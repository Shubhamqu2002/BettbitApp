import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AccountLedgerPage {
  final List<AccountLedgerItem> content;

  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool first;
  final bool last;
  final int numberOfElements;
  final bool empty;

  AccountLedgerPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.first,
    required this.last,
    required this.numberOfElements,
    required this.empty,
  });

  factory AccountLedgerPage.fromJson(Map<String, dynamic> json) {
    final list = (json['content'] as List<dynamic>? ?? [])
        .map((e) => AccountLedgerItem.fromJson(e as Map<String, dynamic>))
        .toList();

    int asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    bool asBool(dynamic v, {bool fallback = false}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == "true") return true;
      if (s == "false") return false;
      return fallback;
    }

    return AccountLedgerPage(
      content: list,
      totalElements: asInt(json['totalElements']),
      totalPages: asInt(json['totalPages'], fallback: 1),
      number: asInt(json['number']),
      size: asInt(json['size'], fallback: 10),
      first: asBool(json['first']),
      last: asBool(json['last']),
      numberOfElements: asInt(json['numberOfElements']),
      empty: asBool(json['empty']),
    );
  }
}

class AccountLedgerItem {
  final String ledgerId;
  final String walletId;
  final String userName;
  final String transactionId;
  final String currency;

  // ✅ amount used for PENDING/REJECTED
  final double amount;

  // ✅ transactionValue used for CONFIRMED
  final double transactionValue;

  final double currentBalance;
  final double bonusBalance;

  final String transactionType;
  final String status;
  final DateTime? date;

  final String? imageUrl;
  final String? paymentMethod;
  final String? address;
  final dynamic cryptoAmount;

  final String? remarks;
  final String? resultType;
  final String? platformCode;
  final String? externalTransactionId;

  AccountLedgerItem({
    required this.ledgerId,
    required this.walletId,
    required this.userName,
    required this.transactionId,
    required this.currency,
    required this.amount,
    required this.transactionValue, // ✅ added
    required this.currentBalance,
    required this.bonusBalance,
    required this.transactionType,
    required this.status,
    required this.date,
    this.imageUrl,
    this.paymentMethod,
    this.address,
    this.cryptoAmount,
    this.remarks,
    this.resultType,
    this.platformCode,
    this.externalTransactionId,
  });

  factory AccountLedgerItem.fromJson(Map<String, dynamic> json) {
    return AccountLedgerItem(
      ledgerId: (json['ledgerId'] ?? '').toString(),
      walletId: (json['walletId'] ?? '').toString(),
      userName: (json['userName'] ?? '').toString(),
      transactionId: (json['transactionId'] ?? '').toString(),
      currency: (json['currency'] ?? 'INR').toString(),

      amount: _asDouble(json['amount']),
      transactionValue: _asDouble(json['transactionValue']), // ✅ parse from API

      currentBalance: _asDouble(json['currentBalance']),
      bonusBalance: _asDouble(json['bonusBalance']),
      transactionType: (json['transactionType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      date: _tryParseDate(json['date']),
      imageUrl: json['imageUrl']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      address: json['address']?.toString(),
      cryptoAmount: json['cryptoAmount'],
      remarks: json['remarks']?.toString(),
      resultType: json['resultType']?.toString(),
      platformCode: json['platformCode']?.toString(),
      externalTransactionId: json['externalTransactionId']?.toString(),
    );
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }
}

class AccountRecordsService {
  AccountRecordsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  // ✅ Base from .env + fixed path
  static final String _baseUrl =
      '${dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'))}'
      '/api/wallet/ledger/filter';

  Future<AccountLedgerPage> fetchLedger({
    required int page,
    required int size,
    required String sortBy,
    required String sortDir,
    required List<String> walletIds,
    required String platformCode,
    required String startDateIso,
    required String endDateIso,
    required String type,
    String? status,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl?page=$page&size=$size&sortBy=$sortBy&sortDir=$sortDir',
    );

    final payload = <String, dynamic>{
      'walletIds': walletIds,
      'platformCode': platformCode,
      'startDate': startDateIso,
      'endDate': endDateIso,
      'type': type,
      'status': status,
    };

    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Ledger API failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return AccountLedgerPage.fromJson(json);
  }
}
