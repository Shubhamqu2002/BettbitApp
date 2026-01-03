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
      id: json['id'] as int,
      gameCode: (json['gameCode'] ?? '') as String,
      gameName: (json['gameName'] ?? '') as String,
      categoryCode: (json['categoryCode'] ?? 'UNKNOWN') as String,
      platformCode: (json['platformCode'] ?? '') as String,
      imageSquare: json['imageSquare'] as String?,
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
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    DateTime? _parseDate(String? s) {
      if (s == null) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return BetRecord(
      id: (json['id'] ?? '') as String,
      walletId: (json['walletId'] ?? '') as String,
      traceId: (json['traceId'] ?? '') as String,
      transactionId: (json['transactionId'] ?? '') as String,
      betId: (json['betId'] ?? '') as String,
      currency: (json['currency'] ?? '') as String,
      betAmount: _toDouble(json['betAmount']),
      platformCode: (json['platformCode'] ?? '') as String,
      userName: (json['userName'] ?? '') as String,
      vendorCode: (json['vendorCode'] ?? '') as String,
      winAmount: _toDouble(json['winAmount']),
      lossAmount: _toDouble(json['lossAmount']),
      currentClosingBalance: _toDouble(json['currentClosingBalance']),
      currentBonusBalance: _toDouble(json['currentBonusBalance']),
      gameCode: (json['gameCode'] ?? '') as String,
      gameName: (json['gameName'] ?? '') as String,
      roundId: (json['roundId'] ?? '') as String,
      winLoss: _toDouble(json['winLoss']),
      jackpotAmount: _toDouble(json['jackpotAmount']),
      gameType: json['gameType'] as String?,
      resultType: json['resultType'] as String?,
      status: json['status'] as String?,
      remarks: json['remarks'] as String?,
      transactionType: json['transactionType'] as String?,
      date: _parseDate(json['date'] as String?),
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
  // ✅ Base URL from .env (WALLET_BASE_URL)
  static final String _baseUrl =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  String _formatDateTime(DateTime dt) {
    final iso = dt.toIso8601String();
    return iso.split('.').first; // "YYYY-MM-DDTHH:mm:ss"
  }

  /// First API: game vendor details by walletId.
  /// 🔥 To make sure we get ALL games, we always use a very wide date range:
  /// from 2020-07-30T00:00:00 to today 23:59:59 (unless explicitly overridden).
  Future<GameVendorDetailsResponse> fetchGameVendorDetails({
    required String walletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final DateTime s =
        startDate ?? DateTime(2020, 7, 30, 0, 0, 0); // wide start
    final DateTime e = endDate ??
        DateTime(now.year, now.month, now.day, 23, 59, 59); // today end

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
        .map((e) => GameInfo.fromJson(e as Map<String, dynamic>))
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
    required String customizedCategory, // "ALL" or categoryCode
    required String gameCodeOrAll, // "ALL" or specific gameCode
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
        .map((e) => BetRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    final totalElements = (data['totalElements'] ?? 0) as int;
    final pageSize = (data['size'] ?? size) as int;
    final pageNumber = (data['number'] ?? page) as int;

    return BetRecordsPageResponse(
      records: records,
      totalElements: totalElements,
      pageSize: pageSize,
      pageNumber: pageNumber,
    );
  }
}
