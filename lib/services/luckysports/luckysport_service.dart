import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LuckySportService {
  LuckySportService._();
  static final LuckySportService instance = LuckySportService._();

  static const String _walletRoot = "https://walletservice.bettbit.com";
  static const String _uni247Root = "https://api.uni247.xyz";
  static const String _uni247Key = "001389a8-5682-4211-b676-6244de7fad38";

  // ✅ MUST match what you store after login
  static const String _kRegisteredCountry = "registered_country";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟣 [LuckySportService] $msg");
  }

  Map<String, dynamic>? _tryJson(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// ✅ Read country code from SharedPreferences (registered_country) fallback "IN"
  Future<String> _getCountryCodeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cc = (prefs.getString(_kRegisteredCountry) ?? "IN").toString().trim();
    return cc.isEmpty ? "IN" : cc;
  }

  /// 1) Get idToken from walletservice using countryCode from prefs
  Future<String> getIdToken({String? countryCode}) async {
    // ✅ If caller didn't pass countryCode, read from prefs
    final cc = (countryCode == null || countryCode.trim().isEmpty)
        ? await _getCountryCodeFromPrefs()
        : countryCode.trim();

    final url = Uri.parse(
      "$_walletRoot/luckysport/getidtoken?countryCode=${Uri.encodeComponent(cc)}",
    );

    _log("➡️ getIdToken: $url (countryCode=$cc)");

    final res = await http
        .post(
          url,
          headers: const {
            "accept": "application/json",
            "content-type": "application/json",
          },
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 15));

    _log("⬅️ getIdToken: status=${res.statusCode} body=${res.body}");

    final data = _tryJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data?["message"]?.toString().trim().isNotEmpty ?? false)
          ? data!["message"].toString()
          : "LuckySport token API failed (${res.statusCode})";
      throw Exception(msg);
    }

    final idToken = (data?["idToken"]?.toString() ?? "").trim();
    if (idToken.isEmpty) {
      throw Exception("LuckySport token API: idToken missing");
    }

    _log("✅ getIdToken success (len=${idToken.length})");
    return idToken;
  }

  /// 2) Login v2 at uni247 => returns widget_loader_script html
  Future<String> loginV2GetWidgetHtml({
    required String idToken,
    required String playerId,
    String language = "en",
  }) async {
    final tok = idToken.trim();
    final pid = playerId.trim();

    if (tok.isEmpty) throw Exception("LuckySport login: idToken is required");
    if (pid.isEmpty) throw Exception("LuckySport login: playerId is required");

    final url = Uri.parse(
      "$_uni247Root/api/auth/merchant/login-v2/?key=${Uri.encodeComponent(_uni247Key)}",
    );

    _log("➡️ login-v2: $url player_id=$pid");

    final res = await http
        .post(
          url,
          headers: {
            "accept": "application/json",
            "authorization": "Bearer $tok",
            "content-type": "application/json",
          },
          body: jsonEncode({
            "language": language,
            "player_id": pid,
          }),
        )
        .timeout(const Duration(seconds: 20));

    _log("⬅️ login-v2: status=${res.statusCode} body=${res.body}");

    final data = _tryJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (data?["message"]?.toString().trim().isNotEmpty ?? false)
          ? data!["message"].toString()
          : "LuckySport login-v2 failed (${res.statusCode})";
      throw Exception(msg);
    }

    final html = (data?["widget_loader_script"]?.toString() ?? "").trim();
    if (html.isEmpty) {
      throw Exception("LuckySport login-v2: widget_loader_script missing");
    }

    _log("✅ login-v2 success (html len=${html.length})");
    return html;
  }

  /// ✅ One-call helper (like web)
  /// - countryCode automatically comes from SharedPreferences (registered_country)
  Future<String> getWidgetLoaderHtml({
    required String playerId,
    String? countryCode, // optional override
    String language = "en",
  }) async {
    final idToken = await getIdToken(countryCode: countryCode);
    return loginV2GetWidgetHtml(
      idToken: idToken,
      playerId: playerId,
      language: language,
    );
  }
}
