// lib/services/otp_register_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../util/crypto_utils.dart';
import 'register_services.dart';

class OtpRegisterService {
  static const String _root = "https://communications.nexxorra.com";

  final RegisterService _registerService;

  OtpRegisterService(this._registerService);

  /// Encrypt identifier = encryptText("+<cc><number>")
  Future<String> _buildEncryptedUserIdentifier(String rawPhone) async {
    final geo = await _registerService.fetchGeoInfo();
    final callingCode = (geo['calling_code'] ?? '+91').toString();

    final normalized =
        _registerService.normalizePhoneWithCallingCode(rawPhone, callingCode);

    debugPrint("📞 [OTP][REGISTER] Normalized identifier => $normalized");

    final enc = encryptText(normalized);
    debugPrint("🔐 [OTP][REGISTER] Encrypted user_identifier => $enc");

    return enc;
  }

  Future<void> sendRegisterOtp({required String phone}) async {
    final encryptedIdentifier = await _buildEncryptedUserIdentifier(phone);

    final url = Uri.parse("$_root/webhook/otp");

    final payload = {
      "operator_id": "n8n",
      "source": "REGISTER",
      "user_identifier": encryptedIdentifier,
      "vendor_name": "VERIFYWAY",
      "message_type": "OTP",
      "message_body": "Your OTP is XXXXXX",
      "channel": "WHATSAPP",
    };

    debugPrint("📦 [OTP][SEND][REGISTER] Payload => $payload");

    final res = await http.post(
      url,
      headers: {"content-type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint("📡 [OTP][SEND][REGISTER] Response => ${res.statusCode} | ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("REGISTER OTP send failed (${res.statusCode}): ${res.body}");
    }
  }

  Future<void> verifyRegisterOtp({
    required String phone,
    required String otp,
  }) async {
    final encryptedIdentifier = await _buildEncryptedUserIdentifier(phone);

    final url = Uri.parse("$_root/webhook/verify-otp");

    final payload = {
      "user_identifier": encryptedIdentifier,
      "otp": otp,
      "operator_id": "n8n",
      "source": "REGISTER",
    };

    debugPrint("📦 [OTP][VERIFY][REGISTER] Payload => $payload");

    final res = await http.post(
      url,
      headers: {"content-type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint("📡 [OTP][VERIFY][REGISTER] Response => ${res.statusCode} | ${res.body}");

    if (res.statusCode != 200) {
      throw Exception("REGISTER OTP verify failed (${res.statusCode}): ${res.body}");
    }
  }
}
