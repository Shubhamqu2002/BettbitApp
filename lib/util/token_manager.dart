// lib/util/token_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  TokenManager._internal();
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;

  static const String _tokenKey = 'auth_access_token';
  static const String _tokenExpiryKey = 'auth_access_token_expiry';

  static const String _tokenEmail = 'satyaki0906@gmail.com';
  static const String _tokenPassword = '1234';

  /// Get a valid token (refresh if expired / missing)
  Future<String?> getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    final expiryMillis = prefs.getInt(_tokenExpiryKey);

    final now = DateTime.now().millisecondsSinceEpoch;

    if (savedToken != null &&
        expiryMillis != null &&
        now < expiryMillis) {
      // Still valid
      return savedToken;
    }

    // Need fresh token
    return await _generateToken();
  }

  Future<String?> _generateToken() async {
    final url = Uri.parse('https://api.nexxorra.com/generate/token');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _tokenEmail,
          'password': _tokenPassword,
        }),
      );

      debugPrint(
          '🔑 Token response: ${response.statusCode} -> ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final durationStr = data['duration']?.toString() ?? '1500';
        final durationSeconds = int.tryParse(durationStr) ?? 1500;

        if (accessToken != null && accessToken.isNotEmpty) {
          final now = DateTime.now();
          // refresh 1 minute early
          final expiry = now.add(Duration(seconds: durationSeconds - 60));

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, accessToken);
          await prefs.setInt(
              _tokenExpiryKey, expiry.millisecondsSinceEpoch);

          return accessToken;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Token generation error: $e');
      return null;
    }
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }
}
