// lib/services/withdrawl/gpt_withdraw_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// SAME encryption helper used in AuthService
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
    required String userName, // metadata.internal_id
    required String accountName, // recipient.full_name
    String? accountNumber, // recipient.wallet_uid (Bank Transfer)
    String? ifscCode, // recipient.ifsc_code (Bank Transfer)
    String? phone, // UPI only
    String? upiId, // UPI only

    // IMPORTANT: We encrypt this before sending (sender.full_name)
    required String transactionPassword,
  }) async {
    final url = Uri.parse("$_root/api/invoice/withdraw");
    final reference = _makeReference();

    // Encrypt txn password (same helper as AuthService)
    final encryptedTxnPass = encryptText(transactionPassword.trim());

    if (kDebugMode) {
      debugPrint("🧾 GPT Withdraw methodCode: $methodCode");
      debugPrint("🧾 GPT Withdraw reference: $reference");
      debugPrint("🔐 Encrypted transactionPassword: $encryptedTxnPass");
    }

    final Map<String, dynamic> recipient = {
      "full_name": accountName.trim(),
    };

    // BANK TRANSFER => wallet_uid + ifsc_code
    // UPI => phone + upi_id + hardcoded wallet_uid/ifsc_code (as per your requirement)
    final m = methodCode.trim().toUpperCase();
    if (m == "UPI") {
      recipient["wallet_uid"] = "UPI"; // hardcoded as you requested
      recipient["ifsc_code"] = "NA"; // hardcoded (not used)
      recipient["phone"] = (phone ?? "").trim();
      recipient["upi_id"] = (upiId ?? "").trim();
    } else {
      recipient["wallet_uid"] = (accountNumber ?? "").trim();
      recipient["ifsc_code"] = (ifscCode ?? "").trim();
    }

    final payload = {
      "amount": amount,
      "currency": currency.trim().isEmpty ? "INR" : currency.trim(),
      "method_code": methodCode,
      "recipient": recipient,
      "reference": reference,
      "country": country.trim().isEmpty ? "IN" : country.trim(),
      "metadata": {
        "internal_id": userName,
      },
      "webhook_url": webhookUrl,
      "sender": {
        // sender.full_name must be encrypted transactionPassword (as you asked)
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

  String _makeReference() {
    final now = DateTime.now();
    // INV-YYYY-timestamp
    return "INV-${now.year}-${now.millisecondsSinceEpoch}";
  }
}
