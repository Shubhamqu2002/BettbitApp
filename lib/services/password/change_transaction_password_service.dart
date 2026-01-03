import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../util/crypto_utils.dart';
import '../../util/token_manager.dart';

class ChangeTransactionPasswordService {
  /// Base URL from .env
  static String get _baseUrl {
    final url = dotenv.env['AUTH_BASE_URL'];
    if (url == null || url.trim().isEmpty) {
      throw Exception('AUTH_BASE_URL not found in .env');
    }
    return url;
  }

  /// PATCH: /api/gamer/transaction-password/{gamerId}
  /// Body: { "newPassword": "<ENCRYPTED>" }
  Future<void> changeTransactionPassword({
    required String newPasswordPlain,
  }) async {
    // 1) Read gamerId from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final gamerId = prefs.getString('gamer_id');

    if (gamerId == null || gamerId.trim().isEmpty) {
      throw Exception('Gamer ID not found in local storage.');
    }

    // 2) Get valid Authorization token (auto-refresh)
    final token = await TokenManager().getValidToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    // 3) Encrypt field
    final encryptedNewPassword = encryptText(newPasswordPlain);

    debugPrint('🆔 gamerId: $gamerId');
    debugPrint('🌐 AUTH_BASE_URL: $_baseUrl');
    debugPrint('🔐 Encrypted transaction newPassword: $encryptedNewPassword');

    // 4) Call API
    final url = Uri.parse('$_baseUrl/api/gamer/transaction-password/$gamerId');

    final response = await http.patch(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "newPassword": encryptedNewPassword,
      }),
    );

    debugPrint(
      '📡 Change transaction password response: ${response.statusCode} -> ${response.body}',
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw Exception(
      'Transaction password failed (${response.statusCode}): ${response.body}',
    );
  }
}
