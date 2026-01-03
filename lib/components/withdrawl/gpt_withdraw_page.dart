import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/withdrawl/gpt_withdraw_service.dart';

class GptWithdrawPage extends StatefulWidget {
  final String withdrawalMethod;
  final String withdrawalKey;
  final String methodCode;
  final double minWithdrawal;
  final double maxWithdrawal;

  const GptWithdrawPage({
    super.key,
    required this.withdrawalMethod,
    required this.withdrawalKey,
    required this.methodCode,
    required this.minWithdrawal,
    required this.maxWithdrawal,
  });

  @override
  State<GptWithdrawPage> createState() => _GptWithdrawPageState();
}

class _GptWithdrawPageState extends State<GptWithdrawPage> with SingleTickerProviderStateMixin {
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _txnPassCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;

  String? _accountNameError;
  String? _accountNumberError;
  String? _ifscError;
  String? _phoneError;
  String? _upiError;
  String? _amountError;
  String? _txnPassError;

  String _currency = "INR";
  String _country = "IN";
  String _userName = "";

  final GptWithdrawService _service = GptWithdrawService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);
  static const Color successAccent = Color(0xFF10B981);


  bool get _isUpi => widget.methodCode.trim().toUpperCase() == "UPI";
  String _formatRange(double v) => NumberFormat("#,##0").format(v);

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currency = (prefs.getString('currency') ?? 'INR').trim();
      if (_currency.isEmpty) _currency = "INR";
      _country = (prefs.getString('registered_country') ?? 'IN').trim();
      if (_country.isEmpty) _country = "IN";
      _userName = (prefs.getString('user_name') ?? '').trim();
    });
  }

  double? _parseAmount() {
    final txt = _amountCtrl.text.trim().replaceAll(",", "");
    return double.tryParse(txt);
  }

  bool _isValidUpi(String v) {
    final t = v.trim();
    return t.isNotEmpty && t.contains("@") && !t.startsWith("@") && !t.endsWith("@");
  }

  void _validateAll() {
    final accountName = _accountNameCtrl.text.trim();
    final accountNumber = _accountNumberCtrl.text.trim();
    final ifsc = _ifscCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final upi = _upiCtrl.text.trim();
    final amountRaw = _amountCtrl.text.trim();
    final txnPass = _txnPassCtrl.text.trim();

    setState(() {
      _accountNameError = null;
      _accountNumberError = null;
      _ifscError = null;
      _phoneError = null;
      _upiError = null;
      _amountError = null;
      _txnPassError = null;

      if (accountName.isEmpty) _accountNameError = "Account name is required";

      if (_isUpi) {
        if (phone.isEmpty) {
          _phoneError = "Phone number is required";
        } else if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
          _phoneError = "Enter valid 10-digit phone number";
        }

        if (upi.isEmpty) {
          _upiError = "UPI ID is required";
        } else if (!_isValidUpi(upi)) {
          _upiError = "Enter valid UPI ID (must contain @)";
        }
      } else {
        if (accountNumber.isEmpty) {
          _accountNumberError = "Account number is required";
        } else if (!RegExp(r'^[0-9]{6,30}$').hasMatch(accountNumber)) {
          _accountNumberError = "Enter valid account number";
        }

        if (ifsc.isEmpty) {
          _ifscError = "IFSC code is required";
        } else if (ifsc.length < 6) {
          _ifscError = "Enter valid IFSC code";
        }
      }

      if (amountRaw.isEmpty) {
        _amountError = "Amount is required";
      } else {
        final amount = double.tryParse(amountRaw.replaceAll(",", ""));
        if (amount == null) {
          _amountError = "Enter a valid amount";
        } else if (amount < widget.minWithdrawal) {
          _amountError = "Minimum withdrawal is $_currency ${widget.minWithdrawal.toStringAsFixed(0)}";
        } else if (amount > widget.maxWithdrawal) {
          _amountError = "Maximum withdrawal is $_currency ${widget.maxWithdrawal.toStringAsFixed(0)}";
        }
      }

      if (txnPass.isEmpty) {
        _txnPassError = "Transaction password is required";
      } else if (txnPass.length < 4) {
        _txnPassError = "Password looks too short";
      }
    });
  }

  bool get _isValid {
    return _accountNameError == null &&
        _accountNumberError == null &&
        _ifscError == null &&
        _phoneError == null &&
        _upiError == null &&
        _amountError == null &&
        _txnPassError == null &&
        _accountNameCtrl.text.trim().isNotEmpty &&
        _amountCtrl.text.trim().isNotEmpty &&
        _txnPassCtrl.text.trim().isNotEmpty &&
        (_isUpi
            ? (_phoneCtrl.text.trim().isNotEmpty && _upiCtrl.text.trim().isNotEmpty)
            : (_accountNumberCtrl.text.trim().isNotEmpty && _ifscCtrl.text.trim().isNotEmpty));
  }

  Future<void> _submit() async {
    _validateAll();
    if (!_isValid || _submitting) return;

    setState(() => _submitting = true);

    try {
      final amount = _parseAmount() ?? double.parse(_amountCtrl.text.trim());

      final resp = await _service.createGptWithdraw(
        amount: amount,
        currency: _currency,
        methodCode: widget.methodCode,
        country: _country,
        userName: _userName,
        accountName: _accountNameCtrl.text.trim(),
        accountNumber: _isUpi ? null : _accountNumberCtrl.text.trim(),
        ifscCode: _isUpi ? null : _ifscCtrl.text.trim(),
        phone: _isUpi ? _phoneCtrl.text.trim() : null,
        upiId: _isUpi ? _upiCtrl.text.trim() : null,
        transactionPassword: _txnPassCtrl.text.trim(),
      );

      if (!mounted) return;

      final msg = (resp["message"] ?? "Request submitted").toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Withdrawal request submitted",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: successAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF334155),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _phoneCtrl.dispose();
    _upiCtrl.dispose();
    _amountCtrl.dispose();
    _txnPassCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minText = "$_currency ${widget.minWithdrawal.toStringAsFixed(0)}";
    final maxText = "$_currency ${widget.maxWithdrawal.toStringAsFixed(0)}";

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _IconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _submitting ? null : () => Navigator.pop(context),
              ),
            ),
            title: Text(
              widget.withdrawalMethod,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.8,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF1E293B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderCard(
                          title: "GPT Withdraw",
                          subtitle: _isUpi ? "UPI withdrawal via GPT" : "Bank Transfer withdrawal via GPT",
                          icon: Icons.cloud_done_rounded,
                        ),
                        const SizedBox(height: 24),
                        _LimitsCard(minValue: minText, maxValue: maxText),
                        const SizedBox(height: 28),

                        _SectionHeader(icon: Icons.person_outline_rounded, title: "Recipient Details"),
                        const SizedBox(height: 16),

                        _InputField(
                          label: "Account Name",
                          hint: "Enter full name",
                          controller: _accountNameCtrl,
                          keyboardType: TextInputType.name,
                          errorText: _accountNameError,
                          icon: Icons.person_rounded,
                          enabled: !_submitting,
                          onChanged: (_) => _validateAll(),
                        ),
                        const SizedBox(height: 18),

                        if (!_isUpi) ...[
                          _InputField(
                            label: "Account Number",
                            hint: "Enter account number",
                            controller: _accountNumberCtrl,
                            keyboardType: TextInputType.number,
                            errorText: _accountNumberError,
                            icon: Icons.numbers_rounded,
                            enabled: !_submitting,
                            onChanged: (_) => _validateAll(),
                          ),
                          const SizedBox(height: 18),
                          _InputField(
                            label: "IFSC Code",
                            hint: "Enter IFSC code",
                            controller: _ifscCtrl,
                            keyboardType: TextInputType.text,
                            errorText: _ifscError,
                            icon: Icons.confirmation_number_rounded,
                            enabled: !_submitting,
                            onChanged: (_) => _validateAll(),
                          ),
                          const SizedBox(height: 18),
                        ] else ...[
                          _InputField(
                            label: "Phone Number",
                            hint: "Enter 10-digit phone number",
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            errorText: _phoneError,
                            icon: Icons.phone_iphone_rounded,
                            enabled: !_submitting,
                            onChanged: (_) => _validateAll(),
                          ),
                          const SizedBox(height: 18),
                          _InputField(
                            label: "UPI ID",
                            hint: "example@upi",
                            controller: _upiCtrl,
                            keyboardType: TextInputType.emailAddress,
                            errorText: _upiError,
                            icon: Icons.alternate_email_rounded,
                            enabled: !_submitting,
                            onChanged: (_) => _validateAll(),
                          ),
                          const SizedBox(height: 18),
                        ],

                        const SizedBox(height: 12),
                        _SectionHeader(icon: Icons.payments_outlined, title: "Withdrawal Details"),
                        const SizedBox(height: 16),

                        _InputField(
                          label: "Amount",
                          hint:
                              "Enter amount (${_formatRange(widget.minWithdrawal)} - ${_formatRange(widget.maxWithdrawal)})",
                          prefixText: "$_currency ",
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          errorText: _amountError,
                          icon: Icons.currency_rupee_rounded,
                          enabled: !_submitting,
                          onChanged: (_) => _validateAll(),
                        ),
                        const SizedBox(height: 18),

                        _PasswordField(
                          label: "Transaction Password",
                          hint: "Enter transaction password",
                          controller: _txnPassCtrl,
                          errorText: _txnPassError,
                          enabled: !_submitting,
                          obscure: _obscure,
                          onToggle: () {
                            if (_submitting) return;
                            setState(() => _obscure = !_obscure);
                          },
                          onChanged: (_) => _validateAll(),
                        ),

                        const SizedBox(height: 32),
                        _SubmitButton(
                          text: _submitting ? "Processing..." : "Withdraw Now",
                          onTap: (_submitting) ? () {} : _submit,
                          isLoading: _submitting,
                          enabled: _isValid && !_submitting,
                        ),

                        const SizedBox(height: 20),
                        const _SecurityBadge(text: "Your transaction is secure and encrypted"),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_submitting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF334155)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primaryAccent.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryAccent.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                          ),
                        ),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Processing Transaction",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please wait...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _HeaderCard({required this.title, required this.subtitle, required this.icon});

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withOpacity(0.8),
            const Color(0xFF334155).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryAccent.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryAccent, secondaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.98),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _LimitsCard extends StatelessWidget {
  final String minValue;
  final String maxValue;
  const _LimitsCard({required this.minValue, required this.maxValue});

  static const Color successAccent = Color(0xFF10B981);
  static const Color warnAccent = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withOpacity(0.8),
            const Color(0xFF334155).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: warnAccent.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [warnAccent.withOpacity(0.2), warnAccent.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline_rounded, color: warnAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                "Withdrawal Limits",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.98),
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _LimitBox(
                  label: "Minimum",
                  value: minValue,
                  icon: Icons.arrow_downward_rounded,
                  color: successAccent,
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 2,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LimitBox(
                  label: "Maximum",
                  value: maxValue,
                  icon: Icons.arrow_upward_rounded,
                  color: warnAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _LimitBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.25), color.withOpacity(0.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.98),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.98),
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final String? prefixText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? errorText;
  final IconData icon;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.icon,
    required this.enabled,
    this.prefixText,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withOpacity(0.7),
            const Color(0xFF334155).withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: errorText != null
              ? Colors.red.shade400.withOpacity(0.6)
              : Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: errorText != null
            ? [
                BoxShadow(
                  color: Colors.red.shade400.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.25),
                      const Color(0xFF6366F1).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: TextStyle(
              color: Colors.white.withOpacity(0.98),
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              prefixText: prefixText,
              prefixStyle: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.errorText,
    required this.enabled,
    required this.obscure,
    required this.onToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withOpacity(0.7),
            const Color(0xFF334155).withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: errorText != null
              ? Colors.red.shade400.withOpacity(0.6)
              : Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: errorText != null
            ? [
                BoxShadow(
                  color: Colors.red.shade400.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.25),
                      const Color(0xFF6366F1).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                ),
                child: const Icon(Icons.password_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            onChanged: onChanged,
            style: TextStyle(
              color: Colors.white.withOpacity(0.98),
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              suffixIcon: InkWell(
                onTap: enabled ? onToggle : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.white.withOpacity(0.7),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;

  const _SubmitButton({
    required this.text,
    required this.onTap,
    required this.isLoading,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.grey.withOpacity(0.4),
                      Colors.grey.withOpacity(0.3),
                    ],
                  ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 14),
              Text(
                text,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  final String text;
  const _SecurityBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF10B981).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}