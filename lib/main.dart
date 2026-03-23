// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';

// ✅ AppsFlyer SDK wrapper
import 'services/analytics/appsflyer_service.dart';

// ✅ Poller boot (starts polling if pending INV refs exist)
import 'services/deposit/appsflyer_deposit_poller_service.dart';

// ✅ Operator code boot
import 'services/operator_code_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (must be in project root and added in pubspec assets)
  await dotenv.load(fileName: ".env");

  // ✅ Start AppsFlyer once (global)
  await AppsFlyerService.instance.init();

  // ✅ Fetch + store operator_code once on app start (only if missing)
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

  // ✅ Deep links
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  // ✅ Allows navigation from deep-link callbacks safely
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  // ✅ Store pending route if user is not logged in
  static const String _kPendingDeepLinkRoute = "pending_deeplink_route";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeDebounce?.cancel();
    _linkSub?.cancel();
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

  // -------------------- Auth / SharedPrefs helpers --------------------
  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final gamerId = (prefs.getString('gamer_id') ?? '').trim();

    // Your rule: logged in only if flag true AND gamer_id exists
    return isLoggedIn && gamerId.isNotEmpty;
  }

  Future<void> _setPendingDeepLinkRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingDeepLinkRoute, route);
  }

  Future<void> clearPendingDeepLinkRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingDeepLinkRoute);
  }

  // -------------------- Deep Links (Custom Scheme: bettbit://open) --------------------
  Future<void> _initDeepLinks() async {
    // ✅ Cold start: app opened from killed state by deep link
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("🚀 Initial deep link: $initialUri");
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("❌ getInitialLink error: $e");
    }

    // ✅ While app is running
    _linkSub = _appLinks.uriLinkStream.listen((Uri uri) {
      debugPrint("🔁 Incoming deep link: $uri");
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("❌ uriLinkStream error: $err");
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Expected format:
    // bettbit://open
    // bettbit://open?screen=home
    // bettbit://open?screen=login
    if (uri.scheme != "bettbit" || uri.host != "open") return;

    final qp = uri.queryParameters;
    final screen = (qp["screen"] ?? "").trim().toLowerCase();

    debugPrint("✅ Deep link matched. screen=$screen, params=$qp");

    // Map deep link screen -> route
    String requestedRoute;
    switch (screen) {
      case "login":
        requestedRoute = LoginPage.routeName;
        break;
      case "register":
        requestedRoute = RegisterPage.routeName;
        break;
      case "home":
      default:
        requestedRoute = HomePage.routeName;
        break;
    }

    final loggedIn = await _isLoggedIn();
    debugPrint("🔐 Deep link auth check => loggedIn=$loggedIn");

    // ✅ Gate: if trying to go HOME but user not logged in
    // (You can extend this rule to other protected routes too.)
    final bool isProtected = requestedRoute == HomePage.routeName;

    String finalRoute = requestedRoute;
    if (isProtected && !loggedIn) {
      // Save what user wanted, so after login you can redirect
      await _setPendingDeepLinkRoute(requestedRoute);

      // Force to login
      finalRoute = LoginPage.routeName;

      debugPrint(
        "⛔ Not logged in. Saved pending route=$requestedRoute, redirecting to Login.",
      );
    } else {
      // If logged in and deep link is fine, clear any old pending
      await clearPendingDeepLinkRoute();
    }

    // Navigate AFTER first frame to avoid context/nav not ready issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navKey.currentState;
      if (nav == null) return;

      // Replace stack so user doesn't go back to splash
      nav.pushNamedAndRemoveUntil(finalRoute, (r) => false);
    });
  }
  // -------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Gaming App',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
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
