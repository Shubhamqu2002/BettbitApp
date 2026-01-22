// lib/services/otp_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../util/crypto_utils.dart';

class OtpService {
  static const String _root = "https://communications.bettbit.com";
  static const String _geoUrl = "https://ipwho.is/";

  static String? _cachedCallingCode;
  static String? _cachedCountryCode;

  String _shortBody(String body, {int limit = 500}) {
    if (body.length <= limit) return body;
    return "${body.substring(0, limit)}...";
  }

  /// ✅ Extracts message from any error response (JSON or plain)
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

  Future<void> _detectGeoOnce() async {
    if (_cachedCallingCode != null && _cachedCountryCode != null) {
      debugPrint("🌍 [GEO] Using cached values → "
          "country=$_cachedCountryCode, calling=$_cachedCallingCode");
      return;
    }

    debugPrint("🌍 [GEO] Fetching geo info from ipwho.is...");

    try {
      final res = await http
          .get(Uri.parse(_geoUrl), headers: {"accept": "application/json"})
          .timeout(const Duration(seconds: 8));

      debugPrint("🌍 [GEO] HTTP ${res.statusCode}");

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);

        if (data is Map && data["success"] == true) {
          final countryCode = (data["country_code"] ?? "").toString().trim();
          final callingCodeRaw = (data["calling_code"] ?? "").toString().trim();

          if (countryCode.isNotEmpty && callingCodeRaw.isNotEmpty) {
            _cachedCountryCode = countryCode;
            _cachedCallingCode = "+$callingCodeRaw";

            debugPrint(
              "✅ [GEO] Detected → "
              "country=$_cachedCountryCode | "
              "calling=$_cachedCallingCode",
            );
            return;
          }
        }

        debugPrint("⚠️ [GEO] Invalid response body: ${_shortBody(res.body)}");
      }
    } catch (e) {
      debugPrint("❌ [GEO] Detection failed: $e");
    }

    _cachedCountryCode = "IN";
    _cachedCallingCode = "+91";
    debugPrint(
      "⚠️ [GEO] Fallback used → "
      "country=$_cachedCountryCode | calling=$_cachedCallingCode",
    );
  }

  Future<String> getCallingCode() async {
    await _detectGeoOnce();
    return _cachedCallingCode!;
  }

  Future<String> getCountryCode() async {
    await _detectGeoOnce();
    return _cachedCountryCode!;
  }

  String normalizePhoneWithCode(String input, String callingCode) {
    var v = input.trim().replaceAll(' ', '').replaceAll('-', '');

    if (v.startsWith('+')) v = v.substring(1);
    v = v.replaceAll(RegExp(r'[^0-9]'), '');

    if (v.length > 10) {
      v = v.substring(v.length - 10);
    }

    final cc = callingCode.startsWith("+") ? callingCode : "+$callingCode";
    final normalized = "$cc$v";

    debugPrint("📞 [PHONE] Normalized → $normalized");
    return normalized;
  }

  Future<String> buildEncryptedUserIdentifier(String mobileNumber) async {
    final cc = await getCallingCode();
    final normalized = normalizePhoneWithCode(mobileNumber, cc);
    final encrypted = encryptText(normalized);

    debugPrint("🔐 [OTP] Encrypted user_identifier → $encrypted");
    return encrypted;
  }

  Future<void> sendLoginOtp({required String mobileNumber}) async {
    final encryptedIdentifier = await buildEncryptedUserIdentifier(mobileNumber);
    final url = Uri.parse("$_root/webhook/otp");

    final payload = {
      "operator_id": "n8n",
      "source": "LOGIN",
      "user_identifier": encryptedIdentifier,
      "vendor_name": "TWILIO",
      "message_type": "OTP",
      "message_body":
          "XXXXXX is your BETTBIT OTP. Please use it to proceed further. Enjoy  BETTBIT.",
      "channel": "SIM",
    };

    debugPrint("📦 [SEND OTP] Payload → $payload");

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {"content-type": "application/json"},
        body: jsonEncode(payload),
      );
    } catch (_) {
      throw Exception('Network error. Please try again.');
    }

    debugPrint("📡 [SEND OTP] Response → ${res.statusCode} | ${_shortBody(res.body)}");

    if (res.statusCode != 200) {
      final msg = _extractErrorMessage(
        res.body,
        fallback: 'Failed to send OTP. Please try again.',
      );
      throw Exception(msg);
    }
  }

  Future<void> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    final encryptedIdentifier = await buildEncryptedUserIdentifier(mobileNumber);
    final url = Uri.parse("$_root/webhook/verify-otp");

    final payload = {
      "user_identifier": encryptedIdentifier,
      "otp": otp,
      "operator_id": "n8n",
      "source": "LOGIN",
    };

    debugPrint("📦 [VERIFY OTP] Payload → $payload");

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {"content-type": "application/json"},
        body: jsonEncode(payload),
      );
    } catch (_) {
      throw Exception('Network error. Please try again.');
    }

    debugPrint(
      "📡 [VERIFY OTP] Response → ${res.statusCode} | ${_shortBody(res.body)}",
    );

    if (res.statusCode != 200) {
      final msg = _extractErrorMessage(
        res.body,
        fallback: 'OTP verification failed. Please try again.',
      );
      throw Exception(msg);
    }
  }
}
