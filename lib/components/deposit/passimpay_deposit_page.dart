import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/deposit/passimpay_deposit_service.dart';
import 'passimpay_redirect_page.dart';

class PassimpayDepositPage extends StatefulWidget {
  final String depositKey;
  final String depositMethod;
  final String methodCode;
  final double minDeposit;
  final double maxDeposit;

  const PassimpayDepositPage({
    super.key,
    required this.depositKey,
    required this.depositMethod,
    required this.methodCode,
    required this.minDeposit,
    required this.maxDeposit,
  });

  @override
  State<PassimpayDepositPage> createState() => _PassimpayDepositPageState();
}

class _PassimpayDepositPageState extends State<PassimpayDepositPage>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final PassimpayDepositService _service = PassimpayDepositService();

  String _currency = "INR";
  String _country = "IN";
  String _callingCode = "+91";

  String? _amountError;
  String? _phoneError;

  bool _submitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color successAccent = Color(0xFF10B981);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color passimpayAccent = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = (prefs.getString('currency') ?? 'INR').trim();
    final country = (prefs.getString('registered_country') ?? 'IN').trim();

    String callingCode = "+91";
    if (country.toUpperCase() == "PK") {
      callingCode = "+92";
    } else if (country.toUpperCase() == "BD") {
      callingCode = "+880";
    }

    if (!mounted) return;
    setState(() {
      _currency = currency.isEmpty ? "INR" : currency;
      _country = country.isEmpty ? "IN" : country;
      _callingCode = callingCode;
    });
  }

  double? _parseAmount() {
    final txt = _amountCtrl.text.trim().replaceAll(",", "");
    return double.tryParse(txt);
  }

  bool _validate() {
    final a = _parseAmount();
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    setState(() {
      _amountError = null;
      _phoneError = null;

      if (a == null) {
        _amountError = "Enter a valid amount";
      } else if (a < widget.minDeposit) {
        _amountError =
            "Minimum deposit is $_currency ${widget.minDeposit.toStringAsFixed(0)}";
      } else if (a > widget.maxDeposit) {
        _amountError =
            "Maximum deposit is $_currency ${widget.maxDeposit.toStringAsFixed(0)}";
      }

      if (phone.isEmpty) {
        _phoneError = "Enter phone number";
      } else if (phone.length < 8 || phone.length > 15) {
        _phoneError = "Enter a valid phone number";
      }
    });

    return _amountError == null && _phoneError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final amount = _parseAmount() ?? 0;
      final phone = _phoneCtrl.text.trim();

      final resp = await _service.initiateDeposit(
        amount: amount,
        phoneNumber: phone,
      );

      if (!mounted) return;

      final ok = resp["ok"] == true;
      final msg = (resp["message"] ?? "").toString();
      final url = (resp["url"] ?? "").toString();

      if (!ok || url.isEmpty) {
        _showSnackBar(
          msg.isEmpty ? "PASSIMPAY request failed" : msg,
          isError: true,
        );
        return;
      }

      _showSnackBar("Redirecting to payment...", isError: false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PassimpayRedirectPage(
            title: "${widget.depositMethod} Checkout",
            url: url,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade600 : successAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = "${widget.depositMethod} Deposit";

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
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
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderCard(
                          depositMethod: widget.depositMethod,
                          methodCode: widget.methodCode,
                          minDeposit: widget.minDeposit,
                          maxDeposit: widget.maxDeposit,
                          currency: _currency,
                        ),
                        const SizedBox(height: 24),

                        _AmountInputCard(
                          currency: _currency,
                          controller: _amountCtrl,
                          amountError: _amountError,
                        ),
                        const SizedBox(height: 16),

                        _PhoneInputCard(
                          callingCode: _callingCode,
                          controller: _phoneCtrl,
                          phoneError: _phoneError,
                        ),
                        const SizedBox(height: 20),

                        _ServiceFeeCard(),
                        const SizedBox(height: 28),

                        _SubmitButton(
                          text: _submitting ? "Processing..." : "Proceed to Pay",
                          onTap: _submitting ? () {} : _submit,
                          isLoading: _submitting,
                          accentColor: passimpayAccent,
                        ),
                        const SizedBox(height: 20),

                        const _SecurityBadge(),
                        const SizedBox(height: 20),
                      ],
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryAccent),
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
      ),
    );
  }
}

/* ---------- UI Components ---------- */

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
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String depositMethod;
  final String methodCode;
  final double minDeposit;
  final double maxDeposit;
  final String currency;

  const _HeaderCard({
    required this.depositMethod,
    required this.methodCode,
    required this.minDeposit,
    required this.maxDeposit,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFB923C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Pay using $depositMethod",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Method Code: $methodCode",
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFFF59E0B).withOpacity(0.9),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  "$currency ${minDeposit.toStringAsFixed(0)} - $currency ${maxDeposit.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

class _AmountInputCard extends StatelessWidget {
  final String currency;
  final TextEditingController controller;
  final String? amountError;

  const _AmountInputCard({
    required this.currency,
    required this.controller,
    this.amountError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: amountError != null
              ? Colors.red.shade400.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFFB923C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Deposit Amount",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: amountError != null
                    ? Colors.red.shade400.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$currency ",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    height: 1.2,
                  ),
                ),
                Flexible(
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 32,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                          height: 1.2,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 50),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (amountError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.shade400.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      amountError!,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneInputCard extends StatelessWidget {
  final String callingCode;
  final TextEditingController controller;
  final String? phoneError;

  const _PhoneInputCard({
    required this.callingCode,
    required this.controller,
    this.phoneError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: phoneError != null
              ? Colors.red.shade400.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Phone Number",
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: phoneError != null
                    ? Colors.red.shade400.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  callingCode,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withOpacity(0.12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter phone number",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (phoneError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.shade400.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      phoneError!,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceFeeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.15),
            const Color(0xFFF59E0B).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info_rounded,
              color: const Color(0xFFF59E0B).withOpacity(0.9),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Service fee of 10% will be charged on this transaction",
              style: TextStyle(
                color: const Color(0xFFF59E0B).withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final Color accentColor;

  const _SubmitButton({
    required this.text,
    required this.onTap,
    required this.isLoading,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(
                  Icons.payment_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
              if (!isLoading) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF10B981),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Secure & Encrypted",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}