import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PassimpayDepositService {
  static const String _url =
      "https://payment.bettbit.com/api/passimpay/initiate-deposit";

  String buildOrderId() {
    final year = DateTime.now().year;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "INV-$year-$ts";
  }

  String getCallingCode(String countryCode) {
    final code = countryCode.trim().toUpperCase();
    if (code == "PK") return "+92";
    if (code == "BD") return "+880";
    return "+91";
  }

  Future<Map<String, dynamic>> initiateDeposit({
    required double amount,
    required String phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final currency = (prefs.getString('currency') ?? 'INR').trim();
    final userName = (prefs.getString('user_name') ?? '').trim();
    final gamerId = (prefs.getString('gamer_id') ?? '').trim();
    final country = (prefs.getString('registered_country') ?? 'IN').trim();

    if (userName.isEmpty) {
      return {
        "ok": false,
        "message": "Missing user_name in SharedPreferences",
      };
    }

    if (gamerId.isEmpty) {
      return {
        "ok": false,
        "message": "Missing gamer_id in SharedPreferences",
      };
    }

    final callingCode = getCallingCode(country);
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    final payload = {
      "amount": amount.toStringAsFixed(2),
      "order_id": buildOrderId(),
      "symbol": currency,
      "user_name": userName,
      "number": "$callingCode$cleanPhone",
      "currency": currency,
      "wallet_id": gamerId,
    };

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = (data["result"] ?? 0).toString();
        final url = (data["url"] ?? "").toString();

        if (result == "1" && url.isNotEmpty) {
          return {
            "ok": true,
            "message": "Deposit initiated successfully",
            "url": url,
            "data": data,
          };
        }

        return {
          "ok": false,
          "message": (data["message"] ?? "Failed to initiate deposit").toString(),
          "data": data,
        };
      }

      return {
        "ok": false,
        "message":
            (data["message"] ?? "Request failed with status ${response.statusCode}")
                .toString(),
        "data": data,
      };
    } catch (e) {
      return {
        "ok": false,
        "message": e.toString(),
      };
    }
  }
}