// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../util/crypto_utils.dart';
import '../util/token_manager.dart';

class AuthService {
  // ✅ Load base URL from .env (runtime-safe)
  static final String _baseUrl =
      dotenv.env['AUTH_BASE_URL'] ??
      (throw Exception('AUTH_BASE_URL not found in .env'));

  /// Login API
  /// - For EMAIL: sends encrypted email + encrypted password + type=EMAIL
  /// - For PHONE: sends encrypted phone only + type=PHONE (NO password)
  Future<Map<String, dynamic>> login({
    required String emailOrPhone,
    String? password, // optional for PHONE
    required String type, // "EMAIL" or "PHONE"
  }) async {
    // 1) Get valid token (auto-refresh)
    final token = await TokenManager().getValidToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    // 2) Encrypt identifier
    final encryptedIdentifier = encryptText(emailOrPhone);
    debugPrint('🔐 Encrypted emailOrPhone: $encryptedIdentifier');

    // 3) Encrypt password only if provided (EMAIL)
    String? encryptedPassword;
    if (password != null && password.trim().isNotEmpty) {
      encryptedPassword = encryptText(password);
      debugPrint('🔐 Encrypted password: $encryptedPassword');
    }

    // 4) Prepare request
    final url = Uri.parse('$_baseUrl/api/gamer/login');

    // ✅ Build payload exactly as you asked
    final Map<String, dynamic> payload = {
      "type": type,
      "emailOrPhone": encryptedIdentifier,
    };

    // Only include password for EMAIL
    if (type == "EMAIL") {
      payload["password"] = encryptedPassword ?? "";
    }

    debugPrint('📦 Login payload (raw): $payload');

    final response = await http.post(
      url,
      headers: {
        'Authorization': token, // exactly like your curl
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    debugPrint('📡 Login response: ${response.statusCode} -> ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'LOGIN_SUCCESSFUL') {
        throw Exception('Login failed: ${data['status']}');
      }

      // Store user info in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('gamer_id', data['gamerId'] ?? '');
      await prefs.setString('platform_code', data['platformCode'] ?? '');
      await prefs.setString('user_name', data['userName'] ?? '');
      await prefs.setString('currency', data['currency'] ?? 'INR');
      await prefs.setString('registered_country', data['registeredCountry'] ?? 'IN');
      await prefs.setString('full_name', data['fullName'] ?? 'Player');

      return data;
    } else {
      throw Exception('Login failed (${response.statusCode}): ${response.body}');
    }
  }

  /// Clear stored session (used on logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('gamer_id');
    await prefs.remove('platform_code');
    await prefs.remove('user_name');
    await prefs.remove('currency');
    await prefs.remove('registered_country');
    await prefs.remove('full_name');

    // optional: also clear token
    await TokenManager().clearToken();
  }
}
