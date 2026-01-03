import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/gradient_background.dart';
import '../components/deposit/cash_deposit_page.dart';
import '../components/deposit/upi_deposit_page.dart';
import '../components/deposit/phonepe_deposit_page.dart'; // ✅ NEW

import '../services/deposit/deposit_service.dart';
import '../services/deposit/deposit_models.dart';

class DepositPage extends StatefulWidget {
  const DepositPage({super.key});

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final DepositService _service = DepositService();

  bool _loading = true;
  String? _error;

  String _country = "IN";
  String _currency = "INR";

  List<DepositMethod> _billblendMethods = [];
  List<DepositMethod> _gptMethods = []; // ✅ NEW

  // Elegant color palette
  static const Color primaryAccent = Color(0xFF6366F1); // Indigo
  static const Color successAccent = Color(0xFF10B981); // Emerald
  static const Color cardBg = Color(0xFF1E293B); // Slate dark

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final savedCountry = (prefs.getString('registered_country') ?? 'IN').trim();
      final savedCurrency = (prefs.getString('currency') ?? 'INR').trim();

      _country = savedCountry.isEmpty ? "IN" : savedCountry;
      _currency = savedCurrency.isEmpty ? "INR" : savedCurrency;

      final resp = await _service.fetchDepositMethods(_country);

      if (!mounted) return;
      setState(() {
        _billblendMethods = resp.billblend;
        _gptMethods = resp.gpt; // ✅ NEW
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openCash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GradientBackground(
          child: CashDepositPage(
            minDeposit: 100.00,
            maxDeposit: 20000.00,
          ),
        ),
      ),
    );
  }

  void _openBillblendMethod(DepositMethod m) {
    if (m.depositKey.toUpperCase() == "UPI") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GradientBackground(
            child: UpiDepositPage(
              depositKey: m.depositKey,
              depositMethod: m.depositMethod,
              minDeposit: m.minDeposit,
              maxDeposit: m.maxDeposit,
              groupId: m.groupId,
            ),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Deposit method '${m.depositMethod}' is not supported yet."),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openGptMethod(DepositMethod m) {
    if (m.depositKey.toUpperCase() == "PHONE_PE" ||
    m.depositKey.toUpperCase() == "UPI" ||
    m.depositKey.toUpperCase() == "PAYTM") {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GradientBackground(
        child: PhonePeDepositPage(
          depositKey: m.depositKey,
          depositMethod: m.depositMethod, // button label (dynamic)
          minDeposit: m.minDeposit,
          maxDeposit: m.maxDeposit,
          groupId: m.groupId,
        ),
      ),
    ),
  );
  return;
}



    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("GPT method '${m.depositMethod}' is not supported yet."),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text(
            "Deposit",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: _IconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: "Refresh",
                onPressed: _initLoad,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
            )
          ],
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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        _TopHeader(currency: _currency, country: _country),
                        const SizedBox(height: 32),

                        Text(
                          "Payment Methods",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Choose your preferred method for instant deposits",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_loading) ...[
                          const _MethodSkeleton(),
                          const SizedBox(height: 16),
                          const _MethodSkeleton(),
                          const SizedBox(height: 16),
                          const _MethodSkeleton(),
                        ] else if (_error != null) ...[
                          _ErrorCard(message: _error!, onRetry: _initLoad),
                        ] else ...[
                          _DepositMethodTile(
                            title: "Cash Deposit",
                            subtitle: "$_currency 100 - $_currency 20,000",
                            icon: Icons.account_balance_wallet_rounded,
                            badgeText: "Instant",
                            badgeColor: successAccent,
                            onTap: _openCash,
                          ),
                          const SizedBox(height: 16),

                          // ---------------- BILLBLEND ----------------
                          ..._billblendMethods.map((m) {
                            final range =
                                "$_currency ${m.minDeposit.toStringAsFixed(0)} - $_currency ${m.maxDeposit.toStringAsFixed(0)}";
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _DepositMethodTile(
                                title: m.depositMethod,
                                subtitle: range,
                                icon: Icons.qr_code_2_rounded,
                                badgeText: "Online",
                                badgeColor: primaryAccent,
                                onTap: () => _openBillblendMethod(m),
                              ),
                            );
                          }),

                          // ---------------- GPT (NEW) ----------------
                          if (_gptMethods.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              "More Options",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            ..._gptMethods.map((m) {
                              final range =
                                  "$_currency ${m.minDeposit.toStringAsFixed(0)} - $_currency ${m.maxDeposit.toStringAsFixed(0)}";
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _DepositMethodTile(
                                  title: m.depositMethod, // ✅ use depositMethod from response
                                  subtitle: range,
                                  icon: Icons.account_balance_rounded,
                                  badgeText: "GPT",
                                  badgeColor: const Color(0xFF8B5CF6),
                                  onTap: () => _openGptMethod(m),
                                ),
                              );
                            }),
                          ],

                          if (_billblendMethods.isEmpty && _gptMethods.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: primaryAccent.withOpacity(0.9),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      "No online methods available for $_country currently",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- UI Components (UNCHANGED) ---------- */

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

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

class _TopHeader extends StatelessWidget {
  final String currency;
  final String country;

  const _TopHeader({required this.currency, required this.country});

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
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Secure Deposits",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(text: country, icon: Icons.flag_outlined),
                    const SizedBox(width: 8),
                    _InfoChip(text: currency, icon: Icons.payments_outlined),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositMethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;

  const _DepositMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [badgeColor.withOpacity(0.8), badgeColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      badgeColor.withOpacity(0.15),
                      badgeColor.withOpacity(0.08),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_card_rounded, color: badgeColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Deposit Now",
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, color: badgeColor, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodSkeleton extends StatelessWidget {
  const _MethodSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Failed to Load",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRetry,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Retry",
                      style: TextStyle(
                        color: Colors.redAccent.withOpacity(0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
