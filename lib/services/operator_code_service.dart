// lib/services/operator_code_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Device info
import 'package:device_info_plus/device_info_plus.dart';

class OperatorCodeService {
  OperatorCodeService._();
  static final OperatorCodeService instance = OperatorCodeService._();

  static const String _kOperatorCode = "operator_code";
  static const String _kOperatorIp = "operator_code_ip";
  static const String _kOperatorFetchedAtMs = "operator_code_fetched_at_ms";

  // ✅ NEW: user_code storage key
  static const String _kUserCode = "user_code";

  // ✅ Your API
  static const String _operatorApiBase =
      "https://api.bettbit.com/file/operatorcode/ip";

  // ✅ Free IP API
  static const String _ipWhoIsUrl = "https://ipwho.is/";

  // ✅ Fallback
  static const String fallbackPlatformCode = "QN2570";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟨 [OPCODE] $msg");
  }

  String _shortBody(String body, {int limit = 260}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File("${dir.path}/operator_code.json");
  }

  // ✅ Generate USER-YYYY-TIMESTAMP (USER fixed)
  String _generateUserCode() {
    final year = DateTime.now().year;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "USER-$year-$ts";
  }

  /// ✅ Get stored user_code (prefs -> file backup)
  Future<String?> getStoredUserCode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getString(_kUserCode) ?? "").trim();
    if (v.isNotEmpty) return v;

    // File backup fallback
    try {
      final f = await _backupFile();
      if (await f.exists()) {
        final raw = await f.readAsString();
        final j = jsonDecode(raw);
        if (j is Map && (j["user_code"] ?? "").toString().trim().isNotEmpty) {
          final code = (j["user_code"] ?? "").toString().trim();
          _log("Recovered user_code from file backup: $code");

          await prefs.setString(_kUserCode, code);
          return code;
        }
      }
    } catch (e) {
      _log("File backup read (user_code) failed: $e");
    }

    return null;
  }

  /// ✅ Create once and persist (always returns non-empty)
  Future<String> getOrCreateUserCode() async {
    final existing = await getStoredUserCode();
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();

    final created = _generateUserCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserCode, created);

    _log("✅ Created user_code => $created (saved in SharedPreferences)");

    // best-effort: also write into file backup
    try {
      final f = await _backupFile();
      Map<String, dynamic> backup = {};

      if (await f.exists()) {
        try {
          final raw = await f.readAsString();
          final j = jsonDecode(raw);
          if (j is Map) backup = Map<String, dynamic>.from(j);
        } catch (_) {}
      }

      backup["user_code"] = created;
      backup["saved_at_ms"] = DateTime.now().millisecondsSinceEpoch;

      await f.writeAsString(jsonEncode(backup));
      _log("🗂️ File backup updated with user_code: ${f.path}");
    } catch (e) {
      _log("File backup write (user_code) failed: $e");
    }

    return created;
  }

  Future<String?> getStoredOperatorCode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getString(_kOperatorCode) ?? "").trim();
    if (v.isNotEmpty) return v;

    // File backup fallback
    try {
      final f = await _backupFile();
      if (await f.exists()) {
        final raw = await f.readAsString();
        final j = jsonDecode(raw);
        if (j is Map &&
            (j["operator_code"] ?? "").toString().trim().isNotEmpty) {
          final code = (j["operator_code"] ?? "").toString().trim();
          _log("Recovered operator_code from file backup: $code");

          await prefs.setString(_kOperatorCode, code);
          return code;
        }
      }
    } catch (e) {
      _log("File backup read failed: $e");
    }

    return null;
  }

  /// Call this on app start.
  /// It will ONLY hit network if operator_code is missing.
  Future<void> boot() async {
    // ✅ Ensure user_code exists early (no network)
    await getOrCreateUserCode();

    final existing = await getStoredOperatorCode();
    if (existing != null && existing.trim().isNotEmpty) {
      _log("boot(): already stored => $existing (skip network)");
      return;
    }

    _log("boot(): operator_code missing, fetching...");
    await _fetchAndStoreOperatorCode();
  }

  /// Use this when you NEED the code (e.g., before register).
  /// If missing, it fetches once.
  Future<String> getOrFetchOperatorCode() async {
    // ✅ Ensure user_code exists (no network)
    await getOrCreateUserCode();

    final existing = await getStoredOperatorCode();
    if (existing != null && existing.trim().isNotEmpty) return existing;

    _log("getOrFetchOperatorCode(): missing, fetching now...");
    final fetched = await _fetchAndStoreOperatorCode();
    return (fetched ?? "").trim().isNotEmpty
        ? fetched!.trim()
        : fallbackPlatformCode;
  }

  /// ✅ Build device_name = "<brand> <model>"
  Future<String> _getDeviceName() async {
    try {
      final plugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        final brand = (a.brand).trim();
        final model = (a.model).trim();
        final combined =
            [brand, model].where((s) => s.isNotEmpty).join(" ").trim();

        _log("📱 device_name(Android) => $combined");
        return combined.isNotEmpty ? combined : "Android";
      }

      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        final model = (i.utsname.machine).trim(); // e.g. iPhone14,2
        final combined = ("Apple $model").trim();

        _log("📱 device_name(iOS) => $combined");
        return combined.isNotEmpty ? combined : "iOS";
      }

      final generic = Platform.operatingSystem;
      _log("📱 device_name(Other) => $generic");
      return generic;
    } catch (e) {
      _log("❌ _getDeviceName error: $e");
      return Platform.operatingSystem;
    }
  }

  Future<String?> _fetchAndStoreOperatorCode() async {
    try {
      // ✅ Ensure user_code exists (no network)
      final userCode = await getOrCreateUserCode();

      // 1) Get public IP
      final ip = await _fetchPublicIp();
      if (ip == null || ip.trim().isEmpty) {
        _log("❌ public IP not available, cannot fetch operator_code");
        return null;
      }

      // 2) Build device_name
      final deviceName = await _getDeviceName();

      _log("📦 Payload Params:");
      _log("   • ip_address  = ${ip.trim()}");
      _log("   • device_name = $deviceName");
      _log("   • user_code   = $userCode");

      // 3) Build API URL with query params
      final queryParams = <String, String>{
        "ip_address": ip.trim(),
        "device_name": deviceName,
        "user_code": userCode, // ✅ NEW PARAM
      };

      final uri =
          Uri.parse(_operatorApiBase).replace(queryParameters: queryParams);

      _log("➡️ Calling operator API:");
      _log("   • base = $_operatorApiBase");
      _log("   • query = $queryParams");
      _log("   • final_url = $uri");

      final res = await http.get(uri).timeout(const Duration(seconds: 12));

      _log("⬅️ operator API response:");
      _log("   • status = ${res.statusCode}");
      _log("   • body   = ${_shortBody(res.body)}");

      if (res.statusCode != 200) {
        _log("❌ operator API failed: ${res.statusCode}");
        return null;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        _log("❌ operator API invalid json shape");
        return null;
      }

      final status = (decoded["status"] ?? "").toString().trim();
      final operatorCode = (decoded["operator_code"] ?? "").toString().trim();
      final ipEcho = (decoded["ip_address"] ?? ip).toString().trim();

      _log("✅ Parsed response:");
      _log("   • status        = $status");
      _log("   • operator_code = $operatorCode");
      _log("   • ip_address    = $ipEcho");

      if (status != "SUCCESS" || operatorCode.isEmpty) {
        _log("⚠️ operator API not SUCCESS or missing operator_code");
        return null;
      }

      // 4) Save in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOperatorCode, operatorCode);
      await prefs.setString(_kOperatorIp, ipEcho);
      await prefs.setInt(
        _kOperatorFetchedAtMs,
        DateTime.now().millisecondsSinceEpoch,
      );

      // ✅ Persist user_code too
      await prefs.setString(_kUserCode, userCode);

      _log("💾 Saved in SharedPreferences:");
      _log("   • $_kOperatorCode = $operatorCode");
      _log("   • $_kOperatorIp   = $ipEcho");
      _log("   • $_kOperatorFetchedAtMs = ${DateTime.now().millisecondsSinceEpoch}");
      _log("   • $_kUserCode = $userCode");

      // 5) Save file backup
      try {
        final f = await _backupFile();
        final backup = {
          "operator_code": operatorCode,
          "ip_address": ipEcho,
          "device_name": deviceName,
          "user_code": userCode,
          "saved_at_ms": DateTime.now().millisecondsSinceEpoch,
        };
        await f.writeAsString(jsonEncode(backup));
        _log("🗂️ File backup saved: ${f.path}");
      } catch (e) {
        _log("File backup write failed: $e");
      }

      _log("✅ Stored operator_code => $operatorCode (ip=$ipEcho)");
      return operatorCode;
    } catch (e) {
      _log("❌ _fetchAndStoreOperatorCode error: $e");
      return null;
    }
  }

  Future<String?> _fetchPublicIp() async {
    try {
      final uri = Uri.parse(_ipWhoIsUrl);
      _log("➡️ Fetching IP from: $uri");

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      _log("⬅️ ipwho.is status=${res.statusCode} body=${_shortBody(res.body)}");

      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;

      if (decoded["success"] == false) return null;

      final ip = (decoded["ip"] ?? "").toString().trim();
      _log("✅ Public IP from ipwho.is => $ip");

      return ip.isNotEmpty ? ip : null;
    } catch (e) {
      _log("❌ _fetchPublicIp error: $e");
      return null;
    }
  }
}
