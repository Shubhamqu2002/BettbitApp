import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../util/crypto_utils.dart';

class CashWithdrawResponse {
  final bool success;
  final int statusCode;
  final String message;
  final String rawBody;

  CashWithdrawResponse({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.rawBody,
  });
}

class CashWithdrawService {
  /// Base URL from .env
  static String get _baseUrl {
    final baseUrl = dotenv.env['WALLET_BASE_URL'];
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw Exception('WALLET_BASE_URL not found in .env');
    }
    return baseUrl;
  }

  /// POST: /api/wallet/pending-transaction/withdraw/{gamerId}
  /// Body:
  /// {
  ///   "amount": 100,
  ///   "number": "<ENCRYPTED_MOBILE>",
  ///   "transactionPassword": "<ENCRYPTED_PASS>"
  /// }
  Future<CashWithdrawResponse> createCashWithdraw({
    required double amount,
    required String mobileNumber,
    required String transactionPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final gamerId = (prefs.getString('gamer_id') ?? '').trim();

    if (gamerId.isEmpty) {
      throw Exception("Gamer ID not found. Please login again.");
    }

    final encNumber = encryptText(mobileNumber);
    final encTxnPass = encryptText(transactionPassword);

    debugPrint("🆔 gamerId: $gamerId");
    debugPrint("💰 amount: $amount");
    debugPrint("📱 encrypted number: $encNumber");
    debugPrint("🔐 encrypted transactionPassword: $encTxnPass");

    final url = Uri.parse(
      "$_baseUrl/api/wallet/pending-transaction/withdraw/$gamerId",
    );

    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "amount": amount,
          "number": encNumber,
          "transactionPassword": encTxnPass,
        }),
      );
    } catch (_) {
      return CashWithdrawResponse(
        success: false,
        statusCode: -1,
        message: "Network error. Please check your internet and try again.",
        rawBody: "",
      );
    }

    debugPrint(
      "📡 Withdraw response: ${response.statusCode} -> ${response.body}",
    );

    final status = response.statusCode;
    final ok = status == 200 || status == 201;

    String apiMsg = "";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final m = decoded["message"] ??
            decoded["msg"] ??
            decoded["error"] ??
            decoded["errors"];
        if (m != null) apiMsg = m.toString();
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        apiMsg = response.body.trim();
      }
    }

    String fallback;
    if (ok) {
      fallback = "Withdrawal request submitted successfully ✅";
    } else {
      if (status == 400) {
        fallback = "Invalid request. Please check details and try again.";
      } else if (status == 401) {
        fallback = "Unauthorized. Please login again.";
      } else if (status == 404) {
        fallback = "Service not found (404). Please try again later.";
      } else if (status == 501) {
        fallback = "Service not implemented. Please try later.";
      } else if (status >= 500) {
        fallback = "Server error. Please try again later.";
      } else {
        fallback = "Withdrawal request failed. Please try again.";
      }
    }

    final message =
        apiMsg.trim().isNotEmpty ? apiMsg.trim() : fallback;

    return CashWithdrawResponse(
      success: ok,
      statusCode: status,
      message: message,
      rawBody: response.body,
    );
  }
}
