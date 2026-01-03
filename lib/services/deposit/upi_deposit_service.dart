import 'dart:convert';
import 'package:http/http.dart' as http;

class UpiDepositService {
  static const String _payUrl =
      "https://payment.bettbit.com/billblend/pay";

  /// Fetch public IP (remoteAddr)
  /// Uses ipify. Falls back to 0.0.0.0 safely.
  Future<String> fetchPublicIp() async {
    try {
      final res = await http
          .get(Uri.parse("https://api.ipify.org?format=json"))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        final ip = data is Map && data["ip"] != null
            ? data["ip"].toString()
            : "";
        return ip.trim().isEmpty ? "0.0.0.0" : ip.trim();
      }
      return "0.0.0.0";
    } catch (_) {
      return "0.0.0.0";
    }
  }

  /// POST payload (BILLBLEND only)
  /// {
  ///   "username": "...",
  ///   "amount": 300,
  ///   "remoteAddr": "x.x.x.x",
  ///   "group_id": "<DYNAMIC GROUP ID>"
  /// }
  Future<Map<String, dynamic>> createUpiRedirect({
    required String username,
    required num amount,
    required String remoteAddr,
    required String groupId, // ✅ ALWAYS dynamic from DepositMethod
  }) async {
    try {
      final payload = {
        "username": username,
        "amount": amount,
        "remoteAddr": remoteAddr,
        "group_id": groupId, // ✅ CORRECT & COUNTRY-SAFE
      };

      final res = await http
          .post(
            Uri.parse(_payUrl),
            headers: const {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      dynamic decoded;

      try {
        decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      } catch (_) {
        decoded = res.body;
      }

      final ok = status >= 200 && status < 300;
      String message = ok ? "Success" : "Request failed";
      String? redirectUrlRaw;

      if (decoded is Map) {
        final m =
            decoded["message"] ?? decoded["msg"] ?? decoded["error"];
        if (m != null) message = m.toString();
        if (decoded["redirectUrl"] != null) {
          redirectUrlRaw = decoded["redirectUrl"].toString();
        }
      }

      final redirectUrlDecoded =
          _extractAndDecodeRedirectUrl(redirectUrlRaw);

      if (ok &&
          (redirectUrlDecoded == null ||
              redirectUrlDecoded.trim().isEmpty)) {
        return {
          "ok": false,
          "statusCode": status,
          "message": "Redirect URL not found in response",
          "redirectUrlRaw": redirectUrlRaw,
          "redirectUrlDecoded": null,
        };
      }

      return {
        "ok": ok,
        "statusCode": status,
        "message": message,
        "redirectUrlRaw": redirectUrlRaw,
        "redirectUrlDecoded": redirectUrlDecoded,
      };
    } catch (e) {
      return {
        "ok": false,
        "statusCode": 0,
        "message": "Network error: $e",
        "redirectUrlRaw": null,
        "redirectUrlDecoded": null,
      };
    }
  }

  /// Extract and decode redirect-url param safely
  String? _extractAndDecodeRedirectUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    const key = "redirect-url=";
    final idx = s.indexOf(key);

    if (idx == -1) {
      if (s.startsWith("http://") || s.startsWith("https://")) {
        return s;
      }
      return null;
    }

    final part = s.substring(idx + key.length);
    final stopAmp = part.indexOf("&");
    final stopNl = part.indexOf("\n");

    int end = part.length;
    if (stopAmp != -1) end = stopAmp;
    if (stopNl != -1 && stopNl < end) end = stopNl;

    final encoded = part.substring(0, end).trim();
    if (encoded.isEmpty) return null;

    return Uri.decodeComponent(encoded);
  }
}
