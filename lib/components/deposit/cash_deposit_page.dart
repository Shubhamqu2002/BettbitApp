import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'image_picker_field.dart';
import '../../services/deposit/cash_deposit_service.dart';

class CashDepositPage extends StatefulWidget {
  final double minDeposit;
  final double maxDeposit;

  const CashDepositPage({
    super.key,
    required this.minDeposit,
    required this.maxDeposit,
  });

  @override
  State<CashDepositPage> createState() => _CashDepositPageState();
}

class _CashDepositPageState extends State<CashDepositPage>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController();
  final _txnCtrl = TextEditingController();
  final CashDepositService _cashService = CashDepositService();
  
  bool _submitting = false;
  String _currency = "INR";
  String? _amountError;
  String? _txnError;
  String? _imageError;
  File? _proof;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Elegant color palette (matching deposit page)
  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color successAccent = Color(0xFF10B981);
  static const Color cardBg = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadCurrency();
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

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currency = (prefs.getString('currency') ?? 'INR').trim().isEmpty
          ? "INR"
          : (prefs.getString('currency') ?? 'INR').trim();
    });
  }

  double? _parseAmount() {
    final txt = _amountCtrl.text.trim().replaceAll(",", "");
    return double.tryParse(txt);
  }

  bool _validate() {
    final a = _parseAmount();

    setState(() {
      _amountError = null;
      _txnError = null;
      _imageError = null;

      if (a == null) {
        _amountError = "Enter a valid amount";
      } else if (a < widget.minDeposit) {
        _amountError =
            "Minimum deposit is $_currency ${widget.minDeposit.toStringAsFixed(0)}";
      } else if (a > widget.maxDeposit) {
        _amountError =
            "Maximum deposit is $_currency ${widget.maxDeposit.toStringAsFixed(0)}";
      }

      final txn = _txnCtrl.text.trim();
      if (txn.isEmpty) _txnError = "Transaction ID is required";

      if (_proof == null) _imageError = "Upload transaction proof image";
    });

    return _amountError == null && _txnError == null && _imageError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final gamerId = (prefs.getString('gamer_id') ?? '').trim();
      final currency = (prefs.getString('currency') ?? 'INR').trim().isEmpty
          ? "INR"
          : (prefs.getString('currency') ?? 'INR').trim();
      final platformCode = (prefs.getString('platform_code') ?? '').trim();

      final amount = _parseAmount() ?? 0;
      final txnId = _txnCtrl.text.trim();
      final imageFile = _proof!;

      if (gamerId.isEmpty) {
        _showSnackBar(
          "Missing gamer_id in SharedPreferences",
          isError: true,
        );
        return;
      }

      if (platformCode.isEmpty) {
        _showSnackBar(
          "Missing platform_code in SharedPreferences",
          isError: true,
        );
        return;
      }

      final resp = await _cashService.submitCashDeposit(
        walletId: gamerId,
        amount: amount,
        currency: currency,
        transactionId: txnId,
        platformCode: platformCode,
        imageFile: imageFile,
      );

      final ok = resp["ok"] == true;
      final msg = (resp["message"] ?? "").toString();

      if (!mounted) return;

      if (ok) {
        _showSnackBar(
          "Cash deposit submitted successfully",
          isError: false,
        );
        Navigator.pop(context);
      } else {
        _showSnackBar(
          msg.isEmpty ? "Deposit failed" : msg,
          isError: true,
        );
      }
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
    _txnCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            title: const Text(
              "Cash Deposit",
              style: TextStyle(
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
                          title: "Cash Deposit",
                          subtitle: "Submit your transaction details securely",
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        const SizedBox(height: 20),

                        _DepositLimitsCard(
                          minDeposit: widget.minDeposit,
                          maxDeposit: widget.maxDeposit,
                          currency: _currency,
                        ),
                        const SizedBox(height: 24),

                        _SectionHeader(
                          icon: Icons.receipt_long_rounded,
                          title: "Transaction Details",
                        ),
                        const SizedBox(height: 16),

                        _InputField(
                          label: "Amount",
                          hint: "Enter deposit amount",
                          prefixText: "$_currency ",
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          errorText: _amountError,
                          icon: Icons.payments_outlined,
                        ),
                        const SizedBox(height: 16),

                        _InputField(
                          label: "Transaction ID",
                          hint: "Enter transaction reference",
                          controller: _txnCtrl,
                          keyboardType: TextInputType.text,
                          errorText: _txnError,
                          icon: Icons.tag_rounded,
                        ),
                        const SizedBox(height: 24),

                        _SectionHeader(
                          icon: Icons.upload_file_rounded,
                          title: "Payment Proof",
                        ),
                        const SizedBox(height: 16),

                        _ImageUploadCard(
                          proof: _proof,
                          imageError: _imageError,
                          onChanged: (f) {
                            setState(() {
                              _proof = f;
                              _imageError = null;
                            });
                          },
                        ),

                        const SizedBox(height: 28),

                        _SubmitButton(
                          text: _submitting ? "Submitting..." : "Submit Deposit",
                          onTap: _submitting ? () {} : _submit,
                          isLoading: _submitting,
                        ),

                        const SizedBox(height: 20),

                        _SecurityBadge(),
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
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
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
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
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

class _DepositLimitsCard extends StatelessWidget {
  final double minDeposit;
  final double maxDeposit;
  final String currency;

  const _DepositLimitsCard({
    required this.minDeposit,
    required this.maxDeposit,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFFF59E0B).withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Deposit Limits",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: -0.2,
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
                  value: "$currency ${minDeposit.toStringAsFixed(0)}",
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withOpacity(0.15),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LimitBox(
                  label: "Maximum",
                  value: "$currency ${maxDeposit.toStringAsFixed(0)}",
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFF59E0B),
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

  const _LimitBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
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
            letterSpacing: -0.3,
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

  const _InputField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.icon,
    this.prefixText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: errorText != null
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6366F1),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              prefixText: prefixText,
              prefixStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 2,
                ),
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade400,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  final File? proof;
  final String? imageError;
  final Function(File?) onChanged;

  const _ImageUploadCard({
    required this.proof,
    required this.imageError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: imageError != null
              ? Colors.red.shade400.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImagePickerField(
            title: "Upload Proof",
            subtitle: "Camera or Gallery",
            onChanged: onChanged,
          ),
          if (imageError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.shade400.withOpacity(0.3),
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
                      imageError!,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                const Icon(
                  Icons.check_circle_rounded,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Your transaction is secure and encrypted",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}