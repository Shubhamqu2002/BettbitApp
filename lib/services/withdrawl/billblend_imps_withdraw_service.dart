import 'dart:convert';
import 'package:http/http.dart' as http;

class BillblendImpsWithdrawService {
  // TODO: Replace with your real Billblend IMPS withdrawal endpoint
  // Example (guess): https://walletservice.bettbit.com/withdrawal/imps
  static const String endpoint = "https://walletservice.bettbit.com/withdrawal/imps";

  Future<Map<String, dynamic>> createImpsWithdraw({
    required String userName,
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

    final payload = {
      "user_name": userName,
      "currency": currency,
      "group_id": groupId,
      "account_name": accountName,
      "account_number": accountNumber,
      "amount": amount.toStringAsFixed(0),
      "bank_name": bankName,
      "bank_code": bankCode,
      "receiver_email": email,
      "receiver_phone": phone,
      "transactionPassword": transactionPassword,
      "receiver_first_name": "BillblendUser",
    };

    final res = await http
        .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        (body is Map && body["message"] != null)
            ? body["message"].toString()
            : "IMPS withdraw failed (${res.statusCode})",
      );
    }

    if (body is Map<String, dynamic>) return body;
    return {"data": body};
  }
}
