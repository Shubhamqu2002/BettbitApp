// lib/pages/login_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../components/gradient_background.dart';
import '../components/login/login_method_tabs.dart';
import '../components/login/email_login_tab.dart';
import '../components/login/phone_login_tab.dart';
import '../components/login/forgot_password_modal.dart';
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

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;

  late AnimationController _animationController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

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
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
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
    _glowController.dispose();
    super.dispose();
  }

  String _cleanMessage(Object e) {
    final raw = e.toString().trim();
    final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
      _showSnack(_cleanMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openForgotPasswordModal() {
    showGeneralDialog(
      context: context,
      barrierLabel: "Forgot Password",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) {
        return ForgotPasswordModal(
          initialEmail: _emailController.text.trim(),
          onSuccess: (msg) {
            _showSnack(msg, success: true);
          },
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = Curves.easeOutCubic.transform(anim.value);
        return Transform.scale(
          scale: 0.96 + (0.04 * curved),
          child: Opacity(opacity: curved, child: child),
        );
      },
    );
  }

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
      _showSnack(_cleanMessage(e));
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

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
      await _otpService.verifyLoginOtp(mobileNumber: phoneRaw, otp: otp);

      final cc = await _otpService.getCallingCode();
      final normalized = _otpService.normalizePhoneWithCode(phoneRaw, cc);

      await _authService.login(emailOrPhone: normalized, type: "PHONE");

      if (!mounted) return;
      _showSnack("Login successful", success: true);
      Navigator.pushReplacementNamed(context, HomePage.routeName);
    } catch (e) {
      _showSnack(_cleanMessage(e));
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _goToRegister() => Navigator.pushNamed(context, RegisterPage.routeName);

  Widget _logoWidget() {
    return FutureBuilder<String?>(
      future: _logoUrlFuture,
      builder: (context, snap) {
        final logoUrl = (snap.connectionState == ConnectionState.done &&
                snap.hasData &&
                (snap.data ?? '').toString().trim().isNotEmpty)
            ? snap.data!.trim()
            : '';

        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C9A7).withOpacity(0.4 * _glowAnimation.value),
                    blurRadius: 60 * _glowAnimation.value,
                    spreadRadius: 20 * _glowAnimation.value,
                  ),
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.2 * _glowAnimation.value),
                    blurRadius: 80 * _glowAnimation.value,
                    spreadRadius: 10 * _glowAnimation.value,
                  ),
                ],
              ),
              child: Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00C9A7).withOpacity(0.3),
                      const Color(0xFF00C9A7).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    width: 2,
                    color: const Color(0xFF00C9A7).withOpacity(0.5),
                  ),
                ),
                child: logoUrl.isEmpty
                    ? Image.asset('assets/images/logo.png', fit: BoxFit.contain)
                    : SvgPicture.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        placeholderBuilder: (_) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00C9A7),
                            ),
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingOrb(double top, double left, double size, Color color) {
    return Positioned(
      top: top,
      left: left,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.3 * _glowAnimation.value),
                  color.withOpacity(0.1 * _glowAnimation.value),
                  Colors.transparent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Floating orbs for depth
            _buildFloatingOrb(
              screenHeight * 0.1,
              screenWidth * 0.1,
              200,
              const Color(0xFF00C9A7),
            ),
            _buildFloatingOrb(
              screenHeight * 0.6,
              screenWidth * 0.7,
              150,
              Colors.cyanAccent,
            ),
            _buildFloatingOrb(
              screenHeight * 0.3,
              screenWidth * 0.8,
              100,
              const Color(0xFF00C9A7),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo with glow effect
                              _logoWidget(),
                              
                              const SizedBox(height: 40),

                              // Welcome text with gradient
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Color(0xFF00C9A7),
                                    Colors.cyanAccent,
                                    Color(0xFF00C9A7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Subtitle
                              Text(
                                'Sign in to continue your journey',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 50),

                              // Tab selector with modern design
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: Colors.black.withOpacity(0.3),
                                  border: Border.all(
                                    color: const Color(0xFF00C9A7).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: LoginMethodTabs(controller: _tabController),
                              ),

                              const SizedBox(height: 35),

                              // Tab content without card wrapper
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
                                      passwordController: _passwordController,
                                      obscurePassword: _obscurePassword,
                                      isLoading: _isLoading,
                                      onTogglePassword: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                      onForgot: _openForgotPasswordModal,
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
                                      onVerifyOtpAndLogin: _handleVerifyOtpAndLogin,
                                      onGoRegister: _goToRegister,
                                      onBackToPhone: () {
                                        setState(() => _otpSent = false);
                                        _clearOtp();
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),

                              // Security badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00C9A7).withOpacity(0.3),
                                    width: 1,
                                  ),
                                  color: Colors.black.withOpacity(0.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      size: 18,
                                      color: const Color(0xFF00C9A7).withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Secure & Encrypted',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
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
          ],
        ),
      ),
    );
  }
}