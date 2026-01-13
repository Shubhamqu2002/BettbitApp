// lib/services/password_reset_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../util/crypto_utils.dart';
import '../util/token_manager.dart';

class PasswordResetService {
  static final String _baseUrl =
      dotenv.env['AUTH_BASE_URL'] ??
      (throw Exception('AUTH_BASE_URL not found in .env'));

  /// POST: /api/gamer/get-gamerid
  Future<String> getGamerIdByEmail({required String email}) async {
    final token = await TokenManager().getValidToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    final encryptedEmail = encryptText(email.trim());
    debugPrint("🔐 [FORGOT] Encrypted email: $encryptedEmail");

    final url = Uri.parse('$_baseUrl/api/gamer/get-gamerid');
    final payload = {"email": encryptedEmail};

    debugPrint("📦 [FORGOT] get-gamerid payload: $payload");

    final res = await http.post(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    debugPrint("📡 [FORGOT] get-gamerid response: ${res.statusCode} -> ${res.body}");

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final gamerId = (data['gamerId'] ?? '').toString().trim();
      final message = (data['message'] ?? '').toString().trim();

      if (message.toUpperCase() != 'SUCCESS' || gamerId.isEmpty) {
        throw Exception('Email not found / invalid response: $message');
      }

      return gamerId;
    }

    throw Exception('Failed (${res.statusCode}): ${res.body}');
  }

  /// PATCH: /api/gamer/login-password/{gamerId}
  Future<void> resetLoginPassword({
    required String gamerId,
    required String newPassword,
  }) async {
    final token = await TokenManager().getValidToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    final encryptedPassword = encryptText(newPassword);
    debugPrint("🔐 [FORGOT] Encrypted newPassword: $encryptedPassword");

    final url = Uri.parse('$_baseUrl/api/gamer/login-password/$gamerId');
    final payload = {"newPassword": encryptedPassword};

    debugPrint("📦 [FORGOT] reset password payload: $payload");

    final res = await http.patch(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    debugPrint("📡 [FORGOT] reset password response: ${res.statusCode} -> ${res.body}");

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw Exception('Reset failed (${res.statusCode}): ${res.body}');
  }
}
