import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../util/crypto_utils.dart';
import '../../util/token_manager.dart';

class ChangeLoginPasswordService {
  /// Base URL from .env
  static String get _baseUrl {
    final url = dotenv.env['AUTH_BASE_URL'];
    if (url == null || url.trim().isEmpty) {
      throw Exception('AUTH_BASE_URL not found in .env');
    }
    return url;
  }

  /// PATCH: /api/gamer/login-password/{gamerId}
  /// Body: { "newPassword": "<ENCRYPTED>" }
  Future<void> changeLoginPassword({
    required String newPasswordPlain,
  }) async {
    // 1) Read gamerId from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final gamerId = prefs.getString('gamer_id');

    if (gamerId == null || gamerId.trim().isEmpty) {
      throw Exception('Gamer ID not found in local storage.');
    }

    // 2) Get valid Authorization token
    final token = await TokenManager().getValidToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    // 3) Encrypt new password
    final encryptedNewPassword = encryptText(newPasswordPlain);

    debugPrint('🆔 gamerId: $gamerId');
    debugPrint('🌐 AUTH_BASE_URL: $_baseUrl');
    debugPrint('🔐 Encrypted newPassword: $encryptedNewPassword');

    // 4) Call API
    final url = Uri.parse('$_baseUrl/api/gamer/login-password/$gamerId');

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
      '📡 Change login password response: ${response.statusCode} -> ${response.body}',
    );

    // Success (200 or 204)
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw Exception(
      'Change password failed (${response.statusCode}): ${response.body}',
    );
  }
}
