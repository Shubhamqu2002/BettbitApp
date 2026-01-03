import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/gradient_background.dart';
import '../components/withdrawl/cash_withdraw_page.dart';
import '../components/withdrawl/billblend_imps_withdraw_page.dart';
import '../components/withdrawl/gpt_withdraw_page.dart';

import '../models/withdrawal_method_item.dart';
import '../services/withdrawl/withdrawal_methods_service.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  // CASH fixed (as you want)
  static const String cashMethod = "CASH";
  static const String cashKey = "CASH";
  static const double cashMin = 200.00;
  static const double cashMax = 20000.00;

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color successAccent = Color(0xFF10B981);

  final WithdrawalMethodsService _methodsService = WithdrawalMethodsService();

  bool _loading = true;
  String _country = "IN";
  String _currency = "INR";
  String? _error;
  List<WithdrawalMethodItem> _items = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final cc = (prefs.getString('registered_country') ?? 'IN').trim();
      final cur = (prefs.getString('currency') ?? 'INR').trim();

      _country = cc.isEmpty ? "IN" : cc;
      _currency = cur.isEmpty ? "INR" : cur;

      final list = await _methodsService.fetchWithdrawalMethods(countryCode: _country);

      if (!mounted) return;
      setState(() {
        _items = list;
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

  void _openDynamicMethod(WithdrawalMethodItem it) {
    final key = it.withdrawalKey.trim().toUpperCase();

    if (key == "IMPS") {
      final gid = (it.groupId ?? "").trim();
      if (gid.isEmpty) {
        _toast("groupId missing for this method");
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GradientBackground(
            child: BillblendImpsWithdrawPage(
              withdrawalMethod: it.withdrawalMethod,
              withdrawalKey: it.withdrawalKey,
              methodCode: it.methodCode,
              minWithdrawal: it.minWithdrawal,
              maxWithdrawal: it.maxWithdrawal,
              groupId: gid,
            ),
          ),
        ),
      );
      return;
    }

    if (key == "UPI") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GradientBackground(
            child: GptWithdrawPage(
              withdrawalMethod: it.withdrawalMethod,
              withdrawalKey: it.withdrawalKey,
              methodCode: it.methodCode,
              minWithdrawal: it.minWithdrawal,
              maxWithdrawal: it.maxWithdrawal,
            ),
          ),
        ),
      );
      return;
    }

    _toast("This method is not supported yet: ${it.withdrawalKey}");
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
            "Withdraw",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.5),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: _IconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: _loading ? null : _boot,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.85), size: 18),
                      const SizedBox(width: 6),
                      Text(_country, style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
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
                        const SizedBox(height: 28),

                        Text(
                          "Withdrawal Methods",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Choose your withdrawal method",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // CASH first always
                        _MethodTile(
                          title: cashMethod,
                          subtitle: "Min ${cashMin.toStringAsFixed(0)} • Max ${cashMax.toStringAsFixed(0)}",
                          icon: Icons.payments_rounded,
                          badgeText: "Instant",
                          badgeColor: successAccent,
                          ctaText: "Withdraw Now",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GradientBackground(
                                  child: CashWithdrawPage(
                                    withdrawalMethod: cashMethod,
                                    withdrawalKey: cashKey,
                                    minWithdrawal: cashMin,
                                    maxWithdrawal: cashMax,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        if (_loading)
                          _LoadingBox()
                        else if (_error != null)
                          _ErrorBox(
                            text: _error!,
                            onRetry: _boot,
                          )
                        else if (_items.isEmpty)
                          _InfoBox(text: "No additional withdrawal methods available for $_country")
                        else
                          ..._items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _MethodTile(
                                title: it.withdrawalMethod,
                                subtitle:
                                    "Min ${it.minWithdrawal.toStringAsFixed(0)} • Max ${it.maxWithdrawal.toStringAsFixed(0)}",
                                icon: it.provider.toUpperCase() == "GPT"
                                    ? Icons.cloud_done_rounded
                                    : Icons.account_balance_rounded,
                                badgeText: it.provider.toUpperCase(),
                                badgeColor: primaryAccent,
                                ctaText: "Open",
                                onTap: () => _openDynamicMethod(it),
                              ),
                            );
                          }).toList(),

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

/* ---------------- UI Components (same style system) ---------------- */

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
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final String currency;
  final String country;
  const _TopHeader({required this.currency, required this.country});

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
              gradient: const LinearGradient(colors: [primaryAccent, secondaryAccent]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.outbox_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Secure Withdrawals",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Country: $country  •  Currency: $currency",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class _MethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final String ctaText;
  final VoidCallback onTap;

  const _MethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.ctaText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.6,
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
                    colors: [badgeColor.withOpacity(0.15), badgeColor.withOpacity(0.08)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: badgeColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      ctaText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w800,
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

class _LoadingBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Loading withdrawal methods...",
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorBox({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text("Retry", style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.75)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
