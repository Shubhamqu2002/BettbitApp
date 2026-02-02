// lib/services/addmember/addmember_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddMemberService {
  AddMemberService._();
  static final AddMemberService instance = AddMemberService._();

  // ---------------- LuckySports ----------------
  static const String _walletRootNexxorra = "https://walletservice.bettbit.com";
  static const String _uni247Root = "https://api.uni247.xyz";
  static const String _uni247Key = "001389a8-5682-4211-b676-6244de7fad38";

  // ---------------- Torrospin ----------------
  static const String _torrospinAddUserUrl =
      "https://walletservice.bettbit.com/torrospin/adduser";

  // ---------------- Mascot ----------------
  static const String _mascotRpcUrl = "https://mascotservice.bettbit.com/";

  // ---------------- Pref Keys (one-time) ----------------
  static const String _kLsMemberCreated = "ls_member_created_once";
  static const String _kTorrospinUserAdded = "torrospin_user_added_once";
  static const String _kMascotPlayerSet = "mascot_player_set_once";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟧 [AddMemberService] $msg");
  }

  /// ✅ swallow all errors, never throw (fire-and-leave)
  Future<T?> _safe<T>(
    String tag,
    Future<T> Function() fn,
  ) async {
    try {
      return await fn();
    } catch (e, st) {
      _log("⚠️ $tag failed (ignored): $e");
      if (kDebugMode) {
        _log("🧾 $tag stack:\n$st");
      }
      return null;
    }
  }

  // ✅ Call this BEFORE LuckySports webview launch
  // Moto: Fire & Leave — ignore errors, but mark done so it runs only once.
  Future<void> ensureLuckySportsMemberCreatedOnce({
    required String playerId, // user_name
    required String countryCode, // registered_country
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final already = prefs.getBool(_kLsMemberCreated) ?? false;
    if (already) {
      _log("LuckySports: already attempted/created (skip)");
      return;
    }

    final cc = countryCode.trim().isEmpty ? "IN" : countryCode.trim();
    _log("LuckySports: start one-time attempt | playerId=$playerId cc=$cc");

    // ✅ IMPORTANT: mark flag TRUE immediately so we never try again,
    // even if API fails. (as per your requirement)
    await prefs.setBool(_kLsMemberCreated, true);
    _log("LuckySports: flag saved early (will not retry)");

    // 1) get idToken (ignore errors)
    final idToken = await _safe<String>(
      "LuckySports getidtoken",
      () => _getLuckySportsIdToken(countryCode: cc),
    );

    if (idToken == null || idToken.trim().isEmpty) {
      _log("LuckySports: no idToken -> skip create-member (launch will continue)");
      return;
    }

    // 2) create member (ignore errors)
    await _safe<void>(
      "LuckySports create-member",
      () => _createLuckySportsMember(playerId: playerId, idToken: idToken),
    );

    _log("LuckySports: ✅ one-time attempt finished (launch will continue)");
  }

  Future<String> _getLuckySportsIdToken({required String countryCode}) async {
    final url = Uri.parse(
      "$_walletRootNexxorra/luckysport/getidtoken?countryCode=$countryCode",
    );

    _log("LuckySports: POST getidtoken => $url");

    final res = await http
        .post(
          url,
          headers: const {"content-type": "application/json"},
        )
        .timeout(const Duration(seconds: 15));

    _log("LuckySports: getidtoken status=${res.statusCode}");

    // if error, throw (will be caught by _safe)
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log("LuckySports: getidtoken failed body=${res.body}");
      throw Exception("getidtoken failed (${res.statusCode})");
    }

    final data = jsonDecode(res.body);
    if (data is! Map) throw Exception("getidtoken response invalid map");

    final token = (data["idToken"] ?? "").toString().trim();
    if (token.isEmpty) throw Exception("getidtoken missing idToken");

    _log("LuckySports: ✅ got idToken len=${token.length}");
    return token;
  }

  Future<void> _createLuckySportsMember({
    required String playerId,
    required String idToken,
  }) async {
    final url = Uri.parse(
      "$_uni247Root/api/auth/merchant/create-member/?key=$_uni247Key",
    );

    final body = jsonEncode({"player_id": playerId});

    _log("LuckySports: POST create-member => $url");
    _log("LuckySports: create-member body=$body");
    _log("LuckySports: create-member auth=bearer (len=${idToken.length})");

    final res = await http
        .post(
          url,
          headers: {
            "accept": "application/json",
            "authorization": "bearer $idToken",
            "content-type": "application/json",
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    _log("LuckySports: create-member status=${res.statusCode}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log("LuckySports: create-member failed body=${res.body}");
      throw Exception("create-member failed (${res.statusCode})");
    }

    _log("LuckySports: ✅ create-member success");
  }

  // ✅ Call this BEFORE Torrospin launchUrl generation
  // Fire & Leave — ignore errors, but mark done so it runs only once.
  Future<void> ensureTorrospinUserAddedOnce({
    required String userName, // user_name
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final already = prefs.getBool(_kTorrospinUserAdded) ?? false;
    if (already) {
      _log("Torrospin: already attempted/added (skip)");
      return;
    }

    _log("Torrospin: start one-time attempt | userName=$userName");

    // ✅ mark done early (no retry)
    await prefs.setBool(_kTorrospinUserAdded, true);
    _log("Torrospin: flag saved early (will not retry)");

    await _safe<void>("Torrospin adduser", () async {
      final payload = {
        "casinoUserId": userName,
        "username": userName,
        "birthdate": "1990-01-01", // ✅ hardcoded
      };

      final body = jsonEncode(payload);

      _log("Torrospin: POST adduser => $_torrospinAddUserUrl");
      _log("Torrospin: payload=$body");

      final res = await http
          .post(
            Uri.parse(_torrospinAddUserUrl),
            headers: const {"content-type": "application/json"},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      _log("Torrospin: adduser status=${res.statusCode}");

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _log("Torrospin: adduser failed body=${res.body}");
        throw Exception("adduser failed (${res.statusCode})");
      }

      _log("Torrospin: ✅ adduser success");
    });

    _log("Torrospin: ✅ one-time attempt finished (launch will continue)");
  }

  // ✅ Call this BEFORE Mascot create session
  // Fire & Leave — ignore errors, but mark done so it runs only once.
  Future<void> ensureMascotPlayerSetOnce({
    required String userName, // user_name
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final already = prefs.getBool(_kMascotPlayerSet) ?? false;
    if (already) {
      _log("Mascot: already attempted/Player.Set done (skip)");
      return;
    }

    _log("Mascot: start one-time attempt | userName=$userName");

    // ✅ mark done early (no retry)
    await prefs.setBool(_kMascotPlayerSet, true);
    _log("Mascot: flag saved early (will not retry)");

    await _safe<void>("Mascot Player.Set", () async {
      final rpc = {
        "jsonrpc": "2.0",
        "method": "Player.Set",
        "id": DateTime.now().millisecondsSinceEpoch,
        "params": {
          "Id": userName,
          "Nick": userName,
          "BankGroupId": "PU4012_Nexxorra_INR", // ✅ hardcoded
        }
      };

      final body = jsonEncode(rpc);

      _log("Mascot: POST RPC => $_mascotRpcUrl");
      _log("Mascot: body=$body");

      final res = await http
          .post(
            Uri.parse(_mascotRpcUrl),
            headers: const {"content-type": "application/json"},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      _log("Mascot: Player.Set status=${res.statusCode}");

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _log("Mascot: Player.Set failed body=${res.body}");
        throw Exception("Player.Set failed (${res.statusCode})");
      }

      _log("Mascot: ✅ Player.Set success");
    });

    _log("Mascot: ✅ one-time attempt finished (launch will continue)");
  }
}
