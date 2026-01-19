import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../util/crypto_utils.dart';

class BillblendImpsWithdrawService {
  // ✅ REAL endpoint (as per your curl)
  static const String endpoint = "https://payment.bettbit.com/billblend/withdraw";

  // ✅ helper: mask sensitive logs (keeps debugging safe)
  String _mask(String v, {int keepStart = 6, int keepEnd = 4}) {
    final s = v.toString();
    if (s.length <= keepStart + keepEnd) return "***";
    return "${s.substring(0, keepStart)}***${s.substring(s.length - keepEnd)}";
  }

  Future<Map<String, dynamic>> createImpsWithdraw({
    required String userName,
    required String walletId, // ✅ gamer_id -> wallet_id
    required String currency,
    required String groupId,

    required String accountName,
    required String accountNumber,
    required double amount,
    required String bankName,
    required String bankCode,
    required String email,
    required String phone,
    required String transactionPassword,
  }) async {
    final url = Uri.parse(endpoint);

    // ✅ Encrypt required fields
    final encAccountName = encryptText(accountName);
    final encAccountNumber = encryptText(accountNumber);
    final encEmail = encryptText(email);
    final encPhone = encryptText(phone);
    final encTxnPass = encryptText(transactionPassword);

    // As you said: receiver_first_name should be encrypted Account Name
    final encReceiverFirstName = encAccountName;

    final payload = <String, dynamic>{
      "account_name": encAccountName,
      "account_number": encAccountNumber,
      "amount": amount.toStringAsFixed(0),
      "bank_code": bankCode,
      "bank_name": bankName,
      "currency": currency,
      "receiver_email": encEmail,
      "receiver_first_name": encReceiverFirstName,
      "receiver_phone": encPhone,
      "transactionPassword": encTxnPass,
      "user_name": userName,
      "wallet_id": walletId,
      "group_id": groupId,
    };

    // ✅ Debug logs (so you can verify what you are sending)
    debugPrint("🚀 [BILLBLEND_IMPS_WITHDRAW] POST $endpoint");
    debugPrint("🧾 [BILLBLEND_IMPS_WITHDRAW] group_id=$groupId | user_name=$userName | wallet_id=$walletId | currency=$currency | amount=${amount.toStringAsFixed(0)}");

    // Print encrypted payload but masked for safer debugging
    debugPrint("📦 [BILLBLEND_IMPS_WITHDRAW] payload(encrypted+masked): {"
        "account_name:${_mask(encAccountName)}, "
        "account_number:${_mask(encAccountNumber)}, "
        "amount:${amount.toStringAsFixed(0)}, "
        "bank_code:$bankCode, "
        "bank_name:$bankName, "
        "currency:$currency, "
        "receiver_email:${_mask(encEmail)}, "
        "receiver_first_name:${_mask(encReceiverFirstName)}, "
        "receiver_phone:${_mask(encPhone)}, "
        "transactionPassword:${_mask(encTxnPass)}, "
        "user_name:$userName, "
        "wallet_id:$walletId, "
        "group_id:$groupId"
        "}");

    final res = await http
        .post(
          url,
          headers: {"content-type": "application/json"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    debugPrint("📡 [BILLBLEND_IMPS_WITHDRAW] response: ${res.statusCode} -> ${res.body}");

    dynamic decoded;
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = {"raw": res.body};
      }
    } else {
      decoded = {};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (decoded is Map && decoded["message"] != null)
          ? decoded["message"].toString()
          : "Billblend IMPS withdraw failed (${res.statusCode})";
      throw Exception(msg);
    }

    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    return {"data": decoded};
  }
}
