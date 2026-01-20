import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';

class AppsFlyerService {
  AppsFlyerService._();
  static final AppsFlyerService instance = AppsFlyerService._();

  AppsflyerSdk? _sdk;
  bool _started = false;

  bool get isStarted => _started;

  Future<void> init() async {
    if (_started) return;

    final devKey = (dotenv.env['APPSFLYER_DEV_KEY'] ?? '').trim();
    if (devKey.isEmpty) {
      debugPrint('⚠️ [AF] Missing APPSFLYER_DEV_KEY in .env');
      return;
    }

    final options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: '', // iOS only (App Store ID). Keep empty for Android-only.
      showDebug: kDebugMode,
      manualStart: false,
    );

    final sdk = AppsflyerSdk(options);

    await sdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    sdk.onInstallConversionData((res) {
      debugPrint('✅ [AF] Install conversion: $res');
    });

    sdk.onAppOpenAttribution((res) {
      debugPrint('✅ [AF] App open attribution: $res');
    });

    sdk.onDeepLinking((res) {
      debugPrint('✅ [AF] Deep link: $res');
    });

    sdk.startSDK(); // returns void (do NOT await)

    _sdk = sdk;
    _started = true;

    debugPrint('✅ [AF] SDK started (global service)');
  }

  Future<void> logEvent(String name, Map<String, dynamic> values) async {
    try {
      if (!_started || _sdk == null) {
        debugPrint('⚠️ [AF] logEvent skipped (SDK not started): $name');
        return;
      }
      await _sdk!.logEvent(name, values);
      debugPrint('✅ [AF] event sent: $name $values');
    } catch (e) {
      debugPrint('❌ [AF] event failed: $e');
    }
  }
}
