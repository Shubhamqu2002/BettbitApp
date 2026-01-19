// lib/pages/splash_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';

import '../components/gradient_background.dart';
import '../services/update/update_service.dart';
import 'update_page.dart';
import 'login_page.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  static const String routeName = '/';

  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _particleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  final List<Particle> _particles = [];

  String _versionText = 'Version 1.0.0';
  bool _navigated = false;

  // ✅ AppsFlyer
  AppsflyerSdk? _afSdk;
  bool _afStarted = false;

  @override
  void initState() {
    super.initState();

    // Generate particles
    _generateParticles();

    // ✅ Load real app version/build for UI (bottom text)
    _loadAppVersion();

    // ✅ Start AppsFlyer early (Flutter way)
    _initAppsFlyer();

    // Pulse animation for outer glow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Smooth rotation animation
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Scale animation with bounce
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // ✅ After 2.5 seconds decide where to go (includes update check)
    Timer(const Duration(milliseconds: 2500), _decideNavigationWithUpdateGate);
  }

  /// ✅ Flutter equivalent of Android `AppsFlyerLib.init(...)` in Application.onCreate
  Future<void> _initAppsFlyer() async {
    try {
      // Prefer .env; fallback to your key so app still works
      final envKey = (dotenv.env['APPSFLYER_DEV_KEY'] ?? '').trim();
      final devKey =
          envKey.isNotEmpty ? envKey : 'ZrQNxQJYWCfqApE3GtJ5SF';

      if (devKey.isEmpty) {
        debugPrint('⚠️ [AF] Missing dev key. Add APPSFLYER_DEV_KEY in .env');
        return;
      }

      final options = AppsFlyerOptions(
        afDevKey: devKey,
        appId: '', // iOS only (App Store ID). Keep empty for Android-only.
        showDebug: true, // set false in release builds
        manualStart: false, // set true if you want consent-based deferred start
      );

      final sdk = AppsflyerSdk(options);

      // IMPORTANT: initSdk returns Future<void> (don’t assign it to variables)
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );

      // Callback setters return void (don’t assign them)
      sdk.onInstallConversionData((res) {
        debugPrint('✅ [AF] Install conversion: $res');
      });

      sdk.onAppOpenAttribution((res) {
        debugPrint('✅ [AF] App open attribution: $res');
      });

      sdk.onDeepLinking((res) {
        debugPrint('✅ [AF] Deep link: $res');
      });

      sdk.startSDK();

      _afSdk = sdk;
      _afStarted = true;

      debugPrint('✅ [AF] SDK started');

      // ✅ Send a tiny event so you can verify in dashboard/debug logs
      await _logAfEvent(
        'af_splash_ready',
        {'ts': DateTime.now().millisecondsSinceEpoch},
      );
    } catch (e) {
      debugPrint('❌ [AF] init/start failed: $e');
    }
  }

  Future<void> _logAfEvent(String name, Map<String, dynamic> values) async {
    try {
      if (!_afStarted || _afSdk == null) return;
      await _afSdk!.logEvent(name, values);
      debugPrint('✅ [AF] event sent: $name $values');
    } catch (e) {
      debugPrint('❌ [AF] event failed: $e');
    }
  }

  void _generateParticles() {
    final random = Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble() * 400 - 200,
          y: random.nextDouble() * 400 - 200,
          size: random.nextDouble() * 4 + 2,
          speed: random.nextDouble() * 0.5 + 0.2,
          delay: random.nextDouble(),
        ),
      );
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionText = 'Version ${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      // keep default
    }
  }

  /// ✅ Update check happens here BEFORE deciding Home/Login
  Future<void> _decideNavigationWithUpdateGate() async {
    if (!mounted || _navigated) return;

    // Read current app version/build
    final pkg = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
    final currentVersion = pkg.version;

    // Call the provided API
    final detailsUrl = dotenv.env['APK_VERSION_DETAILS_URL'] ??
        'https://api.nexxorra.com/file/apk/version/details';

    final service = UpdateService(detailsUrl: detailsUrl);
    final result = await service.checkForUpdate();

    if (!mounted || _navigated) return;

    // If update required -> go UpdatePage (blocks login)
    if (result.needsUpdate && result.info != null) {
      _navigated = true;

      // Optional event for tracking
      await _logAfEvent('af_update_required', {
        'current_build': currentBuild,
        'current_version': currentVersion,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UpdatePage(
            info: result.info!,
            currentBuild: currentBuild,
            currentVersion: currentVersion,
          ),
        ),
      );
      return;
    }

    // Otherwise -> normal flow
    await _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final gamerId = prefs.getString('gamer_id') ?? '';

    final targetRoute = (isLoggedIn && gamerId.isNotEmpty)
        ? HomePage.routeName
        : LoginPage.routeName;

    // Optional event for tracking
    await _logAfEvent('af_splash_route', {
      'route': targetRoute,
      'is_logged_in': isLoggedIn,
      'has_gamer_id': gamerId.isNotEmpty,
    });

    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(context, targetRoute);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Animated particles background
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlePainter(
                    particles: _particles,
                    animation: _particleController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Main content
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated logo with multiple effects
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseAnimation,
                        _glowAnimation,
                      ]),
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing glow
                            Container(
                              height: 200 * _pulseAnimation.value,
                              width: 200 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF00C9A7)
                                        .withOpacity(0.15 * _glowAnimation.value),
                                    const Color(0xFF00A6FF)
                                        .withOpacity(0.1 * _glowAnimation.value),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),

                            // Middle glow ring
                            Container(
                              height: 160,
                              width: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF00C9A7)
                                        .withOpacity(0.2 * _glowAnimation.value),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C9A7)
                                        .withOpacity(0.4 * _glowAnimation.value),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),

                            // Rotating gradient border
                            RotationTransition(
                              turns: _rotateAnimation,
                              child: Container(
                                height: 140,
                                width: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      const Color(0xFF00C9A7),
                                      const Color(0xFF00A6FF),
                                      const Color(0xFF00C9A7),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Inner white border
                            Container(
                              height: 134,
                              width: 134,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.3),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 2,
                                ),
                              ),
                            ),

                            // Logo image with rotation
                            SizedBox(
                              height: 120,
                              width: 120,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: RotationTransition(
                                  turns: _rotateAnimation,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: -5,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/splash.jpeg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Center dot accent
                            Container(
                              height: 8,
                              width: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // Animated text content
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF00C9A7),
                                Color(0xFF00A6FF),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'I Gaming',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF00C9A7).withOpacity(0.5),
                                    blurRadius: 20,
                                  ),
                                  Shadow(
                                    color: const Color(0xFF00A6FF).withOpacity(0.5),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1500),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00C9A7).withOpacity(0.2),
                                    const Color(0xFF00A6FF).withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: const Color(0xFF00C9A7).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C9A7).withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Level up your play.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),

                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              return Column(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 40 * (1 + _glowAnimation.value * 0.3),
                                          height: 40 * (1 + _glowAnimation.value * 0.3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                const Color(0xFF00C9A7)
                                                    .withOpacity(0.3 * _glowAnimation.value),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                        CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            const Color(0xFF00C9A7).withOpacity(_glowAnimation.value),
                                          ),
                                          backgroundColor: Colors.white.withOpacity(0.1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.6 * _glowAnimation.value),
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _versionText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© 2024 I Gaming',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Particle class for background animation
class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double delay;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.delay,
  });
}

// Custom painter for particles
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;

  ParticlePainter({
    required this.particles,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C9A7).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (var particle in particles) {
      final progress = ((animation + particle.delay) % 1.0);
      final opacity = (1 - progress) * 0.6;

      if (opacity > 0) {
        paint.color = Color.lerp(
          const Color(0xFF00C9A7),
          const Color(0xFF00A6FF),
          particle.delay,
        )!
            .withOpacity(opacity);

        final currentX = centerX + particle.x * (1 + progress * particle.speed);
        final currentY = centerY + particle.y * (1 + progress * particle.speed);

        canvas.drawCircle(
          Offset(currentX, currentY),
          particle.size * (1 - progress * 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
