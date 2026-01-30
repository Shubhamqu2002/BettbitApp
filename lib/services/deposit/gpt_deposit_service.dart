// lib/services/deposit/gpt_deposit_service.dart
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
    final ts = DateTime.now().millisecondsSinceEpoch;
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
  ///   reference: string,          // gateway reference (ex: arkF1IUY...)
  ///   merchant_reference: string  // INV-YYYY-TS (THIS is what you pass to ftd api)
  /// }
  Future<Map<String, dynamic>> initiateInvoice({
    required num amount,
    required String currency,
    required String methodCode,
    required String callbackUrl,
    required String webhookUrl,
    required String ipAddress,
    required String country,
  }) async {
    try {
      final username = await _getSavedUsername();

      // ✅ Generate merchant_reference: INV-YEAR-TIMESTAMP
      final localMerchantReference = _buildInvoiceReference();

      // ✅ Kept import usage safe (not sent now). You can remove if not needed.
      // ignore: unused_local_variable
      final encryptedEmail = encryptText("");

      final payload = {
        "amount": amount,
        "currency": currency,
        "method_code": methodCode,
        "callback_url": callbackUrl,
        "webhook_url": webhookUrl,
        "ip_address": ipAddress,
        "username": username,

        // ✅ merchant reference you track for FTD polling
        "reference": localMerchantReference,

        // ✅ Keep customer object, ONLY country
        "customer": {
          "country": country,
        }
      };

      // ✅ DEBUG: request logs
      print("📦 [GPT INIT] URL: $_initUrl");
      print("📦 [GPT INIT] method_code: $methodCode");
      print("👤 [GPT INIT] username: $username");
      print("🧾 [GPT INIT] local merchant_reference: $localMerchantReference");
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

      // gateway reference (like "arkF1IUY...")
      String referenceFromApi = "";

      // merchant_reference (INV-...)
      String merchantReferenceFromApi = "";

      if (decoded is Map) {
        final m = decoded["message"] ?? decoded["msg"] ?? decoded["error"];
        if (m != null) message = m.toString();

        final d1 = decoded["data"];
        if (d1 is Map) {
          final innerData = d1["data"];
          if (innerData is Map) {
            final url = innerData["payment_url"];
            if (url != null) paymentUrl = url.toString();

            // ✅ Gateway reference
            final ref = innerData["reference"];
            if (ref != null) referenceFromApi = ref.toString();

            // ✅ Merchant reference (INV-...)
            final mr = innerData["merchant_reference"];
            if (mr != null) merchantReferenceFromApi = mr.toString();
          }
        }
      }

      // ✅ Fallbacks
      final finalReference =
          referenceFromApi.trim().isNotEmpty ? referenceFromApi : "";

      final finalMerchantReference = merchantReferenceFromApi.trim().isNotEmpty
          ? merchantReferenceFromApi.trim()
          : localMerchantReference;

      // ✅ DEBUG: extracted fields
      print("🔗 [GPT INIT] Extracted payment_url: $paymentUrl");
      print("🧾 [GPT INIT] Extracted reference: $finalReference");
      print("🧾 [GPT INIT] Extracted merchant_reference: $finalMerchantReference");

      if (ok && paymentUrl.trim().isEmpty) {
        return {
          "ok": false,
          "statusCode": status,
          "message": "Payment Server Down Please try again later",
          "payment_url": "",
          "reference": finalReference,
          "merchant_reference": finalMerchantReference,
        };
      }

      return {
        "ok": ok,
        "statusCode": status,
        "message": message,
        "payment_url": paymentUrl,
        "reference": finalReference,
        "merchant_reference": finalMerchantReference,
      };
    } catch (e) {
      print("❌ [GPT INIT] Error: $e");
      return {
        "ok": false,
        "statusCode": 0,
        "message": "Network error: $e",
        "payment_url": "",
        "reference": "",
        "merchant_reference": "",
      };
    }
  }
}
