// lib/components/login/forgot_password_modal.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../services/password_reset_service.dart';

class ForgotPasswordModal extends StatefulWidget {
  final String initialEmail;
  final void Function(String message)? onSuccess;

  const ForgotPasswordModal({
    super.key,
    this.initialEmail = '',
    this.onSuccess,
  });

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  final _resetService = PasswordResetService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  String? _inlineError;
  String? _gamerId; // once found, show password fields

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isStrongPassword(String p) {
    // min 8, one uppercase, one number, one special char
    final re = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');
    return re.hasMatch(p);
  }

  void _setError(String msg) {
    setState(() => _inlineError = msg);
  }

  void _clearError() {
    if (_inlineError != null) setState(() => _inlineError = null);
  }

  Future<void> _handleContinue() async {
    _clearError();
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) return _setError('Please enter email address.');
    if (!_isValidEmail(email)) return _setError('Please enter a valid email.');

    setState(() => _loading = true);
    try {
      final gamerId = await _resetService.getGamerIdByEmail(email: email);
      setState(() => _gamerId = gamerId);
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    _clearError();
    final gid = _gamerId;
    if (gid == null || gid.isEmpty) return _setError('GamerId missing.');

    final p1 = _passCtrl.text;
    final p2 = _confirmCtrl.text;

    if (p1.isEmpty || p2.isEmpty) return _setError('Please fill both password fields.');
    if (p1 != p2) return _setError('Passwords do not match.');
    if (!_isStrongPassword(p1)) {
      return _setError('Password must be 8+ chars with 1 uppercase, 1 number, 1 special character.');
    }

    setState(() => _loading = true);
    try {
      await _resetService.resetLoginPassword(gamerId: gid, newPassword: p1);

      widget.onSuccess?.call('Password reset successful ✅ Please login again.');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 40,
                offset: const Offset(0, 18),
                spreadRadius: -6,
              ),
              BoxShadow(
                color: const Color(0xFF00C9A7).withOpacity(0.18),
                blurRadius: 60,
                spreadRadius: -10,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _decor({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.085),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00C9A7), width: 2),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.6 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF00C9A7), Color(0xFF00B897)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C9A7).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _glassContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00C9A7).withOpacity(0.22),
                              Colors.white.withOpacity(0.06),
                            ],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.14)),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Color(0xFF00C9A7),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Reset Login Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _gamerId == null
                        ? 'Enter your email to fetch your Gamer ID.'
                        : 'Gamer ID found ✅ Now set a new login password.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Inline error
                  if (_inlineError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.orange.withOpacity(0.12),
                        border: Border.all(color: Colors.orange.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.orangeAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Step 1: Email
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    enabled: !_loading && _gamerId == null,
                    decoration: _decor(
                      hint: 'Enter email address',
                      icon: Icons.email_outlined,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Step 2 fields show only after gamerId success
                  if (_gamerId != null) ...[
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure1,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      enabled: !_loading,
                      decoration: _decor(
                        hint: 'New login password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure1 = !_obscure1),
                          icon: Icon(
                            _obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: _obscure2,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      enabled: !_loading,
                      decoration: _decor(
                        hint: 'Confirm new password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure2 = !_obscure2),
                          icon: Icon(
                            _obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '• Min 8 chars • 1 uppercase • 1 number • 1 special',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Actions
                  if (_gamerId == null)
                    _primaryButton(
                      label: 'Continue',
                      onTap: _handleContinue,
                      disabled: _loading,
                    )
                  else
                    _primaryButton(
                      label: 'Reset Password',
                      onTap: _handleResetPassword,
                      disabled: _loading,
                    ),

                  const SizedBox(height: 10),

                  if (_gamerId != null)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _gamerId = null;
                                _passCtrl.clear();
                                _confirmCtrl.clear();
                                _inlineError = null;
                              });
                            },
                      child: const Text(
                        'Change email',
                        style: TextStyle(
                          color: Color(0xFF00C9A7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
