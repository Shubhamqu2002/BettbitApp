// lib/services/operator_code_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class OperatorCodeService {
  OperatorCodeService._();
  static final OperatorCodeService instance = OperatorCodeService._();

  static const String _kOperatorCode = "operator_code";
  static const String _kOperatorIp = "operator_code_ip";
  static const String _kOperatorFetchedAtMs = "operator_code_fetched_at_ms";
  static const String _kUserCode = "user_code";

  static const String _operatorApiBase =
      "https://api.bettbit.com/file/operatorcode/ip";

  static const String _ipWhoIsUrl = "https://ipwho.is/";

  static const String fallbackPlatformCode = "QN2570";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟨 [OPCODE] $msg");
  }

  String _shortBody(String body, {int limit = 260}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  // ✅ TEMP TEST METHOD
  // Use this only when you want to clear saved operator_code and test API again.
  Future<void> clearOperatorCodeForTesting() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_kOperatorCode);
    await prefs.remove(_kOperatorIp);
    await prefs.remove(_kOperatorFetchedAtMs);
    await prefs.remove(_kUserCode);

    _log("🧹 Cleared operator_code, operator_ip, fetched_at, user_code");
  }

  String _generateUserCode() {
    final year = DateTime.now().year;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "USER-$year-$ts";
  }

  Future<String?> getStoredUserCode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getString(_kUserCode) ?? "").trim();
    return v.isNotEmpty ? v : null;
  }

  Future<String> getOrCreateUserCode() async {
    final existing = await getStoredUserCode();
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _generateUserCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserCode, created);

    _log("✅ Created user_code => $created");
    return created;
  }

  Future<String?> getStoredOperatorCode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getString(_kOperatorCode) ?? "").trim();
    return v.isNotEmpty ? v : null;
  }

  Future<void> boot() async {
    await getOrCreateUserCode();

    final existing = await getStoredOperatorCode();
    if (existing != null && existing.isNotEmpty) {
      _log("boot(): already stored => $existing");
      return;
    }

    _log("boot(): operator_code missing, fetching...");
    await _fetchAndStoreOperatorCode();
  }

  Future<String> getOrFetchOperatorCode() async {
    await getOrCreateUserCode();

    final existing = await getStoredOperatorCode();
    if (existing != null && existing.isNotEmpty) return existing;

    final fetched = await _fetchAndStoreOperatorCode();
    return (fetched ?? "").trim().isNotEmpty
        ? fetched!.trim()
        : fallbackPlatformCode;
  }

  Future<String> _getDeviceName() async {
    try {
      final plugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        final combined = [a.brand.trim(), a.model.trim()]
            .where((s) => s.isNotEmpty)
            .join(" ")
            .trim();

        return combined.isNotEmpty ? combined : "Android";
      }

      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        final model = i.utsname.machine.trim();
        return model.isNotEmpty ? "Apple $model" : "iOS";
      }

      return Platform.operatingSystem;
    } catch (e) {
      _log("❌ _getDeviceName error: $e");
      return Platform.operatingSystem;
    }
  }

  Future<String?> _fetchAndStoreOperatorCode() async {
    try {
      final userCode = await getOrCreateUserCode();

      final ip = await _fetchPublicIp();
      if (ip == null || ip.trim().isEmpty) {
        _log("❌ public IP not available");
        return null;
      }

      final deviceName = await _getDeviceName();

      final uri = Uri.parse(_operatorApiBase).replace(
        queryParameters: {
          "ip_address": ip.trim(),
          "device_name": deviceName,
          "user_code": userCode,
        },
      );

      _log("➡️ Calling operator API: $uri");

      final res = await http.get(uri).timeout(const Duration(seconds: 12));

      _log("⬅️ status=${res.statusCode} body=${_shortBody(res.body)}");

      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;

      final status = (decoded["status"] ?? "").toString().trim();
      final operatorCode = (decoded["operator_code"] ?? "").toString().trim();
      final ipEcho = (decoded["ip_address"] ?? ip).toString().trim();

      if (status != "SUCCESS" || operatorCode.isEmpty) {
        _log("⚠️ operator API not SUCCESS or missing operator_code");
        return null;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_kOperatorCode, operatorCode);
      await prefs.setString(_kOperatorIp, ipEcho);
      await prefs.setInt(
        _kOperatorFetchedAtMs,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString(_kUserCode, userCode);

      _log("💾 Saved only in SharedPreferences");
      _log("   • $_kOperatorCode = $operatorCode");
      _log("   • $_kUserCode = $userCode");

      return operatorCode;
    } catch (e) {
      _log("❌ _fetchAndStoreOperatorCode error: $e");
      return null;
    }
  }

  Future<String?> _fetchPublicIp() async {
    try {
      final uri = Uri.parse(_ipWhoIsUrl);

      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      if (decoded["success"] == false) return null;

      final ip = (decoded["ip"] ?? "").toString().trim();
      return ip.isNotEmpty ? ip : null;
    } catch (e) {
      _log("❌ _fetchPublicIp error: $e");
      return null;
    }
  }
}