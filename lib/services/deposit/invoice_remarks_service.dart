// lib/services/deposit/invoice_remarks_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InvoiceRemarksService {
  InvoiceRemarksService._();
  static final InvoiceRemarksService instance = InvoiceRemarksService._();

  static const String _base = "https://payment.bettbit.com";

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟠 [InvoiceRemarksService] $msg");
  }

  /// PATCH https://payment.bettbit.com/api/invoice/remarks/{merchantRef}?remarks=...
  /// Returns true if status is 200/204, else false.
  Future<bool> updateRemarks({
    required String merchantReference, // e.g. INV-2026-...
    required String remarks, // e.g. App is not available
  }) async {
    final mr = merchantReference.trim();
    if (mr.isEmpty) {
      _log("Skipped: empty merchantReference");
      return false;
    }

    try {
      final uri = Uri.parse("$_base/api/invoice/remarks/$mr")
          .replace(queryParameters: {"remarks": remarks});

      _log("PATCH $uri");
      final res = await http.patch(uri).timeout(const Duration(seconds: 12));

      final ok = res.statusCode == 200 || res.statusCode == 204;
      if (!ok) {
        _log("Failed: ${res.statusCode} body=${res.body}");
      } else {
        _log("Success: ${res.statusCode}");
      }

      // (Optional) parse body if needed later; not required now
      if (kDebugMode && res.body.isNotEmpty) {
        try {
          jsonDecode(res.body);
        } catch (_) {}
      }

      return ok;
    } catch (e) {
      _log("Error: $e");
      return false;
    }
  }
}
