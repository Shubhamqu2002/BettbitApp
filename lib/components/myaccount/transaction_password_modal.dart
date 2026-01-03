import 'package:flutter/material.dart';

import '../../services/password/change_transaction_password_service.dart';

class TransactionPasswordModal extends StatefulWidget {
  const TransactionPasswordModal({super.key});

  @override
  State<TransactionPasswordModal> createState() =>
      _TransactionPasswordModalState();
}

class _TransactionPasswordModalState extends State<TransactionPasswordModal> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;

  bool hasUpper = false;
  bool hasLower = false;
  bool hasDigit = false;
  bool hasSpecial = false;
  bool hasLength = false;

  bool _isSubmitting = false;

  // Elegant color palette
  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);
  static const Color successAccent = Color(0xFF10B981);

  final ChangeTransactionPasswordService _service =
      ChangeTransactionPasswordService();

  void _validate(String value) {
    setState(() {
      hasUpper = RegExp(r'[A-Z]').hasMatch(value);
      hasLower = RegExp(r'[a-z]').hasMatch(value);
      hasDigit = RegExp(r'\d').hasMatch(value);
      hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);
      hasLength = value.length >= 8;
    });
  }

  bool get isValid =>
      hasUpper && hasLower && hasDigit && hasSpecial && hasLength;

  Widget _rule(String text, bool ok) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok
            ? successAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok
              ? successAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: ok
                  ? successAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              size: 14,
              color: ok ? successAccent : Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok
                    ? Colors.white.withOpacity(0.9)
                    : Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!isValid || _isSubmitting) return;

    final pass = _passwordController.text.trim();
    if (pass.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await _service.changeTransactionPassword(newPasswordPlain: pass);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Transaction password set successfully'),
          backgroundColor: successAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.toString()}'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryAccent, secondaryAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryAccent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.password_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Set Transaction Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// Password field label
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      size: 14,
                      color: primaryAccent.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Transaction Password',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            /// Password field
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: _obscure,
                onChanged: _validate,
                enabled: !_isSubmitting,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your transaction password',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  suffixIcon: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() => _obscure = !_obscure),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Validation rules header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: successAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      size: 14,
                      color: successAccent.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Password Requirements',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            /// Validation rules
            _rule('Minimum 8 characters', hasLength),
            _rule('At least one uppercase letter (A-Z)', hasUpper),
            _rule('At least one lowercase letter (a-z)', hasLower),
            _rule('At least one digit (0-9)', hasDigit),
            _rule('At least one special character (!@#\$...)', hasSpecial),

            const SizedBox(height: 24),

            /// Set password button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (isValid && !_isSubmitting) ? _submit : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: (isValid && !_isSubmitting)
                        ? const LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey.withOpacity(0.3),
                              Colors.grey.withOpacity(0.2),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (isValid && !_isSubmitting)
                        ? [
                            BoxShadow(
                              color: primaryAccent.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting) ...[
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Updating...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.check_circle_rounded,
                          color: isValid
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Set Password',
                          style: TextStyle(
                            color: isValid
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
