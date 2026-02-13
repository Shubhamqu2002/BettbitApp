// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';

// ✅ AppsFlyer SDK wrapper
import 'services/analytics/appsflyer_service.dart';

// ✅ Poller boot (starts polling if pending INV refs exist)
import 'services/deposit/appsflyer_deposit_poller_service.dart';

// ✅ NEW: Operator code boot
import 'services/operator_code_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (must be in project root and added in pubspec assets)
  await dotenv.load(fileName: ".env");

  // ✅ Start AppsFlyer once (global)
  await AppsFlyerService.instance.init();

  // ✅ NEW: Fetch + store operator_code once on app start (only if missing)
  await OperatorCodeService.instance.boot();

  // ✅ Cold start: try boot once (if any pending references exist)
  await AppsFlyerDepositPollerService.instance.boot();

  runApp(const IGamingApp());
}

class IGamingApp extends StatefulWidget {
  const IGamingApp({super.key});

  @override
  State<IGamingApp> createState() => _IGamingAppState();
}

class _IGamingAppState extends State<IGamingApp> with WidgetsBindingObserver {
  Timer? _resumeDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeDebounce?.cancel();
    super.dispose();
  }

  /// Called on app lifecycle changes (minimize / resume etc.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(milliseconds: 450), () async {
        await AppsFlyerDepositPollerService.instance.boot();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Gaming App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: SplashPage.routeName,
      routes: {
        SplashPage.routeName: (context) => const SplashPage(),
        LoginPage.routeName: (context) => const LoginPage(),
        RegisterPage.routeName: (context) => const RegisterPage(),
        HomePage.routeName: (context) => const HomePage(),
      },
    );
  }
}
