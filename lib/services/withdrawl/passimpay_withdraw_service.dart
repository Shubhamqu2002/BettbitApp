import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../util/crypto_utils.dart';

class PassimpayWithdrawService {
  static const String _url =
      'https://payment.bettbit.com/api/passimpay/initiate-withdraw';

  Future<Map<String, dynamic>> createPassimpayWithdraw({
    required String amount,
    required String orderId,
    required String symbol,
    required String userName,
    required String number,
    required String currency,
    required String walletId,
    required String destinationWalletAddress,
    required String transactionPassword,
    required String methodCode,
  }) async {
    final payload = {
      "amount": amount,
      "order_id": orderId,
      "symbol": symbol,
      "user_name": userName,
      "number": number,
      "currency": currency,
      "wallet_id": walletId,
      "destination_wallet_address": destinationWalletAddress,
      "transaction_password": encryptText(transactionPassword),
      "method_code": methodCode,
    };

    debugPrint("🚀 [PASSIMPAY_WITHDRAW_SERVICE] URL => $_url");
    debugPrint(
      "🚀 [PASSIMPAY_WITHDRAW_SERVICE] Payload => ${jsonEncode({
        ...payload,
        "transaction_password": "***encrypted***",
      })}",
    );

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    debugPrint(
      "📦 [PASSIMPAY_WITHDRAW_SERVICE] status=${response.statusCode} body=${response.body}",
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        "Invalid server response (${response.statusCode})",
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final msg = (data["message"] ??
            data["error"] ??
            data["msg"] ??
            "Passimpay withdrawal failed")
        .toString();

    throw Exception(msg);
  }
}