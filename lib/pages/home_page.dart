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
import '../services/game_categories_service.dart';

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

  String _selectedPlatform = 'ALL';
  String _selectedCategory = 'ALL';

  bool _isRefreshing = false;

  // ✅ NEW: Categories from API
  final List<GameCategoryItem> _apiCategories = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadUserAndBalance();
    _startBalancePolling();
    _loadCategories();
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

  Future<void> _loadCategories() async {
    if (_isLoadingCategories) return;
    setState(() => _isLoadingCategories = true);

    try {
      final items = await GameCategoriesService.instance.fetchCategories();

      if (!mounted) return;
      setState(() {
        _apiCategories
          ..clear()
          ..addAll(items);

        // ✅ If current selected category doesn't exist anymore, fallback
        final exists = _apiCategories.any((e) => e.categoryName == _selectedCategory);
        if (!exists && _selectedCategory != 'ALL') {
          _selectedCategory = 'ALL';
        }
      });
    } catch (_) {
      // silent (keep UI working)
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _onPullToRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await Future.wait([
        _loadUserAndBalance(),
        _loadCategories(),
      ]);
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

  /// ✅ Build tabs list:
  /// Keep "ALL" first (app logic expects it), rest from API by sequence
  List<_UiTabItem> _buildTabsFromApi() {
    final tabs = <_UiTabItem>[
      const _UiTabItem(
        name: 'ALL',
        label: 'ALL',
        imageUrl: '', // no api image for ALL
      ),
      ..._apiCategories.map((e) {
        return _UiTabItem(
          name: e.categoryName,
          label: e.uiLabel.toUpperCase(),
          imageUrl: e.fullImageUrl, // ✅ https://bettbit.com/ + imageUrl
        );
      }),
    ];

    // avoid duplicate if API someday sends ALL
    final seen = <String>{};
    return tabs.where((t) {
      if (seen.contains(t.name)) return false;
      seen.add(t.name);
      return true;
    }).toList();
  }

  Widget _buildCategoryTabs() {
    final tabs = _buildTabsFromApi();

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: _isLoadingCategories && _apiCategories.isEmpty
          ? Row(
              children: const [
                Expanded(
                  child: Opacity(
                    opacity: 0.9,
                    child: BrandedLoader(brandName: 'Bettbit', size: 36),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final tab = tabs[index];
                  final bool isSelected = _selectedCategory == tab.name;

                  return Padding(
                    padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 10),
                    child: _CategoryTab(
                      label: tab.label,
                      imageUrl: tab.imageUrl,
                      isSelected: isSelected,
                      onTap: () => _onCategoryChanged(tab.name),
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAccountPage()));
  }

  void _goToDeposit() {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DepositPage()));
  }

  void _goToWithdraw() {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WithdrawPage()));
  }

  void _goToAccountRecords() {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountRecordsPage()));
  }

  void _goToBettingRecords() {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BettingRecordsPage()));
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

/// small helper for UI tabs
class _UiTabItem {
  final String name;     // actual category key used in logic
  final String label;    // display text
  final String imageUrl; // full url (https://bettbit.com/...)
  const _UiTabItem({
    required this.name,
    required this.label,
    required this.imageUrl,
  });
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final String imageUrl; // ✅ now image instead of icon
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.imageUrl,
    required this.isSelected,
    required this.onTap,
  });

  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? const LinearGradient(
            colors: [primaryAccent, secondaryAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: bg,
            color: isSelected ? null : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.20)
                  : Colors.white.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabIcon(imageUrl: imageUrl, isSelected: isSelected),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
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

class _TabIcon extends StatelessWidget {
  final String imageUrl;
  final bool isSelected;

  const _TabIcon({required this.imageUrl, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    // ✅ If imageUrl empty (ALL tab), keep a small fallback icon (only here)
    if (imageUrl.isEmpty) {
      return Icon(
        Icons.apps_rounded,
        size: 18,
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 20,
        height: 20,
        color: Colors.white.withOpacity(isSelected ? 0.14 : 0.10),
        alignment: Alignment.center,
        child: Image.network(
          imageUrl,
          width: 18,
          height: 18,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Icon(
              Icons.image_not_supported_outlined,
              size: 16,
              color: Colors.white.withOpacity(0.65),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.75),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
