// lib/pages/login_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../components/gradient_background.dart';
import '../components/login/login_method_tabs.dart';
import '../components/login/email_login_tab.dart';
import '../components/login/phone_login_tab.dart';
import 'register_page.dart';
import 'home_page.dart';
import '../services/auth_service.dart';
import '../services/brand_service.dart';
import '../services/otp_service.dart';

class LoginPage extends StatefulWidget {
  static const String routeName = '/login';

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  late TabController _tabController;

  final AuthService _authService = AuthService();
  final OtpService _otpService = OtpService();

  final BrandService _brandService = BrandService();
  Future<String?>? _logoUrlFuture;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
    _logoUrlFuture = _brandService.fetchLogoUrl();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();

    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }

    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? const Color(0xFF00C9A7) : Colors.orangeAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getOtpValue() => _otpControllers.map((e) => e.text.trim()).join();

  void _clearOtp() {
    for (final c in _otpControllers) {
      c.clear();
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.login(
        emailOrPhone: email,
        password: password,
        type: "EMAIL",
      );

      if (!mounted) return;
      _showSnack("Login successful", success: true);
      Navigator.pushReplacementNamed(context, HomePage.routeName);
    } catch (e) {
      _showSnack('Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ PHONE STEP 1: Send OTP
  Future<void> _handleSendOtp() async {
    final phoneRaw = _phoneController.text.trim();
    if (phoneRaw.isEmpty) {
      _showSnack('Please enter phone number.');
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      await _otpService.sendLoginOtp(mobileNumber: phoneRaw);

      if (!mounted) return;
      setState(() => _otpSent = true);

      _clearOtp();
      _otpFocusNodes.first.requestFocus();

      _showSnack("OTP sent successfully", success: true);
    } catch (e) {
      _showSnack("Failed to send OTP: $e");
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  /// ✅ PHONE STEP 2+3: Verify OTP then Login (type=PHONE, no password)
  Future<void> _handleVerifyOtpAndLogin() async {
    final phoneRaw = _phoneController.text.trim();
    final otp = _getOtpValue();

    if (phoneRaw.isEmpty) {
      _showSnack('Please enter phone number.');
      return;
    }
    if (otp.length != 6) {
      _showSnack('Please enter 6-digit OTP.');
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      // 1) Verify OTP
      await _otpService.verifyLoginOtp(mobileNumber: phoneRaw, otp: otp);

      // 2) Build normalized phone using dynamic calling code
      final cc = await _otpService.getCallingCode();
      final normalized = _otpService.normalizePhoneWithCode(phoneRaw, cc);

      // 3) Login (PHONE, NO password)
      await _authService.login(emailOrPhone: normalized, type: "PHONE");

      if (!mounted) return;
      _showSnack("Login successful", success: true);
      Navigator.pushReplacementNamed(context, HomePage.routeName);
    } catch (e) {
      _showSnack("Login failed: $e");
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _goToRegister() => Navigator.pushNamed(context, RegisterPage.routeName);

  Widget _logoWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C9A7).withOpacity(0.4),
            blurRadius: 45,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        height: 85,
        child: FutureBuilder<String?>(
          future: _logoUrlFuture,
          builder: (context, snap) {
            final logoUrl =
                (snap.connectionState == ConnectionState.done &&
                    snap.hasData &&
                    (snap.data ?? '').toString().trim().isNotEmpty)
                ? snap.data!.trim()
                : '';

            if (logoUrl.isEmpty) {
              return Image.asset('assets/images/logo.png', fit: BoxFit.contain);
            }

            return SvgPicture.network(
              logoUrl,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00C9A7),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: const Color(0xFF00C9A7).withOpacity(0.25),
                blurRadius: 65,
                spreadRadius: -12,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _gradientOutline({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C9A7).withOpacity(0.4),
            Colors.white.withOpacity(0.25),
            const Color(0xFF00C9A7).withOpacity(0.15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C9A7).withOpacity(0.3),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.white.withOpacity(0.03),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.18),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: _logoWidget(),
                                ),
                                const SizedBox(height: 26),
                              ],
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0xFF00C9A7),
                                Colors.white,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Welcome Back 👋',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00C9A7).withOpacity(0.2),
                                  const Color(0xFF00C9A7).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00C9A7).withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00C9A7,
                                  ).withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Play and Win',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Color(0xFF00C9A7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          _gradientOutline(
                            child: _glassCard(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  22,
                                  22,
                                  20,
                                ),
                                child: Column(
                                  children: [
                                    LoginMethodTabs(controller: _tabController),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: _tabController.index == 0
                                          ? 410
                                          : (_otpSent ? 420 : 320),
                                      child: TabBarView(
                                        controller: _tabController,
                                        physics: const BouncingScrollPhysics(),
                                        children: [
                                          EmailLoginTab(
                                            emailController: _emailController,
                                            passwordController:
                                                _passwordController,
                                            obscurePassword: _obscurePassword,
                                            isLoading: _isLoading,
                                            onTogglePassword: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                            onForgot: () {},
                                            onLogin: _handleEmailLogin,
                                            onGoRegister: _goToRegister,
                                          ),
                                          PhoneLoginTab(
                                            phoneController: _phoneController,
                                            otpSent: _otpSent,
                                            otpControllers: _otpControllers,
                                            otpFocusNodes: _otpFocusNodes,
                                            isSendingOtp: _isSendingOtp,
                                            isVerifyingOtp: _isVerifyingOtp,
                                            onSendOtp: _handleSendOtp,
                                            onVerifyOtpAndLogin:
                                                _handleVerifyOtpAndLogin,
                                            onGoRegister: _goToRegister,

                                            // ✅ NEW: Back to phone UI
                                            onBackToPhone: () {
                                              setState(() => _otpSent = false);
                                              _clearOtp();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.06),
                                  Colors.white.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  size: 16,
                                  color: const Color(
                                    0xFF00C9A7,
                                  ).withOpacity(0.8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Secure Login',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
