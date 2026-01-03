// lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../components/gradient_background.dart';
import '../services/register_services.dart';
import '../services/brand_service.dart';

// ✅ NEW register tabs/components
import '../components/register/register_method_tabs.dart';
import '../components/register/email_register_tab.dart';
import '../components/register/phone_register_tab.dart';

class RegisterPage extends StatefulWidget {
  static const String routeName = '/register';

  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  // -------------------------
  // EMAIL TAB (existing flow)
  // -------------------------
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

  // -------------------------
  // PHONE TAB (UI only)
  // -------------------------
  final TextEditingController _pNameController = TextEditingController();
  final TextEditingController _pPhoneController = TextEditingController();
  final TextEditingController _pEmailOptionalController =
      TextEditingController();

  DateTime? _pSelectedDob;
  String? _pSelectedGender;

  // -------------------------
  // Common
  // -------------------------
  final RegisterService _registerService = RegisterService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  late TabController _tabController;

  // ✅ GEO info (ONLY country + country code)
  String? _countryCode;
  String? _country;
  bool _isGeoLoading = false;
  String? _geoError;

  final BrandService _brandService = BrandService();
  Future<String?>? _logoUrlFuture;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();

    _fetchGeoInfo();

    _logoUrlFuture = _brandService.fetchLogoUrl();
  }

  Future<void> _fetchGeoInfo() async {
    setState(() {
      _isGeoLoading = true;
      _geoError = null;
    });

    debugPrint('🧭 [REGISTER_PAGE] Fetching GEO (country + code only)...');

    try {
      final data = await _registerService.fetchGeoInfo();

      final cc = (data['country_code'] ?? '').toString().trim();
      final c = (data['country'] ?? '').toString().trim();

      debugPrint('✅ [REGISTER_PAGE] GEO => country_code=$cc | country=$c');

      setState(() {
        _countryCode = cc.isNotEmpty ? cc : null;
        _country = c.isNotEmpty ? c : null;
        _isGeoLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [REGISTER_PAGE] GEO error: $e');

      setState(() {
        _isGeoLoading = false;
        _geoError = 'Could not auto-detect location.';
        _countryCode = null;
        _country = null;
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
    super.dispose();
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? const Color(0xFF00C9A7) : Colors.black87,
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

      if (phone.isEmpty) {
        _phoneError = 'Phone number is required.';
        hasError = true;
      } else if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
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

    // ✅ Require geo? If not available, still allow register but pass empty
    final countryCode = _countryCode ?? '';
    final country = _country ?? '';

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
      _showSnack('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRegisterPhonePlaceholder() {
    final fullName = _pNameController.text.trim();
    final phone = _pPhoneController.text.trim();
    final emailOpt = _pEmailOptionalController.text.trim();

    if (fullName.isEmpty) return _showSnack('Please enter full name.');
    if (phone.isEmpty) return _showSnack('Please enter phone number.');
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      return _showSnack('Please enter a valid 10-digit phone number.');
    }
    if (emailOpt.isNotEmpty && !_isValidEmail(emailOpt)) {
      return _showSnack('Optional email is not valid.');
    }
    if (_pSelectedDob == null) return _showSnack('Please select date of birth.');
    if (_pSelectedGender == null || _pSelectedGender!.isEmpty) {
      return _showSnack('Please select gender.');
    }

    _showSnack('Phone register API not added yet. (UI ready)');
  }

  Widget _logoWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C9A7).withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        height: 80,
        child: FutureBuilder<String?>(
          future: _logoUrlFuture,
          builder: (context, snap) {
            final logoUrl = (snap.connectionState == ConnectionState.done &&
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00C9A7)),
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

  Widget _detectedCountryChip(String detectedCountryText) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00C9A7).withOpacity(0.2),
              Colors.black.withOpacity(0.3),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF00C9A7).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C9A7).withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00C9A7).withOpacity(0.3),
                    const Color(0xFF00C9A7).withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.public_outlined,
                size: 15,
                color: Color(0xFF00C9A7),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                detectedCountryText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
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
                  size: 15,
                  color: Colors.orangeAccent.withOpacity(0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Only show country + code (no currency)
    final detectedCountryText =
        (_country != null && _country!.isNotEmpty && _countryCode != null && _countryCode!.isNotEmpty)
            ? 'Detected: $_country ($_countryCode)'
            : _isGeoLoading
                ? 'Detecting country...'
                : 'Country detection unavailable';

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 70,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            color: Colors.white.withOpacity(0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFF00C9A7).withOpacity(0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
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
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: _logoWidget(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Center(
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF00C9A7), Color(0xFF00FFC6)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Text(
                                    'Join us and start your journey',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.75),
                                      letterSpacing: 0.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),
                          RegisterMethodTabs(controller: _tabController),
                          const SizedBox(height: 18),

                          Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                  spreadRadius: -5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF00C9A7).withOpacity(0.2),
                                  blurRadius: 60,
                                  spreadRadius: -10,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 560,
                              child: TabBarView(
                                controller: _tabController,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  EmailRegisterTab(
                                    nameController: _nameController,
                                    phoneController: _phoneController,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    isLoading: _isLoading,
                                    obscurePassword: _obscurePassword,
                                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                                    selectedDob: _selectedDob,
                                    selectedGender: _selectedGender,
                                    onPickDob: _pickDobForEmailTab,
                                    onGenderChanged: (v) => setState(() => _selectedGender = v),
                                    nameError: _nameError,
                                    phoneError: _phoneError,
                                    emailError: _emailError,
                                    passwordError: _passwordError,
                                    dobError: _dobError,
                                    genderError: _genderError,
                                    detectedCountryWidget: _detectedCountryChip(detectedCountryText),
                                    onRegister: _handleRegisterEmail,
                                  ),
                                  PhoneRegisterTab(
                                    fullNameController: _pNameController,
                                    phoneController: _pPhoneController,
                                    emailOptionalController: _pEmailOptionalController,
                                    selectedDob: _pSelectedDob,
                                    selectedGender: _pSelectedGender,
                                    onPickDob: _pickDobForPhoneTab,
                                    onGenderChanged: (v) => setState(() => _pSelectedGender = v),
                                    onRegister: _handleRegisterPhonePlaceholder,
                                    detectedCountryWidget: _detectedCountryChip(detectedCountryText),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 26),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.03),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.85),
                                      letterSpacing: 0.3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF00C9A7), Color(0xFF00B897)],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00C9A7).withOpacity(0.5),
                                            blurRadius: 12,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
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
