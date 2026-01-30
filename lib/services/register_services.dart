// lib/services/register_services.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/crypto_utils.dart';
import '../util/token_manager.dart';

// ✅ APPSFLYER
import 'analytics/appsflyer_service.dart';

class RegisterService {
  static final String _baseUrl =
      dotenv.env['AUTH_BASE_URL'] ??
      (throw Exception('AUTH_BASE_URL not found in .env'));

  static final String _walletBaseUrl =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  static final String _mascotBaseUrl =
      dotenv.env['MASCOT_BASE_URL'] ??
      (throw Exception('MASCOT_BASE_URL not found in .env'));

  static const String _geoUrl = 'https://ipwho.is/';

  // ✅ cache geo (avoid repeated calls)
  static Map<String, dynamic>? _geoCache;

  static const String _mascotBankGroupId = "PU4012_Nexxorra_INR";
  static const int _mascotRpcId = 1928822491;
  static const String _torrospinBirthdateHardcoded = "1990-01-01";

  // ✅ NEW: hardcoded platform code query param for patch call
  static const String _platformCodeHardcoded = "QN2570";

  String _shortBody(String body, {int limit = 400}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  /// Normalize calling code: "880" -> "+880"
  String _normalizeCallingCode(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return "+91";
    return v.startsWith("+") ? v : "+$v";
  }

  /// Normalize phone → +<cc><last10digits>
  String normalizePhoneWithCallingCode(String input, String callingCode) {
    var v = input.trim().replaceAll(' ', '').replaceAll('-', '');

    if (v.startsWith('+')) v = v.substring(1);
    v = v.replaceAll(RegExp(r'[^0-9]'), '');

    if (v.length > 10) v = v.substring(v.length - 10);

    final cc = _normalizeCallingCode(callingCode);
    final normalized = "$cc$v";

    debugPrint("📞 [REGISTER][PHONE] Normalized => $normalized");
    return normalized;
  }

  /// ✅ Fetch geo info (country_code, country, currency, calling_code)
  Future<Map<String, dynamic>> fetchGeoInfo({bool forceRefresh = false}) async {
    if (!forceRefresh && _geoCache != null) {
      debugPrint("🌍 [GEO] Using cached geo => $_geoCache");
      return _geoCache!;
    }

    final uri = Uri.parse(_geoUrl);
    debugPrint('🌍 [GEO] Fetching from: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    debugPrint(
      '📡 [GEO] status=${response.statusCode} body=${_shortBody(response.body, limit: 250)}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GEO failed (${response.statusCode}): ${_shortBody(response.body, limit: 200)}',
      );
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('GEO invalid json shape from ipwho.is');
    }

    if (raw['success'] == false) {
      throw Exception('GEO ipwho.is failed: ${raw['message'] ?? 'Unknown error'}');
    }

    final countryCode = (raw['country_code'] ?? '').toString().trim();
    final country = (raw['country'] ?? '').toString().trim();

    String currencyCode = '';
    final currencyRaw = raw['currency'];
    if (currencyRaw is Map) {
      currencyCode = (currencyRaw['code'] ?? '').toString().trim();
    } else if (currencyRaw is String) {
      currencyCode = currencyRaw.trim();
    }

    final callingRaw = (raw['calling_code'] ?? '').toString();
    final callingCode = _normalizeCallingCode(callingRaw);

    final normalized = <String, dynamic>{
      'country_code': countryCode.isNotEmpty ? countryCode : 'IN',
      'country': country.isNotEmpty ? country : 'India',
      'currency': currencyCode.isNotEmpty ? currencyCode : 'INR',
      'calling_code': callingCode,
    };

    _geoCache = normalized;

    debugPrint(
      '✅ [GEO] Normalized => country_code=${normalized['country_code']} | country=${normalized['country']} | calling_code=${normalized['calling_code']} | currency=${normalized['currency']}',
    );

    return normalized;
  }

  /// ✅ Main register API
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
    required String registrationType, // EMAIL / PHONE
    required String callingCode,
    String middleName = '',
    String platformCode = 'PU4012',
  }) async {
    final token = await TokenManager().getValidToken();
    if (token == null || token.isEmpty) {
      throw Exception('Unable to generate authorization token');
    }

    final encryptedEmail = encryptText(email);

    final normalizedNumber = number.trim().isEmpty
        ? ""
        : normalizePhoneWithCallingCode(number, callingCode);

    final encryptedNumber =
        normalizedNumber.isEmpty ? "" : encryptText(normalizedNumber);

    final encryptedPassword = encryptText(password);

    debugPrint('🔐 [REGISTER] Encrypted email: $encryptedEmail');
    debugPrint('🔐 [REGISTER] Normalized number: $normalizedNumber');
    debugPrint('🔐 [REGISTER] Encrypted number: $encryptedNumber');
    debugPrint('🔐 [REGISTER] Encrypted password: $encryptedPassword');
    debugPrint('🏷️ [REGISTER] registrationType: $registrationType');

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
      "source": "Mobile",
      "registrationType": registrationType, // EMAIL / PHONE
    };

    debugPrint('➡️ [REGISTER] URL: $url');
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

    // ✅ APPSFLYER EVENT (after successful registration)
    await AppsFlyerService.instance.logEvent(
      "af_complete_registration",
      {
        "af_registration_method": registrationType.toLowerCase(), // email / phone
        "country_code": countryCode,
        "platform_code": platformCode,
      },
    );

    // ✅ username from response
    final userName = (data['userName'] ?? '').toString().trim();

    // ✅ grab AppsFlyer UID (agencyId) and fire PATCH (do NOT wait)
    unawaited(_firePlatformCodePatchAfterRegistration(
      userName: userName,
      token: token,
    ));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', userName);

    debugPrint('💾 [REGISTER] Saved user_name: $userName');

    if (userName.isNotEmpty) {
      unawaited(_hitMascotPlayerSet(userName));
      unawaited(_hitTorrospinAddUser(userName));
    }

    return data;
  }

  /// ✅ NEW: Fire-and-leave PATCH call
  /// PATCH /api/gamer/by-username/{username}/platform-code?code=PU4015&agencyId=<APPSFLYER_UID>
  Future<void> _firePlatformCodePatchAfterRegistration({
    required String userName,
    required String token,
  }) async {
    try {
      if (userName.trim().isEmpty) {
        debugPrint('⚠️ [PATCH][PLATFORM] Skipped: userName is empty');
        return;
      }

      final afUid = await AppsFlyerService.instance.getUid();
      final agencyId = (afUid ?? '').trim();

      if (agencyId.isEmpty) {
        debugPrint('⚠️ [PATCH][PLATFORM] Skipped: AppsFlyer UID not available');
        return;
      }

      final uri = Uri.parse(
        '$_baseUrl/api/gamer/by-username/$userName/platform-code',
      ).replace(queryParameters: {
        'code': _platformCodeHardcoded, // ✅ hardcoded
        'agencyId': agencyId,           // ✅ AppsFlyer UID
      });

      debugPrint('➡️ [PATCH][PLATFORM] URL: $uri');
      debugPrint('🔐 [PATCH][PLATFORM] agencyId(AF UID): $agencyId');

      final res = await http.patch(
        uri,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}), // curl had no body; keep safe empty JSON
      );

      debugPrint(
        '⬅️ [PATCH][PLATFORM] status=${res.statusCode} body=${_shortBody(res.body)}',
      );
    } catch (e) {
      debugPrint('❌ [PATCH][PLATFORM] Error: $e');
    }
  }

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
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      debugPrint('⬅️ [MASCOT] status=${res.statusCode} body=${_shortBody(res.body)}');
    } catch (e) {
      debugPrint('❌ [MASCOT] Error: $e');
    }
  }

  Future<void> _hitTorrospinAddUser(String userName) async {
    try {
      final url = Uri.parse("$_walletBaseUrl/torrospin/adduser");
      final payload = {
        "casinoUserId": userName,
        "username": userName,
        "birthdate": _torrospinBirthdateHardcoded,
      };

      debugPrint('➡️ [TORROSPIN] URL: $url');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      debugPrint('⬅️ [TORROSPIN] status=${res.statusCode} body=${_shortBody(res.body)}');
    } catch (e) {
      debugPrint('❌ [TORROSPIN] Error: $e');
    }
  }
}
