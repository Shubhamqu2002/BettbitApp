// lib/pages/register_page.dart
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../components/gradient_background.dart';
import '../services/register_services.dart';
import '../services/brand_service.dart';

// Register tabs/components
import '../components/register/register_method_tabs.dart';
import '../components/register/email_register_tab.dart';
import '../components/register/phone_register_tab.dart';

// OTP UI + services for phone register flow
import '../components/register/otp_verify_panel.dart';
import '../services/otp_register_service.dart';

class RegisterPage extends StatefulWidget {
  static const String routeName = '/register';

  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  // EMAIL TAB
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  DateTime? _selectedDob;
  String? _selectedGender;

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _dobError;
  String? _genderError;

  // PHONE TAB (OTP flow)
  final TextEditingController _pNameController = TextEditingController();
  final TextEditingController _pPhoneController = TextEditingController();
  final TextEditingController _pEmailOptionalController = TextEditingController();

  DateTime? _pSelectedDob;
  String? _pSelectedGender;

  // Services + state
  final RegisterService _registerService = RegisterService();
  late final OtpRegisterService _otpRegisterService =
      OtpRegisterService(_registerService);

  bool _isLoading = false;
  bool _isOtpLoading = false;
  bool _obscurePassword = true;
  bool _showPhoneOtpUi = false;

  static const String _phoneRegPasswordHardcoded = "Temp@1234#PHONE";
  static const String _phoneRegEmailHardcoded = "noemail@demo.local";

  late AnimationController _animationController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  late TabController _tabController;

  // GEO info
  String? _countryCode;
  String? _country;
  String? _callingCode;
  bool _isGeoLoading = false;
  String? _geoError;

  final BrandService _brandService = BrandService();
  Future<String?>? _logoUrlFuture;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
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

    _fetchGeoInfo();
    _logoUrlFuture = _brandService.fetchLogoUrl();

    _tabController.addListener(() {
      if (_tabController.index == 0) {
        setState(() => _showPhoneOtpUi = false);
      }
    });
  }

  Future<void> _fetchGeoInfo() async {
    setState(() {
      _isGeoLoading = true;
      _geoError = null;
    });

    try {
      final data = await _registerService.fetchGeoInfo();

      final cc = (data['country_code'] ?? '').toString().trim();
      final c = (data['country'] ?? '').toString().trim();
      final calling = (data['calling_code'] ?? '').toString().trim();

      setState(() {
        _countryCode = cc.isNotEmpty ? cc : null;
        _country = c.isNotEmpty ? c : null;
        _callingCode = calling.isNotEmpty ? calling : null;
        _isGeoLoading = false;
      });
    } catch (e) {
      setState(() {
        _isGeoLoading = false;
        _geoError = 'Could not auto-detect location.';
        _countryCode = null;
        _country = null;
        _callingCode = null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    _pNameController.dispose();
    _pPhoneController.dispose();
    _pEmailOptionalController.dispose();

    _tabController.dispose();
    _animationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  String _cleanApiMessage(Object e) {
    String raw = e.toString().trim();
    raw = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

    final int jsonStart = raw.indexOf('{');
    if (jsonStart != -1) {
      final jsonPart = raw.substring(jsonStart).trim();
      try {
        final decoded = jsonDecode(jsonPart);
        if (decoded is Map) {
          final msg = (decoded['message'] ?? '').toString().trim();
          if (msg.isNotEmpty) return msg;

          final err = (decoded['error'] ?? '').toString().trim();
          if (err.isNotEmpty) return err;

          final detail = (decoded['details'] ?? decoded['detail'] ?? '')
              .toString()
              .trim();
          if (detail.isNotEmpty) return detail;
        }
      } catch (_) {}
    }

    return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
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
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDob(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    final passwordRegex =
        RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');
    return passwordRegex.hasMatch(password);
  }

  Future<void> _pickDobForEmailTab() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 100, 1, 1);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00C9A7),
              surface: Color(0xFF05070A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) setState(() => _selectedDob = picked);
  }

  Future<void> _pickDobForPhoneTab() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 100, 1, 1);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _pSelectedDob ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00C9A7),
              surface: Color(0xFF05070A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) setState(() => _pSelectedDob = picked);
  }

  Future<void> _handleRegisterEmail() async {
    if (_isLoading) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool hasError = false;

    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _passwordError = null;
      _dobError = null;
      _genderError = null;

      if (name.isEmpty) {
        _nameError = 'Full name is required.';
        hasError = true;
      }

      if (phone.isNotEmpty && !RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
        _phoneError = 'Please enter a valid 10-digit phone number.';
        hasError = true;
      }

      if (email.isEmpty) {
        _emailError = 'Email is required.';
        hasError = true;
      } else if (!_isValidEmail(email)) {
        _emailError = 'Please enter a valid email address.';
        hasError = true;
      }

      if (password.isEmpty) {
        _passwordError = 'Password is required.';
        hasError = true;
      } else if (!_isValidPassword(password)) {
        _passwordError =
            'Password must be 8+ chars and include uppercase, number, and special character.';
        hasError = true;
      }

      if (_selectedDob == null) {
        _dobError = 'Date of birth is required.';
        hasError = true;
      }

      if (_selectedGender == null || _selectedGender!.isEmpty) {
        _genderError = 'Gender is required.';
        hasError = true;
      }
    });

    if (hasError) {
      _showSnack('Please correct the highlighted fields.');
      return;
    }

    final countryCode = _countryCode ?? '';
    final country = _country ?? '';
    final callingCode = _callingCode ?? '+91';

    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final firstName = parts.isNotEmpty ? parts.first : name;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    setState(() => _isLoading = true);

    try {
      final registerData = await _registerService.registerGamer(
        email: email,
        number: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
        countryCode: countryCode,
        country: country,
        dob: _formatDob(_selectedDob!),
        gender: _selectedGender!,
        registrationType: "EMAIL",
        callingCode: callingCode,
      );

      final gamerId = registerData['gamerId']?.toString() ?? '';
      final status = registerData['status']?.toString() ?? '';

      if (status == 'REGISTRATION_SUCCESSFUL' && gamerId.isNotEmpty) {
        _showSnack('Registered successfully! Please login to continue.',
            success: true);
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        throw Exception('Unexpected status: $status');
      }
    } catch (e) {
      _showSnack(_cleanApiMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePhoneRegister_SendOtp() async {
    if (_isOtpLoading) return;

    final fullName = _pNameController.text.trim();
    final phone = _pPhoneController.text.trim();
    final emailOpt = _pEmailOptionalController.text.trim();

    if (fullName.isEmpty) return _showSnack('Please enter full name.');
    if (phone.isEmpty) return _showSnack('Please enter phone number.');
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      return _showSnack('Please enter a valid 10-digit phone number.');
    }
    if (emailOpt.isNotEmpty && !_isValidEmail(emailOpt)) {
      return _showSnack('Email is not valid.');
    }
    if (_pSelectedDob == null) return _showSnack('Please select date of birth.');
    if (_pSelectedGender == null || _pSelectedGender!.isEmpty) {
      return _showSnack('Please select gender.');
    }

    setState(() => _isOtpLoading = true);

    try {
      await _otpRegisterService.sendRegisterOtp(phone: phone);
      _showSnack('OTP sent on device ✅', success: true);
      setState(() => _showPhoneOtpUi = true);
    } catch (e) {
      _showSnack(_cleanApiMessage(e));
    } finally {
      if (mounted) setState(() => _isOtpLoading = false);
    }
  }

  Future<void> _handlePhoneRegister_VerifyOtpAndRegister(String otp) async {
    if (_isOtpLoading) return;

    final name = _pNameController.text.trim();
    final phone = _pPhoneController.text.trim();
    final emailOpt = _pEmailOptionalController.text.trim();

    final emailToSend =
        emailOpt.isNotEmpty ? emailOpt : _phoneRegEmailHardcoded;

    final countryCode = _countryCode ?? '';
    final country = _country ?? '';
    final callingCode = _callingCode ?? '+91';

    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final firstName = parts.isNotEmpty ? parts.first : name;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    setState(() => _isOtpLoading = true);

    try {
      await _otpRegisterService.verifyRegisterOtp(phone: phone, otp: otp);

      final registerData = await _registerService.registerGamer(
        email: emailToSend,
        number: phone,
        password: _phoneRegPasswordHardcoded,
        firstName: firstName,
        lastName: lastName,
        countryCode: countryCode,
        country: country,
        dob: _formatDob(_pSelectedDob!),
        gender: _pSelectedGender!,
        registrationType: "PHONE",
        callingCode: callingCode,
      );

      final gamerId = registerData['gamerId']?.toString() ?? '';
      final status = registerData['status']?.toString() ?? '';

      if (status == 'REGISTRATION_SUCCESSFUL' && gamerId.isNotEmpty) {
        _showSnack('Registered successfully! Please login to continue.',
            success: true);
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        throw Exception('Unexpected status: $status');
      }
    } catch (e) {
      _showSnack(_cleanApiMessage(e));
    } finally {
      if (mounted) setState(() => _isOtpLoading = false);
    }
  }

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
                    color: const Color(0xFF00C9A7)
                        .withOpacity(0.4 * _glowAnimation.value),
                    blurRadius: 60 * _glowAnimation.value,
                    spreadRadius: 20 * _glowAnimation.value,
                  ),
                  BoxShadow(
                    color: Colors.cyanAccent
                        .withOpacity(0.2 * _glowAnimation.value),
                    blurRadius: 80 * _glowAnimation.value,
                    spreadRadius: 10 * _glowAnimation.value,
                  ),
                ],
              ),
              child: Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(18),
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

  Widget _detectedCountryChip(String detectedCountryText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.3),
        border: Border.all(
          color: const Color(0xFF00C9A7).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.public_outlined,
            size: 14,
            color: const Color(0xFF00C9A7).withOpacity(0.8),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              detectedCountryText,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_geoError != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: Colors.orangeAccent.withOpacity(0.9),
              ),
            ),
        ],
      ),
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

    final detectedCountryText = (_country != null &&
            _country!.isNotEmpty &&
            _countryCode != null &&
            _countryCode!.isNotEmpty)
        ? 'Detected: $_country ($_countryCode) • ${_callingCode ?? ""}'
        : _isGeoLoading
            ? 'Detecting country...'
            : 'Country detection unavailable';

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Floating orbs for depth
            _buildFloatingOrb(
              screenHeight * 0.15,
              screenWidth * 0.1,
              180,
              const Color(0xFF00C9A7),
            ),
            _buildFloatingOrb(
              screenHeight * 0.65,
              screenWidth * 0.75,
              140,
              Colors.cyanAccent,
            ),
            _buildFloatingOrb(
              screenHeight * 0.35,
              screenWidth * 0.85,
              100,
              const Color(0xFF00C9A7),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Custom Back Button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF00C9A7).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main scrollable content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 500),
                                child: Column(
                                  children: [
                                    // Logo with glow effect
                                    _logoWidget(),

                                    const SizedBox(height: 30),

                                    // Title with gradient
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [
                                          Color(0xFF00C9A7),
                                          Colors.cyanAccent,
                                          Color(0xFF00C9A7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      child: const Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Subtitle
                                    Text(
                                      'Join us and start your journey',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withOpacity(0.6),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 35),

                                    // Tab selector with modern design
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(25),
                                        color: Colors.black.withOpacity(0.3),
                                        border: Border.all(
                                          color: const Color(0xFF00C9A7)
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: RegisterMethodTabs(
                                          controller: _tabController),
                                    ),

                                    const SizedBox(height: 25),

                                    // Country detection chip
                                    _detectedCountryChip(detectedCountryText),

                                    const SizedBox(height: 25),

                                    // Tab content without card wrapper
                                    SizedBox(
                                      height: screenHeight < 750 ? 540 : 560,
                                      child: TabBarView(
                                        controller: _tabController,
                                        physics: const BouncingScrollPhysics(),
                                        children: [
                                          EmailRegisterTab(
                                            nameController: _nameController,
                                            phoneController: _phoneController,
                                            emailController: _emailController,
                                            passwordController:
                                                _passwordController,
                                            isLoading: _isLoading,
                                            obscurePassword: _obscurePassword,
                                            onTogglePassword: () => setState(() =>
                                                _obscurePassword =
                                                    !_obscurePassword),
                                            selectedDob: _selectedDob,
                                            selectedGender: _selectedGender,
                                            onPickDob: _pickDobForEmailTab,
                                            onGenderChanged: (v) =>
                                                setState(() => _selectedGender = v),
                                            nameError: _nameError,
                                            phoneError: _phoneError,
                                            emailError: _emailError,
                                            passwordError: _passwordError,
                                            dobError: _dobError,
                                            genderError: _genderError,
                                            detectedCountryWidget: const SizedBox
                                                .shrink(), // Not needed here anymore
                                            onRegister: _handleRegisterEmail,
                                          ),
                                          _showPhoneOtpUi
                                              ? OtpVerifyPanel(
                                                  title: "Verify OTP",
                                                  subtitle:
                                                      "Enter the 6-digit OTP sent on device",
                                                  isLoading: _isOtpLoading,
                                                  onBack: () => setState(() =>
                                                      _showPhoneOtpUi = false),
                                                  onCompleted:
                                                      _handlePhoneRegister_VerifyOtpAndRegister,
                                                )
                                              : PhoneRegisterTab(
                                                  fullNameController:
                                                      _pNameController,
                                                  phoneController:
                                                      _pPhoneController,
                                                  emailOptionalController:
                                                      _pEmailOptionalController,
                                                  selectedDob: _pSelectedDob,
                                                  selectedGender: _pSelectedGender,
                                                  onPickDob: _pickDobForPhoneTab,
                                                  onGenderChanged: (v) => setState(
                                                      () => _pSelectedGender = v),
                                                  onRegister:
                                                      _handlePhoneRegister_SendOtp,
                                                  detectedCountryWidget:
                                                      const SizedBox.shrink(),
                                                  isLoading: _isOtpLoading,
                                                ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 25),

                                    // Already have account section
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF00C9A7)
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                        color: Colors.black.withOpacity(0.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Already have an account? ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => Navigator.pop(context),
                                            child: Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF00C9A7)
                                                    .withOpacity(0.9),
                                                letterSpacing: 0.3,
                                              ),
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
          ],
        ),
      ),
    );
  }
}