import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UpdateProfileResult {
  final bool success;
  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  UpdateProfileResult({
    required this.success,
    required this.statusCode,
    required this.message,
    this.data,
  });
}

class UpdateProfileService {
  // ✅ Base URL from .env
  static final String _base =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  /// PATCH /wallet/update-profile/{gamerId}
  /// Body can be partial:
  /// { "firstName": "..." } or { "dob": "YYYY-MM-DD" } or both
  static Future<UpdateProfileResult> updateProfile({
    required String gamerId,
    String? firstName,
    String? dob, // YYYY-MM-DD
  }) async {
    final payload = <String, dynamic>{};

    if (firstName != null && firstName.trim().isNotEmpty) {
      payload["firstName"] = firstName.trim();
    }
    if (dob != null && dob.trim().isNotEmpty) {
      payload["dob"] = dob.trim();
    }

    if (payload.isEmpty) {
      return UpdateProfileResult(
        success: false,
        statusCode: 0,
        message: "No changes to update.",
      );
    }

    final url = Uri.parse("$_base/wallet/update-profile/$gamerId");

    try {
      final res = await http.patch(
        url,
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      Map<String, dynamic>? parsed;
      String msgFromApi = "";

      // Try parse JSON (if present)
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          parsed = decoded;
          final m = decoded["message"] ??
              decoded["msg"] ??
              decoded["error"] ??
              decoded["errors"];
          if (m != null) msgFromApi = m.toString();
        }
      } catch (_) {
        // Non-JSON body
        if (res.body.trim().isNotEmpty) msgFromApi = res.body.trim();
      }

      final ok = res.statusCode == 200 || res.statusCode == 201;

      // Generate a clean message if API doesn't give one
      String fallback;
      if (ok) {
        if (payload.keys.length == 1 && payload.containsKey("firstName")) {
          fallback = "Full Name updated successfully ✅";
        } else if (payload.keys.length == 1 && payload.containsKey("dob")) {
          fallback = "Date of Birth updated successfully ✅";
        } else {
          fallback = "Profile updated successfully ✅";
        }
      } else {
        if (res.statusCode == 400) {
          fallback = "Invalid details. Please check and try again.";
        } else if (res.statusCode == 401) {
          fallback = "Unauthorized. Please login again.";
        } else if (res.statusCode == 403) {
          fallback = "Access denied.";
        } else if (res.statusCode >= 500) {
          fallback = "Server error. Please try again later.";
        } else {
          fallback = "Update failed. Please try again.";
        }
      }

      final message =
          msgFromApi.trim().isNotEmpty ? msgFromApi.trim() : fallback;

      return UpdateProfileResult(
        success: ok,
        statusCode: res.statusCode,
        message: message,
        data: parsed,
      );
    } catch (_) {
      return UpdateProfileResult(
        success: false,
        statusCode: -1,
        message: "Network error. Please check internet and try again.",
      );
    }
  }
}
