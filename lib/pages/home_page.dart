// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/gradient_background.dart';
import '../components/dashboard_header.dart';
import '../components/balance_modal.dart';
import '../components/hamburger_menu_sheet.dart';
import '../components/banner_carousel.dart';
import '../components/branded_loader.dart';

import '../components/vendors/all_vendors.dart';
import '../components/vendors/hot_vendors.dart';
import '../components/vendors/slot_vendors.dart';
import '../components/vendors/casino_vendors.dart';
import '../components/vendors/vendor_games_section.dart';

import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import 'login_page.dart';

import 'my_account_page.dart';
import 'deposit_page.dart';
import 'withdraw_page.dart';
import 'account_records_page.dart';
import 'betting_records_page.dart';

class HomePage extends StatefulWidget {
  static const String routeName = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ SAME KEYS USED IN VendorGamesSection
  static const String kTotalBalanceKey = 'wallet_total_balance';
  static const String kBalanceUpdatedAtKey = 'wallet_balance_updated_at_ms';
  static const String kCurrencyKey = 'currency';

  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _fullName = 'Player';
  String? _gamerId;
  String? _userName;

  String _currency = 'INR';
  double _cashBalance = 0.00;
  double _promoBalance = 0.00;
  double _totalBalance = 0.00;

  Timer? _balanceTimer;
  bool _isFetchingBalance = false;

  String _selectedPlatform = 'TORROSPIN';
  String _selectedCategory = 'ALL';

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadUserAndBalance();
    _startBalancePolling();
  }

  void _startBalancePolling() {
    _balanceTimer?.cancel();
    _balanceTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _refreshBalance());
  }

  Future<void> _loadUserAndBalance() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // ✅ read stored total balance instantly (if present)
    final storedTotal = prefs.getDouble(kTotalBalanceKey) ?? 0.00;

    setState(() {
      _fullName = prefs.getString('full_name') ?? 'Player';
      _gamerId = prefs.getString('gamer_id');
      _userName = prefs.getString('user_name');

      _currency = prefs.getString(kCurrencyKey) ?? 'INR';

      _cashBalance = 0.00;
      _promoBalance = 0.00;
      _totalBalance = storedTotal;
    });

    await _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final id = _gamerId;
    if (id == null || id.isEmpty) return;

    if (_isFetchingBalance) return;
    _isFetchingBalance = true;

    try {
      final balance = await _walletService.fetchBalance(id);

      final prefs = await SharedPreferences.getInstance();

      // ✅ ALWAYS store (even if 0 from error fallback)
      await prefs.setDouble(kTotalBalanceKey, balance.totalBalance);
      await prefs.setString(kCurrencyKey, balance.currency);
      await prefs.setInt(
        kBalanceUpdatedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (!mounted) return;
      setState(() {
        _cashBalance = balance.cashBalance;
        _promoBalance = balance.promoBalance;
        _totalBalance = balance.totalBalance;
        _currency = balance.currency;
      });
    } finally {
      _isFetchingBalance = false;
    }
  }

  Future<void> _onPullToRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await _loadUserAndBalance();
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _authService.logout();
    _balanceTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTotalBalanceKey);
    await prefs.remove(kBalanceUpdatedAtKey);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, LoginPage.routeName);
  }

  void _openBalanceModal() {
    showDialog(
      context: context,
      builder: (context) => BalanceModal(
        cashBalance: _cashBalance,
        promoBalance: _promoBalance,
        totalBalance: _totalBalance,
        currency: _currency,
      ),
    );
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _onPlatformChanged(String newPlatform) {
    setState(() => _selectedPlatform = newPlatform.toUpperCase());
  }

  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    super.dispose();
  }

  Widget _buildCategoryTabs() {
    final tabs = [
      {'name': 'ALL', 'icon': Icons.apps_rounded},
      {'name': 'HOT', 'icon': Icons.local_fire_department_rounded},
      {'name': 'SLOT', 'icon': Icons.casino_rounded},
      {'name': 'CASINO', 'icon': Icons.style_rounded},
      {'name': 'TOURNEY', 'icon': Icons.emoji_events_rounded},
      {'name': 'SPORTS', 'icon': Icons.sports_soccer_rounded},
      {'name': 'BINGO', 'icon': Icons.grid_on_rounded},
      {'name': 'TABLE', 'icon': Icons.table_restaurant_rounded},
    ];

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final tabName = tab['name'] as String;
            final tabIcon = tab['icon'] as IconData;
            final bool isSelected = _selectedCategory == tabName;

            return Padding(
              padding:
                  EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 10),
              child: _CategoryTab(
                label: tabName,
                icon: tabIcon,
                isSelected: isSelected,
                onTap: () => _onCategoryChanged(tabName),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildVendorSection() {
    switch (_selectedCategory) {
      case 'HOT':
        return HotVendorsSection(platform: _selectedPlatform);
      case 'SLOT':
        return SlotVendorsSection(platform: _selectedPlatform);
      case 'CASINO':
        return CasinoVendorsSection(platform: _selectedPlatform);
      case 'ALL':
        return AllVendorsSection(platform: _selectedPlatform);
      default:
        return VendorGamesSection(
          category: _selectedCategory,
          platform: _selectedPlatform,
        );
    }
  }

  void _goToMyAccount() {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyAccountPage()));
  }

  void _goToDeposit() {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DepositPage()));
  }

  void _goToWithdraw() {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WithdrawPage()));
  }

  void _goToAccountRecords() {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccountRecordsPage()));
  }

  void _goToBettingRecords() {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BettingRecordsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: DashboardHeader(
          fullName: _fullName,
          totalBalance: _totalBalance,
          currency: _currency,
          onBalanceTap: _openBalanceModal,
          onMenuTap: _openMenu,
          onLogoutTap: () => _logout(context),
          selectedPlatform: _selectedPlatform,
          onPlatformChanged: _onPlatformChanged,
        ),
        drawer: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: HamburgerMenuSheet(
            fullName: _fullName,
            userName: _userName,
            totalBalance: _totalBalance,
            currency: _currency,
            onWalletTap: () {
              Navigator.pop(context);
              _openBalanceModal();
            },
            onMyAccountTap: _goToMyAccount,
            onDepositTap: _goToDeposit,
            onWithdrawTap: _goToWithdraw,
            onAccountRecordsTap: _goToAccountRecords,
            onBettingRecordsTap: _goToBettingRecords,
            onLogoutTap: () {
              Navigator.pop(context);
              _logout(context);
            },
          ),
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onPullToRefresh,
              color: Colors.transparent,
              backgroundColor: Colors.transparent,
              displacement: 30,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height -
                        (MediaQuery.of(context).padding.top) -
                        kToolbarHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: BannerCarousel(),
                        ),
                        const SizedBox(height: 20),
                        _buildCategoryTabs(),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildVendorSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isRefreshing)
              Container(
                color: Colors.black.withOpacity(0.25),
                alignment: Alignment.topCenter,
                child: const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: BrandedLoader(brandName: 'Bettbit', size: 62),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
