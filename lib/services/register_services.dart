// lib/services/register_services.dart
import 'dart:async'; // ✅ for unawaited()
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/crypto_utils.dart';
import '../util/token_manager.dart';

class RegisterService {
  // ✅ Base URLs from .env (runtime safe)
  static final String _baseUrl =
      dotenv.env['AUTH_BASE_URL'] ??
      (throw Exception('AUTH_BASE_URL not found in .env'));

  static final String _walletBaseUrl =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  static final String _mascotBaseUrl =
      dotenv.env['MASCOT_BASE_URL'] ??
      (throw Exception('MASCOT_BASE_URL not found in .env'));

  // ✅ REPLACED: ipapi.co -> ipwho.is
  static const String _geoUrl = 'https://ipwho.is/';

  // ✅ Hardcoded constants
  static const String _mascotBankGroupId = "PU4012_Nexxorra_INR";
  static const int _mascotRpcId = 1928822491;
  static const String _torrospinBirthdateHardcoded = "1990-01-01";

  String _shortBody(String body, {int limit = 400}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  /// ✅ Fetch IP-based geo info (country code, country, currency)
  /// Uses ipwho.is (no aggressive rate limiting like ipapi.co)
  ///
  /// Returns a NORMALIZED map:
  /// {
  ///   "country_code": "IN",
  ///   "country": "India",
  ///   "currency": "INR"
  /// }
  Future<Map<String, dynamic>> fetchGeoInfo() async {
    final uri = Uri.parse(_geoUrl);

    debugPrint('🌍 [GEO] Using ipwho.is endpoint: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    debugPrint(
      '📡 [GEO] status=${response.statusCode} body=${_shortBody(response.body, limit: 300)}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GEO failed (${response.statusCode}): ${_shortBody(response.body, limit: 250)}',
      );
    }

    final raw = jsonDecode(response.body);

    if (raw is! Map<String, dynamic>) {
      throw Exception('GEO invalid json shape from ipwho.is');
    }

    final success = raw['success'];
    if (success == false) {
      // ipwho.is sends {"success":false,"message":"..."}
      throw Exception('GEO ipwho.is failed: ${raw['message'] ?? 'Unknown error'}');
    }

    // ipwho.is fields:
    // country_code: "IN"
    // country: "India"
    // currency: {"code":"INR", ...} OR sometimes string depending on proxy response
    final countryCode = (raw['country_code'] ?? '').toString().trim();
    final country = (raw['country'] ?? '').toString().trim();

    String currencyCode = '';
    final currencyRaw = raw['currency'];

    if (currencyRaw is Map) {
      currencyCode = (currencyRaw['code'] ?? '').toString().trim();
    } else if (currencyRaw is String) {
      currencyCode = currencyRaw.trim();
    }

    // ✅ Fallbacks (safe)
    final normalized = <String, dynamic>{
      'country_code': countryCode.isNotEmpty ? countryCode : 'IN',
      'country': country.isNotEmpty ? country : 'India',
      'currency': currencyCode.isNotEmpty ? currencyCode : 'INR',
    };

    debugPrint(
      '✅ [GEO] Normalized => country_code=${normalized['country_code']} | country=${normalized['country']} | currency=${normalized['currency']}',
    );

    return normalized;
  }

  /// Register gamer API
  Future<Map<String, dynamic>> registerGamer({
    required String email,
    required String number,
    required String password,
    required String firstName,
    required String lastName,
    required String dob,
    required String gender,
    required String countryCode,
    required String country,
    String middleName = '',
    String platformCode = 'PU4012',
  }) async {
    // 1️⃣ Get valid token
    final token = await TokenManager().getValidToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    // 2️⃣ Encrypt sensitive fields
    final encryptedEmail = encryptText(email);
    final encryptedNumber = encryptText(number);
    final encryptedPassword = encryptText(password);

    debugPrint('🔐 [REGISTER] Encrypted email: $encryptedEmail');
    debugPrint('🔐 [REGISTER] Encrypted number: $encryptedNumber');
    debugPrint('🔐 [REGISTER] Encrypted password: $encryptedPassword');

    // 3️⃣ Prepare request
    final url = Uri.parse('$_baseUrl/api/gamer/register');

    final body = {
      "email": encryptedEmail,
      "number": encryptedNumber,
      "password": encryptedPassword,
      "countryCode": countryCode,
      "platformCode": platformCode,
      "firstName": firstName,
      "middleName": middleName,
      "lastName": lastName,
      "dob": dob,
      "gender": gender,
      "country": country,
    };

    debugPrint('➡️ [REGISTER] Hitting: $url');
    debugPrint('📤 [REGISTER] Payload: ${jsonEncode(body)}');

    final response = await http.post(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    debugPrint(
      '⬅️ [REGISTER] status=${response.statusCode} body=${_shortBody(response.body)}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Registration failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'REGISTRATION_SUCCESSFUL') {
      throw Exception('Registration failed: ${data['status']}');
    }

    // 4️⃣ Save username
    final prefs = await SharedPreferences.getInstance();
    final userName = (data['userName'] ?? '').toString();

    await prefs.setString('user_name', userName);
    debugPrint('💾 [REGISTER] Saved user_name: $userName');

    // 5️⃣ Fire & Forget extra APIs
    if (userName.isNotEmpty) {
      debugPrint(
        '🚀 [POST-REGISTER] Triggering Mascot & Torrospin APIs (fire-and-forget)',
      );

      unawaited(_hitMascotPlayerSet(userName));
      unawaited(_hitTorrospinAddUser(userName));
    } else {
      debugPrint(
        '⚠️ [POST-REGISTER] userName missing, skipping extra API calls',
      );
    }

    return data;
  }

  /// (1) Mascot JSON-RPC → Player.Set
  Future<void> _hitMascotPlayerSet(String userName) async {
    try {
      final url = Uri.parse("$_mascotBaseUrl/");

      final payload = {
        "jsonrpc": "2.0",
        "method": "Player.Set",
        "id": _mascotRpcId,
        "params": {
          "Id": userName,
          "Nick": userName,
          "BankGroupId": _mascotBankGroupId,
        }
      };

      debugPrint('➡️ [MASCOT] URL: $url');
      debugPrint('📤 [MASCOT] Payload: ${jsonEncode(payload)}');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint(
        '⬅️ [MASCOT] status=${res.statusCode} body=${_shortBody(res.body)}',
      );
    } catch (e, st) {
      debugPrint('❌ [MASCOT] Error: $e');
      debugPrint('🧾 [MASCOT] Stack: $st');
    }
  }

  /// (2) Torrospin → add user
  Future<void> _hitTorrospinAddUser(String userName) async {
    try {
      final url = Uri.parse("$_walletBaseUrl/torrospin/adduser");

      final payload = {
        "casinoUserId": userName,
        "username": userName,
        "birthdate": _torrospinBirthdateHardcoded,
      };

      debugPrint('➡️ [TORROSPIN] URL: $url');
      debugPrint('📤 [TORROSPIN] Payload: ${jsonEncode(payload)}');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint(
        '⬅️ [TORROSPIN] status=${res.statusCode} body=${_shortBody(res.body)}',
      );
    } catch (e, st) {
      debugPrint('❌ [TORROSPIN] Error: $e');
      debugPrint('🧾 [TORROSPIN] Stack: $st');
    }
  }
}
