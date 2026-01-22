// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../util/crypto_utils.dart';
import '../util/token_manager.dart';

class AuthService {
  static final String _baseUrl =
      dotenv.env['AUTH_BASE_URL'] ??
      (throw Exception('AUTH_BASE_URL not found in .env'));

  String _shortBody(String body, {int limit = 500}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  /// ✅ Extracts a clean human-readable message from API error body
  String _extractErrorMessage(String body, {String fallback = 'Something went wrong'}) {
    try {
      final decoded = jsonDecode(body);

      // Common Spring error format:
      // { status, error, message, path, timestamp }
      if (decoded is Map) {
        final msg = (decoded['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;

        final err = (decoded['error'] ?? '').toString().trim();
        if (err.isNotEmpty) return err;
      }

      // If API returns plain string
      final s = body.toString().trim();
      if (s.isNotEmpty) return s;
    } catch (_) {
      final s = body.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  Future<Map<String, dynamic>> login({
    required String emailOrPhone,
    String? password,
    required String type,
  }) async {
    final token = await TokenManager().getValidToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    final encryptedIdentifier = encryptText(emailOrPhone);
    debugPrint('🔐 Encrypted emailOrPhone: $encryptedIdentifier');

    String? encryptedPassword;
    if (password != null && password.trim().isNotEmpty) {
      encryptedPassword = encryptText(password);
      debugPrint('🔐 Encrypted password: $encryptedPassword');
    }

    final url = Uri.parse('$_baseUrl/api/gamer/login');

    final Map<String, dynamic> payload = {
      "type": type,
      "emailOrPhone": encryptedIdentifier,
    };

    if (type == "EMAIL") {
      payload["password"] = encryptedPassword ?? "";
    }

    debugPrint('📦 Login payload (raw): $payload');

    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      // Network/DNS/timeout etc.
      throw Exception('Network error. Please try again.');
    }

    debugPrint(
      '📡 Login response: ${response.statusCode} -> ${_shortBody(response.body)}',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'LOGIN_SUCCESSFUL') {
        // If backend returns status string only
        final st = (data['status'] ?? 'Login failed').toString();
        throw Exception(st);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('gamer_id', (data['gamerId'] ?? '').toString());
      await prefs.setString('platform_code', (data['platformCode'] ?? '').toString());
      await prefs.setString('user_name', (data['userName'] ?? '').toString());
      await prefs.setString('currency', (data['currency'] ?? 'INR').toString());
      await prefs.setString(
        'registered_country',
        (data['registeredCountry'] ?? 'IN').toString(),
      );
      await prefs.setString('full_name', (data['fullName'] ?? 'Player').toString());

      return data;
    } else {
      // ✅ Clean UI message from error JSON
      final msg = _extractErrorMessage(
        response.body,
        fallback: 'Login failed. Please try again.',
      );
      throw Exception(msg);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('gamer_id');
    await prefs.remove('platform_code');
    await prefs.remove('user_name');
    await prefs.remove('currency');
    await prefs.remove('registered_country');
    await prefs.remove('full_name');

    await TokenManager().clearToken();
  }
}
