// lib/services/betting_records_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Basic game info from game-vendor-details API
class GameInfo {
  final int id;
  final String gameCode;
  final String gameName;
  final String categoryCode;
  final String platformCode;
  final String? imageSquare;

  GameInfo({
    required this.id,
    required this.gameCode,
    required this.gameName,
    required this.categoryCode,
    required this.platformCode,
    this.imageSquare,
  });

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    return GameInfo(
      id: _toInt(json['id']),
      gameCode: _toStringValue(json['gameCode']),
      gameName: _toStringValue(json['gameName']),
      categoryCode: _toStringValue(json['categoryCode'], fallback: 'UNKNOWN'),
      platformCode: _toStringValue(json['platformCode']),
      imageSquare: json['imageSquare']?.toString(),
    );
  }
}

/// Response for game-vendor-details
class GameVendorDetailsResponse {
  final List<GameInfo> games;
  final List<String> categories;
  final String? platformCode;

  GameVendorDetailsResponse({
    required this.games,
    required this.categories,
    required this.platformCode,
  });
}

/// Bet record model for table
class BetRecord {
  final String id;
  final String walletId;
  final String traceId;
  final String transactionId;
  final String betId;
  final String currency;
  final double balanceBefore; // ✅ added
  final double betAmount;
  final String platformCode;
  final String userName;
  final String vendorCode;
  final double winAmount;
  final double lossAmount;
  final double currentClosingBalance;
  final double currentBonusBalance;
  final String gameCode;
  final String gameName;
  final String roundId;
  final double winLoss;
  final double jackpotAmount;
  final String? gameType;
  final String? resultType;
  final String? status;
  final String? remarks;
  final String? transactionType;
  final DateTime? date;

  BetRecord({
    required this.id,
    required this.walletId,
    required this.traceId,
    required this.transactionId,
    required this.betId,
    required this.currency,
    required this.balanceBefore, // ✅ added
    required this.betAmount,
    required this.platformCode,
    required this.userName,
    required this.vendorCode,
    required this.winAmount,
    required this.lossAmount,
    required this.currentClosingBalance,
    required this.currentBonusBalance,
    required this.gameCode,
    required this.gameName,
    required this.roundId,
    required this.winLoss,
    required this.jackpotAmount,
    this.gameType,
    this.resultType,
    this.status,
    this.remarks,
    this.transactionType,
    this.date,
  });

  factory BetRecord.fromJson(Map<String, dynamic> json) {
    return BetRecord(
      id: _toStringValue(json['id']),
      walletId: _toStringValue(json['walletId']),
      traceId: _toStringValue(json['traceId']),
      transactionId: _toStringValue(json['transactionId']),
      betId: _toStringValue(json['betId']),
      currency: _toStringValue(json['currency']),
      balanceBefore: _toDouble(json['balanceBefore']), // ✅ added
      betAmount: _toDouble(json['betAmount']),
      platformCode: _toStringValue(json['platformCode']),
      userName: _toStringValue(json['userName']),
      vendorCode: _toStringValue(json['vendorCode']),
      winAmount: _toDouble(json['winAmount']),
      lossAmount: _toDouble(json['lossAmount']),
      currentClosingBalance: _toDouble(json['currentClosingBalance']),
      currentBonusBalance: _toDouble(json['currentBonusBalance']),
      gameCode: _toStringValue(json['gameCode']),
      gameName: _toStringValue(json['gameName']),
      roundId: _toStringValue(json['roundId']),
      winLoss: _toDouble(json['winLoss']),
      jackpotAmount: _toDouble(json['jackpotAmount']),
      gameType: json['gameType']?.toString(),
      resultType: json['resultType']?.toString(),
      status: json['status']?.toString(),
      remarks: json['remarks']?.toString(),
      transactionType: json['transactionType']?.toString(),
      date: _parseDate(json['date']?.toString()),
    );
  }
}

/// Paginated response for betrecordsbygamename
class BetRecordsPageResponse {
  final List<BetRecord> records;
  final int totalElements;
  final int pageSize;
  final int pageNumber;

  BetRecordsPageResponse({
    required this.records,
    required this.totalElements,
    required this.pageSize,
    required this.pageNumber,
  });
}

class BettingRecordsService {
  static final String _baseUrl =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  String _formatDateTime(DateTime dt) {
    final iso = dt.toIso8601String();
    return iso.split('.').first;
  }

  /// First API: game vendor details by walletId.
  /// Uses wide range to ensure all games are fetched.
  Future<GameVendorDetailsResponse> fetchGameVendorDetails({
    required String walletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final DateTime s = startDate ?? DateTime(2020, 7, 30, 0, 0, 0);
    final DateTime e =
        endDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    final uri = Uri.parse(
      '$_baseUrl/api/wallet/ledger/game-vendor-details/$walletId',
    ).replace(
      queryParameters: {
        'startDate': _formatDateTime(s),
        'endDate': _formatDateTime(e),
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch game vendor details (status: ${res.statusCode})',
      );
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final List gamesJson = (data['gamesDetails'] ?? []) as List;

    final games = gamesJson
        .whereType<Map>()
        .map((e) => GameInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final categoriesSet = <String>{};
    for (final g in games) {
      if (g.categoryCode.isNotEmpty) {
        categoriesSet.add(g.categoryCode);
      }
    }

    String? platformCode;
    if (games.isNotEmpty) {
      platformCode = games.first.platformCode;
    }

    return GameVendorDetailsResponse(
      games: games,
      categories: categoriesSet.toList()..sort(),
      platformCode: platformCode,
    );
  }

  /// Second API: betrecordsbygamename
  Future<BetRecordsPageResponse> fetchBetRecords({
    required String walletId,
    required String platformCode,
    required DateTime startDate,
    required DateTime endDate,
    required String customizedCategory,
    required String gameCodeOrAll,
    required int page,
    required int size,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/wallet/ledger/betrecordsbygamename',
    ).replace(
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
        'sortBy': 'date',
        'sortDir': 'desc',
      },
    );

    final body = {
      'walletIds': [walletId],
      'platformCode': platformCode,
      'startDate': _formatDateTime(
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0),
      ),
      'endDate': _formatDateTime(
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
      ),
      'type': 'BET',
      'customizedCategory': customizedCategory,
      'gameCodes': [gameCodeOrAll],
    };

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch betting records (status: ${res.statusCode})',
      );
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final List contentJson = (data['content'] ?? []) as List;

    final records = contentJson
        .whereType<Map>()
        .map((e) => BetRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final totalElements = _toInt(data['totalElements']);
    final pageSize = _toInt(data['size'], fallback: size);
    final pageNumber = _toInt(data['number'], fallback: page);

    return BetRecordsPageResponse(
      records: records,
      totalElements: totalElements,
      pageSize: pageSize,
      pageNumber: pageNumber,
    );
  }
}

/* ---------------- helpers ---------------- */

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String _toStringValue(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString();
  return s;
}

DateTime? _parseDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}