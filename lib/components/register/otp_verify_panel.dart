// lib/components/register/otp_verify_panel.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';

class OtpVerifyPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onBack;
  final ValueChanged<String> onCompleted;

  const OtpVerifyPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onBack,
    required this.onCompleted,
  });

  @override
  State<OtpVerifyPanel> createState() => _OtpVerifyPanelState();
}

class _OtpVerifyPanelState extends State<OtpVerifyPanel>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  // ✅ SmartAuth (Android SMS User Consent)
  final SmartAuth _smartAuth = SmartAuth.instance;
  bool _consentListening = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _startSmartAuthListener(); // ✅ start listening as soon as panel opens
    });
  }

  @override
  void dispose() {
    _stopSmartAuthListener();
    _animationController.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _startSmartAuthListener() async {
    if (!Platform.isAndroid) return; // consent flow is Android-only
    if (_consentListening) return;
    _consentListening = true;

    try {
      // ignore: avoid_print
      print(
          "✅ [REGISTER_OTP_AUTOFILL] SmartAuth: Listening (User Consent API)...");

      final SmartAuthResult<SmartAuthSms> result =
          await _smartAuth.getSmsWithUserConsentApi();

      if (!mounted) return;

      // allow restarting later if needed
      _consentListening = false;

      if (result.hasData) {
        final SmartAuthSms data = result.requireData;

        final String smsText = data.sms; // full SMS
        final String codeText =
            (data.code ?? "").toString(); // extracted code (optional)

        // ignore: avoid_print
        print("✅ [REGISTER_OTP_AUTOFILL] Received SMS: $smsText");
        // ignore: avoid_print
        print("✅ [REGISTER_OTP_AUTOFILL] Received code: $codeText");

        final String combined = codeText.isNotEmpty ? codeText : smsText;
        final otp = _extractSixDigitOtp(combined);

        if (otp != null) {
          _applyOtp(otp);
        } else {
          // ignore: avoid_print
          print("⚠️ [REGISTER_OTP_AUTOFILL] Could not extract 6-digit OTP.");
        }
      } else if (result.isCanceled) {
        // ignore: avoid_print
        print("⚠️ [REGISTER_OTP_AUTOFILL] User canceled consent dialog.");
      } else if (result.hasError) {
        // ignore: avoid_print
        print(
            "⚠️ [REGISTER_OTP_AUTOFILL] SmartAuth error: ${result.error?.toString()}");
      } else {
        // ignore: avoid_print
        print("⚠️ [REGISTER_OTP_AUTOFILL] No SMS captured (unknown state).");
      }
    } catch (e) {
      _consentListening = false;
      // ignore: avoid_print
      print("⚠️ [REGISTER_OTP_AUTOFILL] SmartAuth exception: ${e.toString()}");
    }
  }

  void _stopSmartAuthListener() {
    try {
      _smartAuth.removeUserConsentApiListener();
      // ignore: avoid_print
      print("✅ [REGISTER_OTP_AUTOFILL] SmartAuth listener stopped");
    } catch (_) {}
  }

  String? _extractSixDigitOtp(String text) {
    final match = RegExp(r'(\d{6})').firstMatch(text);
    return match?.group(1);
  }

  void _applyOtp(String otp) {
    if (otp.length != 6) return;

    _ctrl.text = otp;
    _ctrl.selection = TextSelection.collapsed(offset: otp.length);

    // hide keyboard after autofill
    FocusManager.instance.primaryFocus?.unfocus();

    // ignore: avoid_print
    print("✅ [REGISTER_OTP_AUTOFILL] Autofilled OTP: $otp");

    setState(() {});
    widget.onCompleted(otp);
  }

  void _sanitizeAndSet(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits != _ctrl.text) {
      _ctrl.text = digits;
      _ctrl.selection = TextSelection.collapsed(offset: digits.length);
    }
    setState(() {});
    if (digits.length == 6) widget.onCompleted(digits);
  }

  @override
  Widget build(BuildContext context) {
    final boxSize = 52.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title
          Row(
            children: [
              InkWell(
                onTap: widget.isLoading ? null : widget.onBack,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Hidden input but we render boxes based on its text
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [
                AutofillHints.oneTimeCode
              ], // ✅ iOS suggestion support
              decoration: const InputDecoration(counterText: ""),
              onChanged: _sanitizeAndSet,
            ),
          ),

          // OTP Boxes
          ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: () {
                _focus.requestFocus();
                _startSmartAuthListener(); // ✅ if user taps again, ensure listener is active
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final ch = i < _ctrl.text.length ? _ctrl.text[i] : '';
                    final isFilled = ch.isNotEmpty;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: isFilled ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          width: boxSize,
                          height: boxSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: isFilled
                                  ? [
                                      const Color(0xFF00C9A7).withOpacity(0.15),
                                      const Color(0xFF00E5B8).withOpacity(0.1),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.08),
                                      Colors.white.withOpacity(0.04),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: isFilled
                                  ? Color.lerp(
                                      Colors.white.withOpacity(0.2),
                                      const Color(0xFF00C9A7),
                                      value,
                                    )!
                                  : Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              if (isFilled)
                                BoxShadow(
                                  color: const Color(0xFF00C9A7)
                                      .withOpacity(0.3 * value),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AnimatedScale(
                            scale: isFilled ? 1.0 : 0.8,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Text(
                              ch,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                shadows: isFilled
                                    ? [
                                        Shadow(
                                          color: const Color(0xFF00C9A7)
                                              .withOpacity(0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Loading indicator
          if (widget.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF00C9A7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Verifying your code...",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

          // Helper text when not loading
          if (!widget.isLoading && _ctrl.text.length < 6)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Enter the 6-digit code sent to your device",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}