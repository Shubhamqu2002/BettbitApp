// lib/components/vendors/vendor_games_section.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart'; // ✅ for .svg support

import '../../services/vendor_game_service.dart';
import '../../services/wallet_service.dart';
import '../../pages/deposit_page.dart';

// ✅ Lucky Sports service
import '../../services/luckysports/luckysport_service.dart';

// ✅ NEW: AddMember service (one-time registration)
import '../../services/addmember/addmember_service.dart';

import '../branded_loader.dart';
import '../models/deposit_required_modal.dart';

class VendorGamesSection extends StatefulWidget {
  final String category;
  final String platform;

  const VendorGamesSection({
    super.key,
    required this.category,
    required this.platform,
  });

  @override
  State<VendorGamesSection> createState() => _VendorGamesSectionState();
}

class _VendorGamesSectionState extends State<VendorGamesSection> {
  static const String _allVendorCode = 'ALL';

  // ✅ Prefix for relative assets paths like "assets/luckysports.png"
  static const String _bettbitCdnPrefix = "https://bettbit.com/";

  // ✅ MUST MATCH HomePage keys
  static const String kTotalBalanceKey = 'wallet_total_balance';
  static const String kBalanceUpdatedAtKey = 'wallet_balance_updated_at_ms';
  static const String kCurrencyKey = 'currency';

  final VendorGameService _service = VendorGameService();
  final WalletService _walletService = WalletService();
  final ScrollController _scrollController = ScrollController();

  // ✅ NEW: AddMember Service instance
  final AddMemberService _addMember = AddMemberService.instance;

  bool _isLoadingVendors = false;
  bool _isLoadingGames = false;
  bool _isLoadingMoreGames = false;

  List<VendorModel> _vendors = [];
  String? _selectedVendorCode;

  List<GameModel> _games = [];
  int _currentGamePage = 0;
  bool _hasMoreGames = false;
  int _totalGames = 0;

  String? _errorMessage;

  bool _isLaunchingGame = false;
  String? _launchingGameName;

  bool _isCheckingBalance = false; // ✅ prevents double-check spam

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟦 [VendorGames] $msg");
  }

  // ✅ Normalize image URLs:
  // - If already http/https -> return as is
  // - If "assets/..." (relative) -> prefix with https://bettbit.com/
  // - If begins with "/" -> prefix
  // - Otherwise keep (might be data:, file:, etc.)
  String _normalizeImageUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) return s;

    // your backend sometimes returns: assets/luckysports.png
    if (lower.startsWith('assets/')) return '$_bettbitCdnPrefix$s';

    if (s.startsWith('/')) return '$_bettbitCdnPrefix${s.substring(1)}';

    return s;
  }

  bool _isSvgUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('.svg') || u.startsWith('data:image/svg');
  }

  Widget _networkImageSmart({
    required String url,
    required BoxFit fit,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Alignment alignment = Alignment.center,
    double? iconSize,
  }) {
    final normalized = _normalizeImageUrl(url);
    if (normalized.isEmpty) {
      return Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white38,
        size: iconSize ?? 28,
      );
    }

    // ✅ SVG support (fixes: https://.../Ardervar.svg)
    if (_isSvgUrl(normalized)) {
      return Padding(
        padding: padding,
        child: SvgPicture.network(
          normalized,
          fit: fit,
          alignment: alignment,
          placeholderBuilder: (_) => Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ✅ Normal images (png/jpg/webp/etc.)
    return Padding(
      padding: padding,
      child: Image.network(
        normalized,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white38,
          size: iconSize ?? 28,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVendorsAndInitialGames();
  }

  @override
  void didUpdateWidget(covariant VendorGamesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.platform != widget.platform) {
      _loadVendorsAndInitialGames();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMoreGames || _isLoadingMoreGames || _isLoadingGames) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGames();
    }
  }

  void _showPrettyError(String title, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111827),
        elevation: 10,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    final s = e.toString().replaceAll('Exception: ', '').trim();
    return s.isEmpty ? 'Something went wrong. Please try again.' : s;
  }

  Future<void> _loadVendorsAndInitialGames() async {
    setState(() {
      _isLoadingVendors = true;
      _isLoadingGames = true;
      _errorMessage = null;
      _vendors = [];
      _games = [];
      _selectedVendorCode = _allVendorCode;
      _currentGamePage = 0;
      _hasMoreGames = false;
      _totalGames = 0;
    });

    try {
      final vendors = await _service.fetchVendors(
        category: widget.category,
        platform: widget.platform,
      );

      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _isLoadingVendors = false;
      });

      await _loadGames(reset: true);
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyErrorMessage(e);
      setState(() {
        _isLoadingVendors = false;
        _isLoadingGames = false;
        _errorMessage = msg;
      });
      _showPrettyError('Unable to load vendors', msg);
    }
  }

  Future<void> _loadGames({bool reset = false}) async {
    if (_selectedVendorCode == null) return;

    if (reset) {
      setState(() {
        _isLoadingGames = true;
        _errorMessage = null;
        _games = [];
        _currentGamePage = 0;
        _hasMoreGames = false;
        _totalGames = 0;
      });
    } else {
      setState(() => _isLoadingMoreGames = true);
    }

    try {
      final vendorCodeToSend = _selectedVendorCode ?? _allVendorCode;

      final result = await _service.fetchGames(
        category: widget.category,
        vendorCode: vendorCodeToSend,
        platform: widget.platform,
        page: _currentGamePage,
        size: 24,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _games = result.games;
        } else {
          _games = [..._games, ...result.games];
        }

        _totalGames = result.totalElements;
        _hasMoreGames = !result.last;
        _isLoadingGames = false;
        _isLoadingMoreGames = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyErrorMessage(e);
      setState(() {
        _isLoadingGames = false;
        _isLoadingMoreGames = false;
        _errorMessage = msg;
      });
      _showPrettyError('Unable to load games', msg);
    }
  }

  Future<void> _loadMoreGames() async {
    if (!_hasMoreGames || _isLoadingMoreGames) return;
    _currentGamePage += 1;
    await _loadGames(reset: false);
  }

  void _onAllTap() async {
    if (_selectedVendorCode == _allVendorCode) return;

    setState(() {
      _selectedVendorCode = _allVendorCode;
      _errorMessage = null;
    });

    await _loadGames(reset: true);
  }

  void _onVendorTap(VendorModel vendor) async {
    if (_selectedVendorCode == vendor.vendorCode) return;

    setState(() {
      _selectedVendorCode = vendor.vendorCode;
      _errorMessage = null;
    });

    await _loadGames(reset: true);
  }

  Future<Map<String, dynamic>> _getReliableBalance() async {
    final prefs = await SharedPreferences.getInstance();

    double stored = prefs.getDouble(kTotalBalanceKey) ?? 0.0;
    String currency = (prefs.getString(kCurrencyKey) ?? 'INR').trim();
    currency = currency.isEmpty ? 'INR' : currency;

    final updatedAt = prefs.getInt(kBalanceUpdatedAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    final isStale = updatedAt == 0 || (now - updatedAt) > 15000;

    if ((stored <= 0) || isStale) {
      final gamerId = (prefs.getString('gamer_id') ?? '').trim();
      if (gamerId.isNotEmpty) {
        final live = await _walletService.fetchBalance(gamerId);

        await prefs.setDouble(kTotalBalanceKey, live.totalBalance);
        await prefs.setString(kCurrencyKey, live.currency);
        await prefs.setInt(kBalanceUpdatedAtKey, now);

        stored = live.totalBalance;
        if (live.currency.trim().isNotEmpty) currency = live.currency.trim();
      }
    }

    return {'totalBalance': stored, 'currency': currency};
  }

  Future<void> _onGameTap(GameModel game) async {
    if (_isLaunchingGame) return;
    if (_isCheckingBalance) return;

    _isCheckingBalance = true;
    try {
      final bal = await _getReliableBalance();
      final totalBalance = (bal['totalBalance'] as double?) ?? 0.0;
      final currency = (bal['currency'] as String?) ?? 'INR';

      if (totalBalance <= 0) {
        if (!mounted) return;
        await showDepositRequiredModal(
          context,
          totalBalance: totalBalance,
          currency: currency,
          onDepositTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DepositPage()),
            );
          },
        );
        return;
      }
    } finally {
      _isCheckingBalance = false;
    }

    setState(() {
      _isLaunchingGame = true;
      _launchingGameName = game.gameName;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = (prefs.getString('user_name') ?? '').trim();

      // ✅ Use registered_country (as you requested). fallback to countryCode then IN.
      final registeredCountry =
          (prefs.getString('registered_country') ?? '').trim();
      final countryCodeFallback = (prefs.getString('countryCode') ?? '').trim();
      final cc = registeredCountry.isNotEmpty
          ? registeredCountry
          : (countryCodeFallback.isNotEmpty ? countryCodeFallback : 'IN');

      if (userName.isEmpty) {
        _showPrettyError(
            'Login required', 'User name not found. Please re-login.');
        return;
      }

      final aggregator = game.aggregator.toUpperCase().trim();
      final vendorCode = game.vendorCode.toUpperCase().trim();

      _log(
          "Tap game=${game.gameName} vendorCode=$vendorCode aggregator=$aggregator");

      String? launchUrl;
      String? luckyWidgetHtml;

      if (vendorCode == 'LUCKY SPORTS' || vendorCode == 'LUCKYSPORTS') {
        _log("➡️ LuckySports: ensure member create (one-time) ...");
        await _addMember.ensureLuckySportsMemberCreatedOnce(
          playerId: userName,
          countryCode: cc,
        );
        _log("✅ LuckySports: member ensured. Now load widget HTML...");

        luckyWidgetHtml = await LuckySportService.instance.getWidgetLoaderHtml(
          playerId: userName,
          countryCode: cc,
          language: 'en',
        );
        _log("✅ LuckySports widget_loader_script len=${luckyWidgetHtml.length}");
      } else if (aggregator == 'TORROSPIN') {
        _log("➡️ Torrospin: ensure adduser (one-time) ...");
        await _addMember.ensureTorrospinUserAddedOnce(userName: userName);
        _log("✅ Torrospin: adduser ensured. Now generate launch url...");

        launchUrl = await _service.generateTorrospinLaunchUrl(
          userName: userName,
          gameCode: game.gameCode,
        );
      } else if (aggregator == 'MASCOT') {
        _log("➡️ Mascot: ensure Player.Set (one-time) ...");
        await _addMember.ensureMascotPlayerSetOnce(userName: userName);
        _log("✅ Mascot: Player.Set ensured. Now create session...");

        launchUrl = await _service.createMascotSession(
          userName: userName,
          gameCode: game.gameCode,
        );
      } else {
        _showPrettyError('Launch not supported',
            'Game launch is not configured for $aggregator.');
        return;
      }

      if (!mounted) return;

      if (luckyWidgetHtml != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LuckySportWebViewPage(
              widgetLoaderScriptHtml: luckyWidgetHtml!,
              title: game.gameName,
            ),
            fullscreenDialog: true,
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameWebViewPage(
              url: launchUrl!,
              title: game.gameName,
            ),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      final msg = _friendlyErrorMessage(e);
      _showPrettyError('Unable to launch game', msg);
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingGame = false;
          _launchingGameName = null;
        });
      }
    }
  }

  Widget _miniBrandedLoader({double size = 34, String? label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandedLoader(brandName: 'Bettbit', size: size),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransparentLaunchingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.18),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandedLoader(
              brandName: 'Bettbit',
              size: 54,
              primaryColor: Colors.white.withOpacity(0.95),
              secondaryColor: Colors.white.withOpacity(0.55),
            ),
            const SizedBox(height: 14),
            Text(
              'Please wait',
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _launchingGameName ?? 'Launching game...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryLabel =
        widget.category[0] + widget.category.substring(1).toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$categoryLabel Vendors',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_totalGames > 0)
                      Text(
                        '$_totalGames games',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildVendorsRow(),
                const SizedBox(height: 18),
                _buildGamesGrid(),
                if (_isLoadingMoreGames)
                  Padding(
                    padding: const EdgeInsets.only(top: 14.0),
                    child: Center(child: _miniBrandedLoader(size: 34)),
                  ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            if (_isLaunchingGame) _buildTransparentLaunchingOverlay(),
          ],
        ),
      ),
    );
  }

  // ---------------- rest of your file unchanged ----------------

  Widget _buildVendorsRow() {
    if (_isLoadingVendors) {
      return SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => Container(
            width: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 98,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildAllVendorCard(),
            ..._vendors.map((vendor) {
              final bool isSelected = vendor.vendorCode == _selectedVendorCode;

              // ✅ important: normalize relative or svg links
              final logoUrl = _normalizeImageUrl(vendor.resolvedImageUrl);

              return GestureDetector(
                onTap: () => _onVendorTap(vendor),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF21C8F6), Color(0xFF637BFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !isSelected ? Colors.white.withOpacity(0.04) : null,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.08),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              color: Colors.black.withOpacity(0.3),
                              alignment: Alignment.center,
                              child: _networkImageSmart(
                                url: logoUrl,
                                fit: BoxFit.contain,
                                padding: const EdgeInsets.all(10),
                                iconSize: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor.vendorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllVendorCard() {
    final bool isSelected =
        (_selectedVendorCode ?? _allVendorCode) == _allVendorCode;

    return GestureDetector(
      onTap: _onAllTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF21C8F6), Color(0xFF637BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isSelected ? Colors.white.withOpacity(0.04) : null,
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.9)
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.apps_rounded,
                      size: 34,
                      color: Colors.white.withOpacity(isSelected ? 1.0 : 0.75),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ALL',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesGrid() {
    if (_isLoadingGames && _games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _miniBrandedLoader(size: 46, label: 'Loading games...'),
        ),
      );
    }

    if (_games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No games available for this selection.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    if (width < 360) {
      crossAxisCount = 2;
    } else if (width > 600) {
      crossAxisCount = 4;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _games.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final game = _games[index];
        return GestureDetector(
          onTap: () => _onGameTap(game),
          child: _buildGameCard(game),
        );
      },
    );
  }

  Widget _buildGameCard(GameModel game) {
    // ✅ normalize relative or svg links
    final imgUrl = _normalizeImageUrl(game.displayImageUrl);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.45),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    alignment: Alignment.center,
                    child: _networkImageSmart(
                      url: imgUrl,
                      fit: BoxFit.contain, // ✅ no crop (sports 75x72 fits)
                      padding: const EdgeInsets.all(8),
                      iconSize: 32,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              game.gameName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ Game WebView ------------------------------ */

class GameWebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const GameWebViewPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<GameWebViewPage> createState() => _GameWebViewPageState();
}

class _GameWebViewPageState extends State<GameWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05070A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: BrandedLoader(brandName: 'Bettbit', size: 64),
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------- Lucky Sports WebView -------------------------- */

class LuckySportWebViewPage extends StatefulWidget {
  final String widgetLoaderScriptHtml;
  final String title;

  const LuckySportWebViewPage({
    super.key,
    required this.widgetLoaderScriptHtml,
    required this.title,
  });

  @override
  State<LuckySportWebViewPage> createState() => _LuckySportWebViewPageState();
}

class _LuckySportWebViewPageState extends State<LuckySportWebViewPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  int _progress = 0;
  bool _loaderHidden = false;
  Timer? _hardStop;

  void _log(String msg) {
    if (kDebugMode) debugPrint("🟣 [LuckySportWeb] $msg");
  }

  void _hideLoaderOnce(String reason) {
    if (_loaderHidden) return;
    _loaderHidden = true;
    _hardStop?.cancel();
    _log("✅ hideLoaderOnce: $reason");
    if (mounted) setState(() => _isLoading = false);
  }

  String _ensureFullHtmlDoc(String html) {
    final s = html.trim();
    final lower = s.toLowerCase();
    if (lower.contains('<html') || lower.contains('<!doctype')) return s;

    return """
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
  <style>
    html, body { margin:0; padding:0; width:100%; height:100%; background:#05070A; }
  </style>
</head>
<body>
$s
</body>
</html>
""";
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05070A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            _progress = p;
            if (!_loaderHidden && mounted) setState(() {});
            if (p >= 85) {
              Future.delayed(const Duration(milliseconds: 450), () {
                if (!_loaderHidden) _hideLoaderOnce("progress>=85");
              });
            }
          },
          onPageStarted: (url) {
            _log("onPageStarted: $url");
            if (!_loaderHidden && mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            _log("onPageFinished: $url");
            _hideLoaderOnce("page finished");
          },
          onWebResourceError: (e) {
            _log("⚠️ WebResourceError: ${e.errorCode} ${e.description}");
            if (!_loaderHidden) _hideLoaderOnce("resource error");
          },
        ),
      );

    _hardStop = Timer(const Duration(seconds: 10), () {
      if (!_loaderHidden) _hideLoaderOnce("hard stop 10s");
    });

    _load();
  }

  Future<void> _load() async {
    try {
      final html = _ensureFullHtmlDoc(widget.widgetLoaderScriptHtml);
      await _controller.loadHtmlString(
        html,
        baseUrl: "https://widgetholder.uni247.xyz/",
      );
    } catch (e) {
      _log("❌ loadHtmlString failed: $e");
      _hideLoaderOnce("loadHtmlString failed");
    }
  }

  @override
  void dispose() {
    _hardStop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandedLoader(brandName: 'Bettbit', size: 64),
                  const SizedBox(height: 12),
                  Text(
                    'Loading... $_progress%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
