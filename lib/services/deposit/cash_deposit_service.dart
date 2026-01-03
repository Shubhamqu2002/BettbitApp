import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CashDepositService {
  /// Endpoint built from WALLET_BASE_URL in .env
  static String get _endpoint {
    final baseUrl = dotenv.env['WALLET_BASE_URL'];
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw Exception('WALLET_BASE_URL not found in .env');
    }
    return '$baseUrl/api/wallet/pending-transaction/add';
  }

  /// Calls:
  /// POST multipart/form-data
  ///  - form field "request" = JSON string
  ///  - form field "image"   = file
  ///
  /// Returns: {ok: bool, message: String, statusCode: int, data: dynamic}
  Future<Map<String, dynamic>> submitCashDeposit({
    required String walletId, // you said: pass gamer_id here
    required num amount,
    required String currency,
    required String transactionId,
    required String platformCode,
    required File imageFile,
  }) async {
    final reqPayload = <String, dynamic>{
      "walletId": walletId,
      "amount": amount,
      "type": "DEPOSIT", // hardcoded
      "currency": currency,
      "category": "test", // hardcoded
      "remarks": "test remarks", // hardcoded
      "transactionId": transactionId,
      "paymentMethod": "CASH", // hardcoded
      "platformCode": platformCode,
    };

    final request =
        http.MultipartRequest("POST", Uri.parse(_endpoint));

    // IMPORTANT: backend expects this exact form field key
    request.fields["request"] = jsonEncode(reqPayload);

    // image field
    request.files.add(
      await http.MultipartFile.fromPath(
        "image",
        imageFile.path,
      ),
    );

    try {
      final streamed = await request.send();
      final status = streamed.statusCode;
      final body = await streamed.stream.bytesToString();

      dynamic decoded;
      try {
        decoded = body.isNotEmpty ? jsonDecode(body) : null;
      } catch (_) {
        decoded = body;
      }

      final ok = status >= 200 && status < 300;

      String message =
          ok ? "Deposit submitted successfully" : "Deposit failed";
      if (decoded is Map) {
        final m = decoded["message"] ??
            decoded["msg"] ??
            decoded["error"];
        if (m != null) message = m.toString();
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        message = decoded;
      }

      return {
        "ok": ok,
        "statusCode": status,
        "message": message,
        "data": decoded,
      };
    } catch (e) {
      return {
        "ok": false,
        "statusCode": 0,
        "message": "Network error: $e",
        "data": null,
      };
    }
  }
}
