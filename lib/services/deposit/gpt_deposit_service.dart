import 'dart:convert';
import 'package:demo_gamer/util/crypto_utils.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GptDepositService {
  static const String _initUrl =
      "https://payment.bettbit.com/api/invoice/initiate";

  /// Fetch public IP (remoteAddr / ip_address)
  /// Uses ipify. Falls back to 0.0.0.0 safely.
  Future<String> fetchPublicIp() async {
    try {
      final res = await http
          .get(Uri.parse("https://api.ipify.org?format=json"))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        final ip =
            (data is Map && data["ip"] != null) ? data["ip"].toString() : "";
        return ip.trim().isEmpty ? "0.0.0.0" : ip.trim();
      }
      return "0.0.0.0";
    } catch (_) {
      return "0.0.0.0";
    }
  }

  /// Reads saved username from SharedPreferences
  /// You store it as: prefs.setString('user_name', data['userName'] ?? '');
  Future<String> _getSavedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString('user_name') ?? '';
      return u.trim();
    } catch (_) {
      return '';
    }
  }

  /// INV-YEAR-TIMESTAMP (INV hardcoded, year dynamic, timestamp = DateTime.now().millisecondsSinceEpoch)
  String _buildInvoiceReference() {
    final year = DateTime.now().year; // e.g., 2026
    final ts = DateTime.now().millisecondsSinceEpoch; // e.g., 946553635353
    return "INV-$year-$ts";
  }

  /// Calls GPT invoice initiate API
  ///
  /// Return map:
  /// {
  ///   ok: bool,
  ///   statusCode: int,
  ///   message: string,
  ///   payment_url: string,
  ///   reference: string
  /// }
  Future<Map<String, dynamic>> initiateInvoice({
    required num amount,
    required String currency,
    required String methodCode,
    required String callbackUrl,
    required String webhookUrl,
    required String ipAddress,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String country,
  }) async {
    try {
      final username = await _getSavedUsername();

      // ✅ Generate reference: INV-YEAR-TIMESTAMP
      final reference = _buildInvoiceReference();

      // ✅ Encrypt email like AuthService
      final encryptedEmail = encryptText(email);

      final payload = {
        "amount": amount,
        "currency": currency,
        "method_code": methodCode,
        "callback_url": callbackUrl,
        "webhook_url": webhookUrl,
        "ip_address": ipAddress,
        "username": username,

        // ✅ NEW: reference (after username, as you asked)
        "reference": reference,

        "customer": {
          "first_name": firstName,
          "last_name": lastName,
          "email": encryptedEmail, // ✅ encrypted
          "phone": phone,
          "country": country,
        }
      };

      // ✅ DEBUG: request logs
      print("📦 [GPT INIT] URL: $_initUrl");
      print("📦 [GPT INIT] method_code: $methodCode");
      print("👤 [GPT INIT] username: $username");
      print("🧾 [GPT INIT] reference: $reference");
      print("🔐 [GPT INIT] Encrypted email: $encryptedEmail");
      print("📦 [GPT INIT] Payload: ${jsonEncode(payload)}");

      final res = await http
          .post(
            Uri.parse(_initUrl),
            headers: const {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;

      // ✅ DEBUG: response logs
      print("✅ [GPT INIT] Status: $status");
      print("✅ [GPT INIT] Raw Response: ${res.body}");

      dynamic decoded;
      try {
        decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      } catch (_) {
        decoded = res.body;
      }

      final ok = status >= 200 && status < 300;

      String message = ok ? "Success" : "Request failed";
      String paymentUrl = "";
      String referenceFromApi = "";

      if (decoded is Map) {
        final m = decoded["message"] ?? decoded["msg"] ?? decoded["error"];
        if (m != null) message = m.toString();

        final d1 = decoded["data"];
        if (d1 is Map) {
          final innerData = d1["data"];
          if (innerData is Map) {
            final url = innerData["payment_url"];
            if (url != null) paymentUrl = url.toString();

            final ref = innerData["reference"];
            if (ref != null) referenceFromApi = ref.toString();
          }
        }
      }

      // ✅ If API didn't return reference, keep the one we generated
      final finalReference =
          referenceFromApi.trim().isNotEmpty ? referenceFromApi : reference;

      // ✅ DEBUG: extracted fields
      print("🔗 [GPT INIT] Extracted payment_url: $paymentUrl");
      print("🧾 [GPT INIT] Extracted reference: $finalReference");

      if (ok && paymentUrl.trim().isEmpty) {
        return {
          "ok": false,
          "statusCode": status,
          "message": "payment_url not found in response",
          "payment_url": "",
          "reference": finalReference,
        };
      }

      return {
        "ok": ok,
        "statusCode": status,
        "message": message,
        "payment_url": paymentUrl,
        "reference": finalReference,
      };
    } catch (e) {
      print("❌ [GPT INIT] Error: $e");
      return {
        "ok": false,
        "statusCode": 0,
        "message": "Network error: $e",
        "payment_url": "",
        "reference": "",
      };
    }
  }
}
