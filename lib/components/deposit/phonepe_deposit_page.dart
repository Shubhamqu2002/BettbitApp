import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/deposit/gpt_deposit_service.dart';
import '../../components/deposit/gpt_payment_webview_page.dart';

class PhonePeDepositPage extends StatefulWidget {
  final String depositKey;     // PHONE_PE (method_code)
  final String depositMethod;  // PHONE_PE (button title)
  final double minDeposit;
  final double maxDeposit;
  final String groupId;

  const PhonePeDepositPage({
    super.key,
    required this.depositKey,
    required this.depositMethod,
    required this.minDeposit,
    required this.maxDeposit,
    required this.groupId,
  });

  @override
  State<PhonePeDepositPage> createState() => _PhonePeDepositPageState();
}

class _PhonePeDepositPageState extends State<PhonePeDepositPage>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _currency = "INR";
  String _country = "IN";

  String? _amountError;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;

  final GptDepositService _service = GptDepositService();
  bool _submitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color successAccent = Color(0xFF10B981);
  static const Color cardBg = Color(0xFF1E293B);

  static const String _callbackUrl =
      "https://payment.bettbit.com/api/invoice/payin/callback";
  static const String _webhookUrl =
      "https://payment.bettbit.com/api/invoice/payin/callback";

  static const String _fallbackMethodCode = "UPI_URL";

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
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final c = (prefs.getString('currency') ?? 'INR').trim();
    final cc = (prefs.getString('registered_country') ?? 'IN').trim();

    setState(() {
      _currency = c.isEmpty ? "INR" : c;
      _country = cc.isEmpty ? "IN" : cc;
    });
  }

  double? _parseAmount() {
    final txt = _amountCtrl.text.trim().replaceAll(",", "");
    return double.tryParse(txt);
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(s);
  }

  bool _isValidPhone(String v) {
    final s = v.trim();
    final re = RegExp(r'^(\+?\d{1,3})?\d{10}$');
    return re.hasMatch(s);
  }

  bool _validateAll() {
    final a = _parseAmount();
    final fn = _firstNameCtrl.text.trim();
    final ln = _lastNameCtrl.text.trim();
    final em = _emailCtrl.text.trim();
    final ph = _phoneCtrl.text.trim();

    setState(() {
      _amountError = null;
      _firstNameError = null;
      _lastNameError = null;
      _emailError = null;
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

      if (fn.isEmpty) _firstNameError = "First name is required";
      if (ln.isEmpty) _lastNameError = "Last name is required";

      if (em.isEmpty) {
        _emailError = "Email is required";
      } else if (!_isValidEmail(em)) {
        _emailError = "Enter a valid email";
      }

      if (ph.isEmpty) {
        _phoneError = "Phone is required";
      } else if (!_isValidPhone(ph)) {
        _phoneError = "Enter a valid phone number";
      }
    });

    return _amountError == null &&
        _firstNameError == null &&
        _lastNameError == null &&
        _emailError == null &&
        _phoneError == null;
  }

  /// Returns true if launched, false if app not available / can't launch
  Future<bool> _tryLaunchDeepLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar("Invalid payment URL", isError: true);
      return false;
    }

    final can = await canLaunchUrl(uri);
    if (!can) return false;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  }

  void _openWebPaymentPage({
    required String paymentUrl,
    required String reference,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GptPaymentWebViewPage(
          paymentUrl: paymentUrl,
          reference: reference,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_validateAll()) return;

    setState(() => _submitting = true);

    try {
      final amount = _parseAmount() ?? 0;
      final ip = await _service.fetchPublicIp();

      // ✅ 1) First call with PHONE_PE (or whatever key you pass)
      final resp1 = await _service.initiateInvoice(
        amount: amount,
        currency: _currency,
        methodCode: widget.depositKey, // ✅ method_code should come from key
        callbackUrl: _callbackUrl,
        webhookUrl: _webhookUrl,
        ipAddress: ip,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        country: _country,
      );

      if (!mounted) return;

      final ok1 = resp1["ok"] == true;
      final msg1 = (resp1["message"] ?? "").toString();
      final paymentUrl1 = (resp1["payment_url"] ?? "").toString();
      final reference1 = (resp1["reference"] ?? "").toString();

      if (!ok1) {
        _showSnackBar(msg1.isEmpty ? "Payment request failed" : msg1, isError: true);
        return;
      }

      if (paymentUrl1.trim().isEmpty) {
        _showSnackBar("payment_url not found in response", isError: true);
        return;
      }

      // ✅ If deep link exists, try to launch
      // If app not available -> fallback flow
      final launched = await _tryLaunchDeepLink(paymentUrl1);

      if (launched) {
        _showSnackBar("Opening ${widget.depositMethod}...", isError: false);
        return;
      }

      // ✅ FALLBACK: If app not available, call same API with method_code = UPI_URL
      _showSnackBar(
        "${widget.depositMethod} app not available. Redirecting to UPI payment page...",
        isError: false,
      );

      final resp2 = await _service.initiateInvoice(
        amount: amount,
        currency: _currency,
        methodCode: _fallbackMethodCode, // ✅ UPI_URL fallback
        callbackUrl: _callbackUrl,
        webhookUrl: _webhookUrl,
        ipAddress: ip,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        country: _country,
      );

      if (!mounted) return;

      final ok2 = resp2["ok"] == true;
      final msg2 = (resp2["message"] ?? "").toString();
      final paymentUrl2 = (resp2["payment_url"] ?? "").toString();
      final reference2 = (resp2["reference"] ?? "").toString();

      if (!ok2) {
        _showSnackBar(msg2.isEmpty ? "Payment request failed" : msg2, isError: true);
        return;
      }

      if (paymentUrl2.trim().isEmpty) {
        _showSnackBar("payment_url not found in response", isError: true);
        return;
      }

      // ✅ Open in separate WebView page
      _openWebPaymentPage(
        paymentUrl: paymentUrl2,
        reference: reference2.isEmpty ? reference1 : reference2,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
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
                        const SizedBox(height: 18),
                        _CustomerFormCard(
                          firstNameCtrl: _firstNameCtrl,
                          lastNameCtrl: _lastNameCtrl,
                          emailCtrl: _emailCtrl,
                          phoneCtrl: _phoneCtrl,
                          firstNameError: _firstNameError,
                          lastNameError: _lastNameError,
                          emailError: _emailError,
                          phoneError: _phoneError,
                        ),
                        const SizedBox(height: 28),
                        _SubmitButton(
                          text: _submitting ? "Processing..." : "Pay via ${widget.depositMethod}",
                          onTap: _submitting ? () {} : _submit,
                          isLoading: _submitting,
                        ),
                        const SizedBox(height: 20),
                        _SecurityBadge(),
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
      ),
    );
  }
}

/* ---------- UI Components (unchanged) ---------- */

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
  final double minDeposit;
  final double maxDeposit;
  final String currency;

  const _HeaderCard({
    required this.depositMethod,
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
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 40),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: const Color(0xFFF59E0B).withOpacity(0.9), size: 16),
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
    return _CardShell(
      borderColor: amountError != null
          ? Colors.red.shade400.withOpacity(0.5)
          : Colors.white.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.account_balance_wallet_outlined, title: "Deposit Amount"),
          const SizedBox(height: 16),
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
                      keyboardType: TextInputType.number,
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
            _ErrorPill(text: amountError!),
          ],
        ],
      ),
    );
  }
}

class _CustomerFormCard extends StatelessWidget {
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;

  final String? firstNameError;
  final String? lastNameError;
  final String? emailError;
  final String? phoneError;

  const _CustomerFormCard({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    this.firstNameError,
    this.lastNameError,
    this.emailError,
    this.phoneError,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      borderColor: Colors.white.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.person_outline_rounded, title: "Customer Details"),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TextFieldBox(
                  controller: firstNameCtrl,
                  label: "First Name",
                  keyboardType: TextInputType.name,
                  errorText: firstNameError,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextFieldBox(
                  controller: lastNameCtrl,
                  label: "Last Name",
                  keyboardType: TextInputType.name,
                  errorText: lastNameError,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TextFieldBox(
            controller: emailCtrl,
            label: "Email",
            keyboardType: TextInputType.emailAddress,
            errorText: emailError,
          ),
          const SizedBox(height: 12),
          _TextFieldBox(
            controller: phoneCtrl,
            label: "Phone",
            keyboardType: TextInputType.phone,
            hintText: "+919876543210",
            errorText: phoneError,
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

  const _SubmitButton({
    required this.text,
    required this.onTap,
    required this.isLoading,
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
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
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
                const Icon(Icons.payment_rounded, color: Colors.white, size: 22),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1),
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
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
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

class _CardShell extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _CardShell({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final String? errorText;

  const _TextFieldBox({
    required this.controller,
    required this.label,
    required this.keyboardType,
    this.hintText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null
        ? Colors.red.shade400.withOpacity(0.5)
        : Colors.white.withOpacity(0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              border: InputBorder.none,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 10),
          _ErrorPill(text: errorText!),
        ]
      ],
    );
  }
}

class _ErrorPill extends StatelessWidget {
  final String text;

  const _ErrorPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade400.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
