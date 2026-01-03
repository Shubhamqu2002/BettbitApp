// lib/components/login/phone_login_tab.dart
import 'package:flutter/material.dart';
import '../primary_button.dart';
import '../../services/otp_service.dart';

class PhoneLoginTab extends StatefulWidget {
  final TextEditingController phoneController;

  // OTP state
  final bool otpSent;
  final List<TextEditingController> otpControllers;
  final List<FocusNode> otpFocusNodes;

  final bool isSendingOtp;
  final bool isVerifyingOtp;

  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtpAndLogin;

  final VoidCallback onGoRegister;

  // ✅ NEW: Back button handler to return to phone screen
  final VoidCallback onBackToPhone;

  const PhoneLoginTab({
    super.key,
    required this.phoneController,
    required this.otpSent,
    required this.otpControllers,
    required this.otpFocusNodes,
    required this.isSendingOtp,
    required this.isVerifyingOtp,
    required this.onSendOtp,
    required this.onVerifyOtpAndLogin,
    required this.onGoRegister,
    required this.onBackToPhone,
  });

  @override
  State<PhoneLoginTab> createState() => _PhoneLoginTabState();
}

class _PhoneLoginTabState extends State<PhoneLoginTab> {
  final OtpService _otpService = OtpService();

  String _callingCode = "";
  bool _ccLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCallingCode();
  }

  Future<void> _loadCallingCode() async {
    setState(() => _ccLoading = true);
    try {
      final cc = await _otpService.getCallingCode();
      if (!mounted) return;
      setState(() {
        _callingCode = cc;
        _ccLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _callingCode = "";
        _ccLoading = false;
      });
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        letterSpacing: 0.3,
        color: Colors.white,
      ),
    );
  }

  Widget _glassContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _callingCodePill() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00C9A7).withOpacity(0.28),
            Colors.white.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00C9A7).withOpacity(0.40),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C9A7).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 18, color: Colors.white.withOpacity(0.92)),
          const SizedBox(width: 10),
          _ccLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.92)),
                  ),
                )
              : Text(
                  _callingCode.isNotEmpty ? _callingCode : "—",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _phoneField() {
    return _glassContainer(
      child: TextField(
        controller: widget.phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          hintText: 'Enter phone number',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(
            Icons.phone_iphone_rounded,
            color: Colors.white.withOpacity(0.75),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF00C9A7), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _registerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        GestureDetector(
          onTap: widget.onGoRegister,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF00C9A7), width: 2),
              ),
            ),
            child: const Text(
              'Register',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00C9A7),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextField(
        controller: widget.otpControllers[i],
        focusNode: widget.otpFocusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.09),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00C9A7), width: 2),
          ),
        ),
        onChanged: (v) {
          if (v.length == 1 && i < widget.otpFocusNodes.length - 1) {
            widget.otpFocusNodes[i + 1].requestFocus();
          }
          if (v.isEmpty && i > 0) {
            widget.otpFocusNodes[i - 1].requestFocus();
          }
        },
      ),
    );
  }

  String _maskPhone(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return "";
    if (v.length <= 4) return v;
    final last4 = v.substring(v.length - 4);
    return "•••• •••• $last4";
  }

  Widget _phoneScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00C9A7).withOpacity(0.18),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: const Color(0xFF00C9A7).withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_rounded, color: Color(0xFF00C9A7), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "We’ll send an OTP to your WhatsApp for verification from VerifyWay.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.8,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        _label('Phone Number'),
        const SizedBox(height: 10),

        // ✅ Better alignment + premium row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _callingCodePill(),
            const SizedBox(width: 12),
            Expanded(child: _phoneField()),
          ],
        ),

        const SizedBox(height: 18),

        PrimaryButton(
          label: 'Continue',
          onPressed: widget.onSendOtp,
          isLoading: widget.isSendingOtp,
        ),

        const SizedBox(height: 18),
        _registerRow(),
      ],
    );
  }

  Widget _otpScreen() {
    final masked = _maskPhone(widget.phoneController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),

        // ✅ Back row
        Row(
          children: [
            InkWell(
              onTap: widget.onBackToPhone,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 6),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00C9A7).withOpacity(0.22),
                    Colors.white.withOpacity(0.06),
                  ],
                ),
                border: Border.all(color: const Color(0xFF00C9A7).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF00C9A7)),
                  const SizedBox(width: 6),
                  Text(
                    "OTP Verification",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Success banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00C9A7).withOpacity(0.22),
                Colors.white.withOpacity(0.06),
              ],
            ),
            border: Border.all(color: const Color(0xFF00C9A7).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C9A7).withOpacity(0.15),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00C9A7), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "OTP sent successfully from VerifyWay",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // phone preview + resend
        if (masked.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_iphone_rounded,
                    size: 18, color: Colors.white.withOpacity(0.85)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    masked,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onSendOtp,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00C9A7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: const Text(
                    "Resend",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        _label("Enter 6-digit OTP"),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _otpBox(i)),
        ),

        const SizedBox(height: 18),

        PrimaryButton(
          label: 'Verify & Login',
          onPressed: widget.onVerifyOtpAndLogin,
          isLoading: widget.isVerifyingOtp,
        ),

        const SizedBox(height: 18),
        _registerRow(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: widget.otpSent
            ? Container(key: const ValueKey("otp_screen"), child: _otpScreen())
            : Container(key: const ValueKey("phone_screen"), child: _phoneScreen()),
      ),
    );
  }
}
