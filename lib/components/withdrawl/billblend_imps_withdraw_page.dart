import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/withdrawl/billblend_imps_withdraw_service.dart';

class BillblendImpsWithdrawPage extends StatefulWidget {
  final String withdrawalMethod;
  final String withdrawalKey;
  final String methodCode;
  final double minWithdrawal;
  final double maxWithdrawal;
  final String groupId;

  const BillblendImpsWithdrawPage({
    super.key,
    required this.withdrawalMethod,
    required this.withdrawalKey,
    required this.methodCode,
    required this.minWithdrawal,
    required this.maxWithdrawal,
    required this.groupId,
  });

  @override
  State<BillblendImpsWithdrawPage> createState() => _BillblendImpsWithdrawPageState();
}

class _BillblendImpsWithdrawPageState extends State<BillblendImpsWithdrawPage>
    with SingleTickerProviderStateMixin {
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankCodeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _txnPassCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;

  String? _accountNameError;
  String? _accountNumberError;
  String? _amountError;
  String? _bankNameError;
  String? _bankCodeError;
  String? _emailError;
  String? _phoneError;
  String? _txnPassError;

  String _currency = "INR";
  String _userName = "";

  final BillblendImpsWithdrawService _service = BillblendImpsWithdrawService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color successAccent = Color(0xFF10B981);
  static const Color cardBg = Color(0xFF1E293B);

  String _formatRange(double v) => NumberFormat("#,##0").format(v);

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currency = (prefs.getString('currency') ?? 'INR').trim();
      if (_currency.isEmpty) _currency = "INR";
      _userName = (prefs.getString('user_name') ?? '').trim();
    });
  }

  double? _parseAmount() {
    final txt = _amountCtrl.text.trim().replaceAll(",", "");
    return double.tryParse(txt);
  }

  bool _isEmail(String v) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
  }

  void _validateAll() {
    final accountName = _accountNameCtrl.text.trim();
    final accountNumber = _accountNumberCtrl.text.trim();
    final amountRaw = _amountCtrl.text.trim();
    final bankName = _bankNameCtrl.text.trim();
    final bankCode = _bankCodeCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final txnPass = _txnPassCtrl.text.trim();

    setState(() {
      _accountNameError = null;
      _accountNumberError = null;
      _amountError = null;
      _bankNameError = null;
      _bankCodeError = null;
      _emailError = null;
      _phoneError = null;
      _txnPassError = null;

      if (accountName.isEmpty) _accountNameError = "Account name is required";

      if (accountNumber.isEmpty) {
        _accountNumberError = "Account number is required";
      } else if (!RegExp(r'^[0-9]{6,25}$').hasMatch(accountNumber)) {
        _accountNumberError = "Enter valid account number";
      }

      if (amountRaw.isEmpty) {
        _amountError = "Amount is required";
      } else {
        final amount = double.tryParse(amountRaw.replaceAll(",", ""));
        if (amount == null) {
          _amountError = "Enter a valid amount";
        } else if (amount < widget.minWithdrawal) {
          _amountError =
              "Minimum withdrawal is $_currency ${widget.minWithdrawal.toStringAsFixed(0)}";
        } else if (amount > widget.maxWithdrawal) {
          _amountError =
              "Maximum withdrawal is $_currency ${widget.maxWithdrawal.toStringAsFixed(0)}";
        }
      }

      if (bankName.isEmpty) _bankNameError = "Bank name is required";

      if (bankCode.isEmpty) {
        _bankCodeError = "Bank code is required";
      } else if (bankCode.length < 4) {
        _bankCodeError = "Enter valid bank code";
      }

      if (email.isEmpty) {
        _emailError = "Email is required";
      } else if (!_isEmail(email)) {
        _emailError = "Enter valid email";
      }

      if (phone.isEmpty) {
        _phoneError = "Phone number is required";
      } else if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        _phoneError = "Enter valid 10-digit phone number";
      }

      if (txnPass.isEmpty) {
        _txnPassError = "Transaction password is required";
      } else if (txnPass.length < 4) {
        _txnPassError = "Password looks too short";
      }
    });
  }

  bool get _isValid =>
      _accountNameError == null &&
      _accountNumberError == null &&
      _amountError == null &&
      _bankNameError == null &&
      _bankCodeError == null &&
      _emailError == null &&
      _phoneError == null &&
      _txnPassError == null &&
      _accountNameCtrl.text.trim().isNotEmpty &&
      _accountNumberCtrl.text.trim().isNotEmpty &&
      _amountCtrl.text.trim().isNotEmpty &&
      _bankNameCtrl.text.trim().isNotEmpty &&
      _bankCodeCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _txnPassCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    _validateAll();
    if (!_isValid || _submitting) return;

    setState(() => _submitting = true);

    try {
      final amount = _parseAmount() ?? double.parse(_amountCtrl.text.trim());

      final resp = await _service.createImpsWithdraw(
        userName: _userName,
        currency: _currency,
        groupId: widget.groupId,
        accountName: _accountNameCtrl.text.trim(),
        accountNumber: _accountNumberCtrl.text.trim(),
        amount: amount,
        bankName: _bankNameCtrl.text.trim(),
        bankCode: _bankCodeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
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
                  "IMPS Withdrawal request submitted",
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

      // optional: show message
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
              Expanded(
                child: Text(
                  e.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
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
    _amountCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankCodeCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                          title: "IMPS Withdraw",
                          subtitle: "Withdraw securely using bank details (Billblend)",
                          icon: Icons.account_balance_rounded,
                        ),
                        const SizedBox(height: 20),
                        _LimitsCard(minValue: minText, maxValue: maxText),
                        const SizedBox(height: 24),

                        _SectionHeader(icon: Icons.person_outline_rounded, title: "Account Details"),
                        const SizedBox(height: 16),

                        _InputField(
                          label: "Account Name",
                          hint: "Enter account holder name",
                          controller: _accountNameCtrl,
                          keyboardType: TextInputType.name,
                          errorText: _accountNameError,
                          icon: Icons.person_rounded,
                          enabled: !_submitting,
                          onChanged: (_) => _validateAll(),
                        ),
                        const SizedBox(height: 18),

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

                        _InputField(
                          label: "Bank Name",
                          hint: "Enter bank name",
                          controller: _bankNameCtrl,
                          keyboardType: TextInputType.text,
                          errorText: _bankNameError,
                          icon: Icons.account_balance_rounded,
                          enabled: !_submitting,
                          onChanged: (_) => _validateAll(),
                        ),
                        const SizedBox(height: 18),

                        _InputField(
                          label: "Bank Code",
                          hint: "Enter bank code",
                          controller: _bankCodeCtrl,
                          keyboardType: TextInputType.text,
                          errorText: _bankCodeError,
                          icon: Icons.confirmation_number_rounded,
                          enabled: !_submitting,
                          onChanged: (_) => _validateAll(),
                        ),

                        const SizedBox(height: 18),

                        _SectionHeader(icon: Icons.contact_mail_rounded, title: "Contact Details"),
                        const SizedBox(height: 16),

                        _InputField(
                          label: "Email Address",
                          hint: "Enter email address",
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          icon: Icons.email_rounded,
                          enabled: !_submitting,
                          onChanged: (_) => _validateAll(),
                        ),
                        const SizedBox(height: 18),

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

                        const SizedBox(height: 28),

                        _SubmitButton(
                          text: _submitting ? "Submitting..." : "Withdraw Now",
                          onTap: (_submitting) ? () {} : _submit,
                          isLoading: _submitting,
                          enabled: _isValid && !_submitting,
                        ),

                        const SizedBox(height: 18),
                        const _SecurityBadge(text: "Your transaction is secure and encrypted"),
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
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryAccent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Processing...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

/* ---------------- Same UI widgets style as your CashWithdrawPage ---------------- */

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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryAccent, secondaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, color: warnAccent.withOpacity(0.9), size: 20),
              const SizedBox(width: 8),
              Text(
                "Withdrawal Limits",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
              const SizedBox(width: 16),
              Container(width: 1, height: 60, color: Colors.white.withOpacity(0.15)),
              const SizedBox(width: 16),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w700)),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w700,
            fontSize: 18,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: errorText != null ? Colors.red.shade400.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 16),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              prefixText: prefixText,
              prefixStyle: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700, fontSize: 16),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(errorText!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 12))),
              ],
            ),
          ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: errorText != null ? Colors.red.shade400.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.password_rounded, color: Color(0xFF6366F1), size: 16),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            onChanged: onChanged,
            style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              suffixIcon: InkWell(
                onTap: enabled ? onToggle : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white.withOpacity(0.7), size: 20),
                ),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(errorText!, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 12))),
              ],
            ),
          ],
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

  const _SubmitButton({required this.text, required this.onTap, required this.isLoading, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                : LinearGradient(colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              else
                const Icon(Icons.outbox_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
