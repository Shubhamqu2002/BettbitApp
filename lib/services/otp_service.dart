// lib/services/otp_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../util/crypto_utils.dart';

class OtpService {
  static const String _root = "https://communications.nexxorra.com";
  static const String _geoUrl = "https://ipapi.co/json/";

  // Cache calling code so we don't hit geo API repeatedly
  static String? _cachedCallingCode;

  /// Get dynamic calling code based on device public IP location.
  /// Fallback: "+91"
  Future<String> getCallingCode() async {
    if (_cachedCallingCode != null && _cachedCallingCode!.trim().isNotEmpty) {
      return _cachedCallingCode!;
    }

    try {
      final res = await http
          .get(Uri.parse(_geoUrl), headers: {"accept": "application/json"})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);

        // ipapi.co usually returns: "country_calling_code": "+91"
        final code = (data is Map && data["country_calling_code"] != null)
            ? data["country_calling_code"].toString().trim()
            : "";

        if (code.isNotEmpty && code.startsWith("+")) {
          _cachedCallingCode = code;
          debugPrint("🌍 Detected calling code: $_cachedCallingCode");
          return _cachedCallingCode!;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Calling code detection failed: $e");
    }

    _cachedCallingCode = "+91";
    debugPrint("🌍 Fallback calling code: $_cachedCallingCode");
    return _cachedCallingCode!;
  }

  /// Normalize number into +<callingCode><digits>
  /// Rules:
  /// - Input can be 10 digits, 91+10 digits, +91+10 digits, etc.
  /// - We keep LAST 10 digits as national number (India-style),
  ///   because your examples are Indian numbers. If you want fully global,
  ///   tell me and I’ll adjust to per-country length.
  String normalizePhoneWithCode(String input, String callingCode) {
    var v = input.trim().replaceAll(' ', '').replaceAll('-', '');

    // remove leading "+"
    if (v.startsWith('+')) v = v.substring(1);

    // keep digits only
    v = v.replaceAll(RegExp(r'[^0-9]'), '');

    // Keep last 10 digits (works for your current flow)
    if (v.length > 10) {
      v = v.substring(v.length - 10);
    }

    // Ensure callingCode starts with +
    final cc = callingCode.startsWith("+") ? callingCode : "+$callingCode";

    return "$cc$v";
  }

  /// Build encrypted user_identifier = encryptText("+<cc><number>")
  Future<String> buildEncryptedUserIdentifier(String mobileNumber) async {
    final cc = await getCallingCode();
    final normalized = normalizePhoneWithCode(mobileNumber, cc);

    debugPrint("📞 Normalized phone (for user_identifier): $normalized");

    final encryptedMobile = encryptText(normalized);
    debugPrint("🔐 Encrypted user_identifier: $encryptedMobile");

    return encryptedMobile;
  }

  /// Send OTP to WhatsApp
  /// ✅ all hardcoded except "user_identifier"
  /// ✅ NO "country_calling_code" param in payload
  Future<void> sendLoginOtp({required String mobileNumber}) async {
    final encryptedIdentifier = await buildEncryptedUserIdentifier(mobileNumber);

    final url = Uri.parse("$_root/webhook/otp");

    final payload = {
      "operator_id": "n8n",
      "source": "LOGIN",
      "user_identifier": encryptedIdentifier,
      "vendor_name": "VERIFYWAY",
      "message_type": "OTP",
      "message_body": "Your OTP is XXXXXX",
      "channel": "WHATSAPP",
    };

    debugPrint("📦 Send OTP payload: $payload");

    final res = await http.post(
      url,
      headers: {"content-type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint("📡 Send OTP response: ${res.statusCode} -> ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("OTP send failed (${res.statusCode}): ${res.body}");
    }
  }

  /// Verify OTP
  /// ✅ hardcoded except "user_identifier" and "otp"
  /// ✅ NO "country_calling_code" param in payload
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

    debugPrint("📦 Verify OTP payload: $payload");

    final res = await http.post(
      url,
      headers: {"content-type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint("📡 Verify OTP response: ${res.statusCode} -> ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("OTP verify failed (${res.statusCode}): ${res.body}");
    }
  }
}
