import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/appsflyer_service.dart';

class AppsFlyerDepositPollerService {
  AppsFlyerDepositPollerService._();
  static final AppsFlyerDepositPollerService instance =
      AppsFlyerDepositPollerService._();

  // ✅ Your API
  static const String _ftdUrl =
      "https://walletservice.bettbit.com/api/wallet/appflyer/ftd";

  // ✅ SharedPreferences keys
  static const String _kPendingRefs = "af_pending_deposit_refs";
  static const String _kProcessedRefs = "af_processed_deposit_refs";

  Timer? _timer;
  bool _isTickRunning = false;

  bool get isRunning => _timer != null;

  /// ✅ Call this once at app start (main.dart)
  Future<void> boot() async {
    // If pending refs exist, start polling immediately.
    final refs = await getPendingReferences();
    if (refs.isNotEmpty) {
      startPolling();
    }
  }

  /// ✅ Add new merchant_reference to local pending list
  Future<void> addPendingReference(String merchantReference) async {
    final ref = merchantReference.trim();
    if (ref.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kPendingRefs) ?? [];

    if (!existing.contains(ref)) {
      existing.add(ref);
      await prefs.setStringList(_kPendingRefs, existing);
      debugPrint("✅ [AF-POLLER] Added pending ref: $ref");
    }

    // Start polling whenever a new ref is added
    startPolling();
  }

  /// ✅ Read all pending refs
  Future<List<String>> getPendingReferences() async {
    final prefs = await SharedPreferences.getInstance();
    final refs = prefs.getStringList(_kPendingRefs) ?? [];
    return refs.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// ✅ Start the 2-minute polling
  void startPolling() {
    if (_timer != null) return;

    debugPrint("✅ [AF-POLLER] Polling started (every 2 minutes)");
    // Immediate tick on start
    _tick();

    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _tick());
  }

  /// ✅ Stop polling when no refs remain
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    debugPrint("🛑 [AF-POLLER] Polling stopped (no pending refs)");
  }

  /// ✅ One polling cycle
  Future<void> _tick() async {
    if (_isTickRunning) return;
    _isTickRunning = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // You said wallet_id comes from SharedPreferences where you saved gamer_id
      final walletId = (prefs.getString('gamer_id') ?? '').trim();
      if (walletId.isEmpty) {
        debugPrint("⚠️ [AF-POLLER] Missing gamer_id (wallet_id). Stop polling.");
        stopPolling();
        return;
      }

      final currency = (prefs.getString('currency') ?? 'INR').trim();
      final pendingRefs = (prefs.getStringList(_kPendingRefs) ?? [])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (pendingRefs.isEmpty) {
        stopPolling();
        return;
      }

      debugPrint("🔄 [AF-POLLER] Checking refs: $pendingRefs");

      final res = await http
          .post(
            Uri.parse(_ftdUrl),
            headers: const {"Content-Type": "application/json"},
            body: jsonEncode({
              "wallet_id": walletId,
              "reference_no": pendingRefs,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final status = res.statusCode;
      final raw = res.body;

      debugPrint("✅ [AF-POLLER] Status=$status raw=$raw");

      if (status < 200 || status >= 300) {
        debugPrint("⚠️ [AF-POLLER] FTD API failed. Will retry next cycle.");
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final responseList = decoded["response"];
      if (responseList is! List) return;

      // For idempotency: avoid sending event twice
      final processed = prefs.getStringList(_kProcessedRefs) ?? [];

      final stillPending = <String>[];
      final toRemove = <String>[];

      for (final item in responseList) {
        if (item is! Map) continue;

        final ref = (item["reference_no"] ?? "").toString().trim();
        if (ref.isEmpty) continue;

        final statusStr = (item["status"] ?? "").toString().toUpperCase().trim();
        final isApproved = (item["is_approved"] == true);
        final firstTime = (item["first_time_deposit"] == true);

        final amountNum = item["amount"];
        final amount = (amountNum is num) ? amountNum.toDouble() : 0.0;

        final depositCountNum = item["deposit_count"];
        final depositCount = (depositCountNum is num) ? depositCountNum.toInt() : 0;

        if (statusStr == "PENDING") {
          stillPending.add(ref);
          continue;
        }

        // Final state (APPROVED / REJECTED / others)
        if (statusStr == "APPROVED" && isApproved) {
          // Prevent duplicates
          if (!processed.contains(ref)) {
            final eventName =
                (firstTime || depositCount <= 1) ? "af_first_deposit" : "af_recurring_deposit";

            await AppsFlyerService.instance.logEvent(eventName, {
              "af_revenue": amount,
              "af_currency": currency.isEmpty ? "INR" : currency,
              "af_content_type": "deposit",
              "af_transaction_id": ref, // ✅ best: use reference_no as unique txn id
            });

            processed.add(ref);
            await prefs.setStringList(_kProcessedRefs, processed);

            debugPrint("✅ [AF-POLLER] Event fired: $eventName for $ref");
          } else {
            debugPrint("ℹ️ [AF-POLLER] Already processed ref: $ref (skip event)");
          }

          toRemove.add(ref);
          continue;
        }

        // If rejected or approved-but-not-approved-flag or anything else: remove & no event
        debugPrint("ℹ️ [AF-POLLER] Final state no-event for $ref: status=$statusStr is_approved=$isApproved");
        toRemove.add(ref);
      }

      // Update pending list: keep only still pending
      final updatedPending = pendingRefs.where((r) => stillPending.contains(r)).toList();

      await prefs.setStringList(_kPendingRefs, updatedPending);

      debugPrint("🧾 [AF-POLLER] Updated pending refs: $updatedPending");

      if (updatedPending.isEmpty) {
        stopPolling();
      }
    } catch (e) {
      debugPrint("❌ [AF-POLLER] Tick error: $e");
      // don't stop; try again next cycle
    } finally {
      _isTickRunning = false;
    }
  }
}
