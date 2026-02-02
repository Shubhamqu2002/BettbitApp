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

  // ✅ LuckySport endpoints (as you provided)
  static const String _luckyWalletRoot = "https://walletservice.bettbit.com";
  static const String _uni247Root = "https://api.uni247.xyz";
  static const String _uni247Key = "001389a8-5682-4211-b676-6244de7fad38";

  // Optional: store idToken if you want reuse
  static const String _kLuckyIdTokenKey = "lucky_id_token";
  static const String _kLuckyIdTokenExpMsKey = "lucky_id_token_exp_ms";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟦 [AuthService] $msg");
  }

  String _shortBody(String body, {int limit = 500}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  /// ✅ Extract clean message from error body
  String _extractErrorMessage(String body, {String fallback = 'Something went wrong'}) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        final msg = (decoded['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;

        final err = (decoded['error'] ?? '').toString().trim();
        if (err.isNotEmpty) return err;
      }

      final s = body.toString().trim();
      if (s.isNotEmpty) return s;
    } catch (_) {
      final s = body.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  /// ✅ LuckySport Step-1: token generation
  /// POST https://walletservice.bettbit.com/luckysport/getidtoken?countryCode=IN
  Future<Map<String, dynamic>> _getLuckySportIdToken({
    required String countryCode,
  }) async {
    final cc = countryCode.trim().isEmpty ? "IN" : countryCode.trim();
    final url = Uri.parse("$_luckyWalletRoot/luckysport/getidtoken?countryCode=$cc");

    _log("🟣 [Lucky] ➡️ getidtoken url=$url");

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {
          "accept": "application/json",
          "content-type": "application/json",
        },
        body: jsonEncode({}), // safe (even if backend ignores body)
      );
    } catch (e) {
      throw Exception("LuckySport getidtoken network error: $e");
    }

    _log("🟣 [Lucky] ⬅️ getidtoken status=${res.statusCode} body=${_shortBody(res.body)}");

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractErrorMessage(
        res.body,
        fallback: "LuckySport token API failed (${res.statusCode})",
      );
      throw Exception(msg);
    }

    final idToken = (data is Map ? (data["idToken"]?.toString() ?? "") : "");
    final expiresInStr = (data is Map ? (data["expiresIn"]?.toString() ?? "") : "");

    if (idToken.isEmpty) {
      throw Exception("LuckySport token API: idToken missing");
    }

    // compute expiry (best effort)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresInSec = int.tryParse(expiresInStr) ?? 3600;
    final expMs = nowMs + (expiresInSec * 1000);

    return {
      "idToken": idToken,
      "expiresIn": expiresInSec,
      "expMs": expMs,
      "raw": data,
    };
  }

  /// ✅ LuckySport Step-2: create-member
  /// POST https://api.uni247.xyz/api/auth/merchant/create-member/?key=... (Bearer idToken)
  Future<void> _createLuckySportMember({
    required String idToken,
    required String playerId,
  }) async {
    final pid = playerId.trim();
    if (idToken.trim().isEmpty) throw Exception("LuckySport create-member: idToken missing");
    if (pid.isEmpty) throw Exception("LuckySport create-member: playerId missing");

    final url = Uri.parse("$_uni247Root/api/auth/merchant/create-member/?key=$_uni247Key");

    _log("🟣 [Lucky] ➡️ create-member url=$url player_id=$pid");

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {
          "accept": "application/json",
          "authorization": "bearer $idToken",
          "content-type": "application/json",
        },
        body: jsonEncode({"player_id": pid}),
      );
    } catch (e) {
      throw Exception("LuckySport create-member network error: $e");
    }

    _log("🟣 [Lucky] ⬅️ create-member status=${res.statusCode} body=${_shortBody(res.body)}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractErrorMessage(
        res.body,
        fallback: "LuckySport create-member failed (${res.statusCode})",
      );
      throw Exception(msg);
    }
  }

  /// ✅ Fire-and-leave LuckySport post-login setup
  /// - never blocks login success
  Future<void> _postLoginLuckySportSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final country =
          (prefs.getString('registered_country') ?? 'IN').toString().trim();
      final userName = (prefs.getString('user_name') ?? '').toString().trim();

      if (userName.isEmpty) {
        _log("🟣 [Lucky] skip: user_name missing in prefs");
        return;
      }

      // Optional: reuse stored token if not expired
      final savedToken = (prefs.getString(_kLuckyIdTokenKey) ?? '').trim();
      final savedExpMs = prefs.getInt(_kLuckyIdTokenExpMsKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      String idTokenToUse = savedToken;
      if (idTokenToUse.isEmpty || savedExpMs <= nowMs) {
        final tokenRes = await _getLuckySportIdToken(countryCode: country);
        idTokenToUse = tokenRes["idToken"].toString();

        // cache it (optional but helps speed)
        await prefs.setString(_kLuckyIdTokenKey, idTokenToUse);
        await prefs.setInt(_kLuckyIdTokenExpMsKey, tokenRes["expMs"] as int);

        _log("🟣 [Lucky] token cached expMs=${tokenRes["expMs"]}");
      } else {
        _log("🟣 [Lucky] using cached idToken (not expired)");
      }

      await _createLuckySportMember(
        idToken: idTokenToUse,
        playerId: userName,
      );

      _log("🟣 [Lucky] ✅ create-member success for player_id=$userName");
    } catch (e) {
      // ✅ fire-and-leave: do NOT throw, just log
      _log("🟣 [Lucky] ⚠️ post-login setup failed: $e");
    }
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
    _log('🔐 Encrypted emailOrPhone: $encryptedIdentifier');

    String? encryptedPassword;
    if (password != null && password.trim().isNotEmpty) {
      encryptedPassword = encryptText(password);
      _log('🔐 Encrypted password: $encryptedPassword');
    }

    final url = Uri.parse('$_baseUrl/api/gamer/login');

    final Map<String, dynamic> payload = {
      "type": type,
      "emailOrPhone": encryptedIdentifier,
    };

    if (type == "EMAIL") {
      payload["password"] = encryptedPassword ?? "";
    }

    _log('📦 Login payload (raw): $payload');

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
      throw Exception('Network error. Please try again.');
    }

    _log('📡 Login response: ${response.statusCode} -> ${_shortBody(response.body)}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'LOGIN_SUCCESSFUL') {
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

      // ✅ Fire & leave LuckySport setup (token + create-member)
      // Won’t block login success
      _postLoginLuckySportSetup();

      return data;
    } else {
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

    // optional: clear lucky token cache
    await prefs.remove(_kLuckyIdTokenKey);
    await prefs.remove(_kLuckyIdTokenExpMsKey);

    await TokenManager().clearToken();
  }
}
