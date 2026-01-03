// lib/services/wallet_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BalanceData {
  final double cashBalance;
  final double promoBalance;
  final double totalBalance;
  final String currency;

  BalanceData({
    required this.cashBalance,
    required this.promoBalance,
    required this.totalBalance,
    required this.currency,
  });

  static BalanceData zero({String currency = 'INR'}) => BalanceData(
        cashBalance: 0.00,
        promoBalance: 0.00,
        totalBalance: 0.00,
        currency: currency,
      );
}

class WalletService {
  // ✅ Base URL from .env
  static final String _baseUrl =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  String _shortBody(String body, {int limit = 400}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  /// Fetch live balance from API
  /// ✅ If any issue happens, return 0.00 instead of throwing (as you asked)
  Future<BalanceData> fetchBalance(String gamerId) async {
    final url = Uri.parse('$_baseUrl/wallet/balance/$gamerId');

    debugPrint('➡️ [BALANCE] Hitting: $url');

    try {
      final response = await http.get(url);

      debugPrint(
        '⬅️ [BALANCE] status=${response.statusCode} body=${_shortBody(response.body)}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          '⚠️ [BALANCE] Non-200 response, returning 0.00 balance safely',
        );
        return BalanceData.zero();
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        debugPrint(
          '⚠️ [BALANCE] Response not a JSON object, returning 0.00 balance safely',
        );
        return BalanceData.zero();
      }

      double _numToDouble(dynamic v) {
        if (v == null) return 0.00;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0.00;
      }

      final currency = (data['currency'] ?? 'INR').toString();

      final balance = BalanceData(
        cashBalance: _numToDouble(data['cashBalance']),
        promoBalance: _numToDouble(data['promoBalance']),
        totalBalance: _numToDouble(data['totalBalance']),
        currency: currency.isEmpty ? 'INR' : currency,
      );

      // ❌ Removed SharedPreferences storing (as you asked)
      // No caching, always live API

      return balance;
    } catch (e, st) {
      debugPrint('❌ [BALANCE] Error: $e');
      debugPrint('🧾 [BALANCE] Stack: $st');

      // ✅ fallback: show 0.00 in UI
      return BalanceData.zero();
    }
  }

  /// ✅ Clear balance cache (kept for symmetry with Auth logout)
  /// Since we no longer store balance, this is just a placeholder for future.
  Future<void> clearStoredBalance() async {
    // Nothing to clear now (no SharedPreferences used anymore).
    debugPrint('🧹 [BALANCE] clearStoredBalance() called — nothing to clear (no caching).');
  }
}
