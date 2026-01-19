// lib/services/otp_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../util/crypto_utils.dart';

class OtpService {
  static const String _root = "https://communications.bettbit.com";
  static const String _geoUrl = "https://ipwho.is/";

  // Cached values (avoid repeated geo calls)
  static String? _cachedCallingCode; // +880
  static String? _cachedCountryCode; // BD

  /* -------------------------------------------------------
   * GEO DETECTION (ipwho.is)
   * ----------------------------------------------------- */

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
          final countryCode =
              (data["country_code"] ?? "").toString().trim();
          final callingCodeRaw =
              (data["calling_code"] ?? "").toString().trim();

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

        debugPrint("⚠️ [GEO] Invalid response body: ${res.body}");
      }
    } catch (e) {
      debugPrint("❌ [GEO] Detection failed: $e");
    }

    // fallback (only if API fails)
    _cachedCountryCode = "IN";
    _cachedCallingCode = "+91";
    debugPrint(
      "⚠️ [GEO] Fallback used → "
      "country=$_cachedCountryCode | calling=$_cachedCallingCode",
    );
  }

  /// Public getter for calling code (+880, +91, etc.)
  Future<String> getCallingCode() async {
    await _detectGeoOnce();
    return _cachedCallingCode!;
  }

  /// Public getter for country code (BD, IN, etc.)
  Future<String> getCountryCode() async {
    await _detectGeoOnce();
    return _cachedCountryCode!;
  }

  /* -------------------------------------------------------
   * PHONE NORMALIZATION
   * ----------------------------------------------------- */

  /// Normalize number → +<callingCode><last 10 digits>
  /// Example:
  /// input: 01712345678
  /// output: +8801712345678
  String normalizePhoneWithCode(String input, String callingCode) {
    var v = input.trim().replaceAll(' ', '').replaceAll('-', '');

    // remove "+"
    if (v.startsWith('+')) v = v.substring(1);

    // digits only
    v = v.replaceAll(RegExp(r'[^0-9]'), '');

    // keep last 10 digits (your current backend expectation)
    if (v.length > 10) {
      v = v.substring(v.length - 10);
    }

    final cc = callingCode.startsWith("+") ? callingCode : "+$callingCode";

    final normalized = "$cc$v";
    debugPrint("📞 [PHONE] Normalized → $normalized");

    return normalized;
  }

  /* -------------------------------------------------------
   * ENCRYPTED IDENTIFIER
   * ----------------------------------------------------- */

  Future<String> buildEncryptedUserIdentifier(String mobileNumber) async {
    final cc = await getCallingCode();
    final normalized = normalizePhoneWithCode(mobileNumber, cc);

    final encrypted = encryptText(normalized);

    debugPrint("🔐 [OTP] Encrypted user_identifier → $encrypted");

    return encrypted;
  }

  /* -------------------------------------------------------
   * SEND OTP
   * ----------------------------------------------------- */

  Future<void> sendLoginOtp({required String mobileNumber}) async {
    final encryptedIdentifier =
        await buildEncryptedUserIdentifier(mobileNumber);

    final url = Uri.parse("$_root/webhook/otp");

    final payload = {
      "operator_id": "n8n",
      "source": "LOGIN",
      "user_identifier": encryptedIdentifier,
      "vendor_name": "TWILIO",
      "message_type": "OTP",
      "message_body": "XXXXXX is your BETTBIT OTP. Please use it to proceed further. Enjoy  BETTBIT.",
      "channel": "SIM",
    };

    debugPrint("📦 [SEND OTP] Payload → $payload");

    final res = await http.post(
      url,
      headers: {"content-type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint(
      "📡 [SEND OTP] Response → ${res.statusCode} | ${res.body}",
    );

    if (res.statusCode != 200) {
      throw Exception(
        "OTP send failed (${res.statusCode}): ${res.body}",
      );
    }
  }

  /* -------------------------------------------------------
   * VERIFY OTP
   * ----------------------------------------------------- */

  Future<void> verifyLoginOtp({
    required String mobileNumber,
    required String otp,
  }) async {
    final encryptedIdentifier =
        await buildEncryptedUserIdentifier(mobileNumber);

    final url = Uri.parse("$_root/webhook/verify-otp");

    final payload = {
      "user_identifier": encryptedIdentifier,
      "otp": otp,
      "operator_id": "n8n",
      "source": "LOGIN",
    };

    debugPrint("📦 [VERIFY OTP] Payload → $payload");

    final res = await http.post(
      url,
      headers: {"content-type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint(
      "📡 [VERIFY OTP] Response → ${res.statusCode} | ${res.body}",
    );

    if (res.statusCode != 200) {
      throw Exception(
        "OTP verify failed (${res.statusCode}): ${res.body}",
      );
    }
  }
}
