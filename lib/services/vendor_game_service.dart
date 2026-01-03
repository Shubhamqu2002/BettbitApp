// lib/services/vendor_game_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base URLs from .env
String get _apiBaseUrl {
  final v = dotenv.env['WALLET_BASE_URL'];
  if (v == null || v.trim().isEmpty) {
    throw Exception('WALLET_BASE_URL not found in .env');
  }
  return v;
}

String get _mascotBaseUrl {
  final v = dotenv.env['MASCOT_BASE_URL'];
  if (v == null || v.trim().isEmpty) {
    throw Exception('MASCOT_BASE_URL not found in .env');
  }
  return v;
}

String get kVendorImageBaseUrl {
  final v = dotenv.env['IMAGE_BASE_URL'];
  if (v == null || v.trim().isEmpty) {
    throw Exception('IMAGE_BASE_URL not found in .env');
  }
  return v;
}

class VendorModel {
  final String imageUrl;
  final String vendorCode;
  final String vendorName;

  VendorModel({
    required this.imageUrl,
    required this.vendorCode,
    required this.vendorName,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      imageUrl: (json['imageUrl'] as String?) ?? '',
      vendorCode: (json['vendorCode'] as String?) ?? '',
      vendorName: (json['vendorName'] as String?) ?? '',
    );
  }

  /// Normalize image URL using base if it's a relative path like "assets/xyz.png"
  String get resolvedImageUrl {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    // Ensure no duplicate slash
    if (imageUrl.startsWith('/')) {
      return '$kVendorImageBaseUrl${imageUrl.substring(1)}';
    }
    return '$kVendorImageBaseUrl$imageUrl';
  }
}

class GameModel {
  final int id;
  final String gameName;
  final String gameCode;
  final String vendorCode;
  final String categoryCode;
  final String imageSquare;
  final String imageLandscape;

  /// For deciding which launch API to call
  final String aggregator; // e.g. "TORROSPIN", "MASCOT"
  final String? gameAggregatorType;

  GameModel({
    required this.id,
    required this.gameName,
    required this.gameCode,
    required this.vendorCode,
    required this.categoryCode,
    required this.imageSquare,
    required this.imageLandscape,
    required this.aggregator,
    this.gameAggregatorType,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      gameName: (json['gameName'] as String?) ?? '',
      gameCode: (json['gameCode'] as String?) ?? '',
      vendorCode: (json['vendorCode'] as String?) ?? '',
      categoryCode: (json['categoryCode'] as String?) ?? '',
      imageSquare: (json['imageSquare'] as String?) ?? '',
      imageLandscape: (json['imageLandscape'] as String?) ?? '',
      aggregator: ((json['aggregator'] as String?) ?? '').toUpperCase(),
      gameAggregatorType: json['gameAggregatorType'] as String?,
    );
  }

  String get displayImageUrl {
    // Prefer square image if present
    if (imageSquare.isNotEmpty) return imageSquare;
    return imageLandscape;
  }
}

class PaginatedGames {
  final List<GameModel> games;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool last;

  PaginatedGames({
    required this.games,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PaginatedGames.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawList = (json['content'] as List?) ?? [];
    final games = rawList
        .map((e) => GameModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedGames(
      games: games,
      pageNumber: (json['pageable']?['pageNumber'] as num?)?.toInt() ??
          (json['number'] as num?)?.toInt() ??
          0,
      pageSize: (json['pageable']?['pageSize'] as num?)?.toInt() ??
          (json['size'] as num?)?.toInt() ??
          games.length,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? games.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      last: (json['last'] as bool?) ?? true,
    );
  }
}

class VendorGameService {
  VendorGameService._internal();
  static final VendorGameService _instance = VendorGameService._internal();
  factory VendorGameService() => _instance;

  // ---------------------------------------------------------------------------
  //  Country resolver for APIs (country.is)
  // ---------------------------------------------------------------------------

  String? _cachedCountryCode;
  DateTime? _cachedCountryAt;

  /// Gets country code from https://api.country.is/
  /// Caches for 10 minutes to avoid repeated calls.
  Future<String> _getCurrentCountryCode() async {
    final now = DateTime.now();
    final cachedOk = _cachedCountryCode != null &&
        _cachedCountryCode!.trim().isNotEmpty &&
        _cachedCountryAt != null &&
        now.difference(_cachedCountryAt!).inMinutes < 10;

    if (cachedOk) {
      debugPrint('🌍 country.is (cached) -> $_cachedCountryCode');
      return _cachedCountryCode!;
    }

    debugPrint('🌍 country.is call -> GET https://api.country.is/');
    try {
      final uri = Uri.parse('https://api.country.is/');
      final res = await http.get(uri);

      debugPrint('🌍 country.is response -> ${res.statusCode} -> ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final c = (decoded is Map && decoded['country'] != null)
            ? decoded['country'].toString().trim()
            : '';

        if (c.isNotEmpty) {
          _cachedCountryCode = c;
          _cachedCountryAt = now;
          debugPrint('🌍 country.is parsed countryCode -> $c');
          return c;
        }
      }
    } catch (e) {
      debugPrint('🌍 country.is error -> $e');
    }

    // fallback
    debugPrint('🌍 country.is fallback -> IN');
    _cachedCountryCode = 'IN';
    _cachedCountryAt = now;
    return 'IN';
  }

  /// Helper to read stored prefs safely
  Future<String> _getPrefOrFallback(String key, String fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getString(key) ?? '').trim();
    return v.isEmpty ? fallback : v;
  }

  // ---------------------------------------------------------------------------
  //  Vendors
  // ---------------------------------------------------------------------------

  /// GET /api/wallet/games/vendors/{category}/{platform}?countryCode=IN&page=0&size=100
  Future<List<VendorModel>> fetchVendors({
    required String category, // ALL / HOT / SLOT / CASINO / ...
    required String platform, // TORROSPIN / MASCOT (UPPERCASE)
    String? countryCode, // auto-detect if null
    int page = 0,
    int size = 100,
  }) async {
    final resolvedCountry = (countryCode == null || countryCode.trim().isEmpty)
        ? await _getCurrentCountryCode()
        : countryCode.trim();

    debugPrint(
      '🧩 fetchVendors -> category=$category platform=$platform countryCode=$resolvedCountry page=$page size=$size',
    );

    final uri = Uri.parse(
      '$_apiBaseUrl/api/wallet/games/vendors/$category/$platform',
    ).replace(queryParameters: {
      'countryCode': resolvedCountry,
      'page': '$page',
      'size': '$size',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load vendors: HTTP ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> rawList = (decoded['content'] as List?) ?? [];
    return rawList
        .map((e) => VendorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  //  Games
  // ---------------------------------------------------------------------------

  /// GET /api/wallet/games/by-category-vendor/{category}/{vendorCode}/{platform}?countryCode=IN&page=0&size=24
  Future<PaginatedGames> fetchGames({
    required String category, // ALL / HOT / SLOT / CASINO / ...
    required String vendorCode,
    required String platform, // TORROSPIN / MASCOT (UPPERCASE)
    String? countryCode, // auto-detect if null
    int page = 0,
    int size = 24,
  }) async {
    final resolvedCountry = (countryCode == null || countryCode.trim().isEmpty)
        ? await _getCurrentCountryCode()
        : countryCode.trim();

    debugPrint(
      '🎮 fetchGames -> category=$category vendorCode=$vendorCode platform=$platform countryCode=$resolvedCountry page=$page size=$size',
    );

    final uri = Uri.parse(
      '$_apiBaseUrl/api/wallet/games/by-category-vendor/$category/$vendorCode/$platform',
    ).replace(queryParameters: {
      'countryCode': resolvedCountry,
      'page': '$page',
      'size': '$size',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load games: HTTP ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return PaginatedGames.fromJson(decoded);
  }

  // ---------------------------------------------------------------------------
  //  TORROSPIN GAME LAUNCH
  // ---------------------------------------------------------------------------

  /// POST /torrospin/generatelink?countryCode=IN
  ///
  /// NOTE (as per your requirement):
  /// - countryCode comes from SharedPreferences key: registered_country
  /// - currency comes from SharedPreferences key: currency
  Future<String> generateTorrospinLaunchUrl({
    required String userName,
    required String gameCode,
  }) async {
    final resolvedCountry =
        await _getPrefOrFallback('registered_country', 'IN');
    final resolvedCurrency = await _getPrefOrFallback('currency', 'INR');

    debugPrint(
      '🚀 generateTorrospinLaunchUrl -> userName=$userName gameCode=$gameCode countryCode=$resolvedCountry currency=$resolvedCurrency',
    );

    final uri = Uri.parse('$_apiBaseUrl/torrospin/generatelink')
        .replace(queryParameters: {
      'countryCode': resolvedCountry,
    });

    final token =
        '${userName}_${DateTime.now().millisecondsSinceEpoch.toString()}';

    final payload = {
      "token": token,
      "gameName": gameCode,
      "userId": userName,
      "birthDate": "2001-09-01",
      "bankId": 0,
      "currency": resolvedCurrency,
      "quitLink": kVendorImageBaseUrl,
      "device": "desktop",
      "lang": "en",
    };

    debugPrint('🚀 Torrospin payload -> ${jsonEncode(payload)}');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate Torrospin game link: HTTP ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final success = decoded['success'] == true;
    final url = decoded['url'] as String?;

    if (!success || url == null || url.isEmpty) {
      throw Exception('Torrospin launch link missing or unsuccessful.');
    }

    debugPrint('🚀 Torrospin launch URL -> $url');
    return url;
  }

  // ---------------------------------------------------------------------------
  //  MASCOT GAME LAUNCH
  // ---------------------------------------------------------------------------

  /// JSON-RPC POST to https://mascotservice.nexxorra.com
  Future<String> createMascotSession({
    required String userName,
    required String gameCode,
  }) async {
    final playerIp = await _getPublicIp();

    final payload = {
      "jsonrpc": "2.0",
      "method": "Session.Create",
      "id": 1047919053,
      "params": {
        "PlayerId": userName,
        "GameId": gameCode,
        "BonusId": "WelcomeBonusIndiaPlayersJan2024",
        "Params": {
          "language": "en",
          "freeround_denomination": 10,
        },
        "PlayerIp": playerIp,
      },
    };

    final response = await http.post(
      Uri.parse(_mascotBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create Mascot session: HTTP ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;

    final sessionUrl = result?['SessionUrl'] as String?;
    if (sessionUrl == null || sessionUrl.isEmpty) {
      throw Exception('Mascot SessionUrl missing in response.');
    }

    return sessionUrl;
  }

  // ---------------------------------------------------------------------------
  //  Helper: Public IP (for Mascot PlayerIp)
  // ---------------------------------------------------------------------------

  Future<String> _getPublicIp() async {
    try {
      final uri = Uri.parse('https://api.ipify.org?format=json');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final ip = decoded['ip'] as String?;
        if (ip != null && ip.isNotEmpty) {
          return ip;
        }
      }
    } catch (_) {
      // ignore and fallback
    }
    // Fallback if anything fails
    return '0.0.0.0';
  }
}
