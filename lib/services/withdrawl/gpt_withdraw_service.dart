import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../util/crypto_utils.dart';

class GptWithdrawService {
  static const String _root = "https://payment.bettbit.com";
  static const String webhookUrl = "https://payment.bettbit.com/api/invoice";
  static const String senderAddress = "No 2, Green Median Str";

  Future<Map<String, dynamic>> createGptWithdraw({
    required double amount,
    required String currency,
    required String methodCode,
    required String country,
    required String userName,
    required String accountName,
    required String accountNumber,
    required String routingValue,
    required String transactionPassword,
  }) async {
    final url = Uri.parse("$_root/api/invoice/withdraw");
    final reference = _makeReference();
    final normalizedCountry = country.trim().toUpperCase();

    final encryptedTxnPass = encryptText(transactionPassword.trim());

    if (kDebugMode) {
      debugPrint("🧾 GPT Withdraw methodCode: $methodCode");
      debugPrint("🌍 GPT Withdraw country: $normalizedCountry");
      debugPrint("🧾 GPT Withdraw reference: $reference");
      debugPrint("🔐 Encrypted transactionPassword: $encryptedTxnPass");
    }

    final recipient = _buildRecipient(
      country: normalizedCountry,
      accountName: accountName,
      accountNumber: accountNumber,
      routingValue: routingValue,
    );

    final payload = {
      "amount": amount,
      "currency": currency.trim().isEmpty ? "INR" : currency.trim(),
      "method_code": methodCode, // ✅ dynamic from payment methods API
      "recipient": recipient,
      "reference": reference,
      "country": normalizedCountry.isEmpty ? "IN" : normalizedCountry,
      "metadata": {
        "internal_id": userName,
      },
      "webhook_url": webhookUrl,
      "sender": {
        "full_name": encryptedTxnPass,
        "address": senderAddress,
      }
    };

    if (kDebugMode) {
      debugPrint("📦 GPT Withdraw payload: ${jsonEncode(payload)}");
    }

    final res = await http
        .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};

    if (kDebugMode) {
      debugPrint("📡 GPT Withdraw response: ${res.statusCode} -> ${res.body}");
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        (body is Map && body["message"] != null)
            ? body["message"].toString()
            : "GPT withdraw failed (${res.statusCode})",
      );
    }

    if (body is Map<String, dynamic>) return body;
    return {"data": body};
  }

  Map<String, dynamic> _buildRecipient({
    required String country,
    required String accountName,
    required String accountNumber,
    required String routingValue,
  }) {
    final normalizedCountry = country.trim().toUpperCase();

    final recipient = <String, dynamic>{
      "full_name": accountName.trim(),
      "wallet_uid": accountNumber.trim(),
    };

    switch (normalizedCountry) {
      case "IN":
        recipient["ifsc_code"] = routingValue.trim();
        break;

      case "PK":
        recipient["phone"] = routingValue.trim();
        break;

      default:
        // Easy future extension:
        // recipient["routing_code"] = routingValue.trim();
        recipient["phone"] = routingValue.trim();
        break;
    }

    return recipient;
  }

  String _makeReference() {
    final now = DateTime.now();
    return "INV-${now.year}-${now.millisecondsSinceEpoch}";
  }
}