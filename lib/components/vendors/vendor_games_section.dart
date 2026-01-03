// lib/components/vendors/vendor_games_section.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/vendor_game_service.dart';
import '../branded_loader.dart';

class VendorGamesSection extends StatefulWidget {
  final String category; // "ALL", "HOT", "SLOT", "CASINO", ...
  final String platform; // "TORROSPIN", "MASCOT"

  const VendorGamesSection({
    super.key,
    required this.category,
    required this.platform,
  });

  @override
  State<VendorGamesSection> createState() => _VendorGamesSectionState();
}

class _VendorGamesSectionState extends State<VendorGamesSection> {
  final VendorGameService _service = VendorGameService();
  final ScrollController _scrollController = ScrollController();

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

  Future<void> _loadVendorsAndInitialGames() async {
    setState(() {
      _isLoadingVendors = true;
      _isLoadingGames = true;
      _errorMessage = null;
      _vendors = [];
      _games = [];
      _selectedVendorCode = null;
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

      if (vendors.isEmpty) {
        setState(() {
          _isLoadingVendors = false;
          _isLoadingGames = false;
          _vendors = [];
          _games = [];
          _selectedVendorCode = null;
          _hasMoreGames = false;
          _errorMessage = 'No vendors found for this selection.';
        });
        return;
      }

      setState(() {
        _vendors = vendors;
        _selectedVendorCode = vendors.first.vendorCode;
        _isLoadingVendors = false;
      });

      await _loadGames(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingVendors = false;
        _isLoadingGames = false;
        _errorMessage = 'Failed to load vendors: $e';
      });
    }
  }

  Future<void> _loadGames({bool reset = false}) async {
    if (_selectedVendorCode == null) return;

    if (reset) {
      setState(() {
        _isLoadingGames = true;
        _games = [];
        _currentGamePage = 0;
        _hasMoreGames = false;
        _totalGames = 0;
      });
    } else {
      setState(() {
        _isLoadingMoreGames = true;
      });
    }

    try {
      final result = await _service.fetchGames(
        category: widget.category,
        vendorCode: _selectedVendorCode!,
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingGames = false;
        _isLoadingMoreGames = false;
        _errorMessage ??= 'Failed to load games: $e';
      });
    }
  }

  Future<void> _loadMoreGames() async {
    if (!_hasMoreGames || _isLoadingMoreGames) return;
    _currentGamePage += 1;
    await _loadGames(reset: false);
  }

  void _onVendorTap(VendorModel vendor) async {
    if (_selectedVendorCode == vendor.vendorCode) return;

    setState(() {
      _selectedVendorCode = vendor.vendorCode;
    });

    await _loadGames(reset: true);
  }

  Future<void> _onGameTap(GameModel game) async {
    if (_isLaunchingGame) return;

    setState(() {
      _isLaunchingGame = true;
      _launchingGameName = game.gameName;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? '';

      if (userName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User name not found. Please re-login.'),
          ),
        );
        return;
      }

      final aggregator = game.aggregator.toUpperCase();
      String launchUrl;

      if (aggregator == 'TORROSPIN') {
        launchUrl = await _service.generateTorrospinLaunchUrl(
          userName: userName,
          gameCode: game.gameCode,
        );
      } else if (aggregator == 'MASCOT') {
        launchUrl = await _service.createMascotSession(
          userName: userName,
          gameCode: game.gameCode,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Game launch not configured for $aggregator aggregator.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameWebViewPage(
            url: launchUrl,
            title: game.gameName,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch game: $e'),
        ),
      );
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
        BrandedLoader(
          brandName: 'Bettbit',
          size: size,
        ),
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

  // ✅ NEW: transparent stylish launching UI (no background card)
  Widget _buildTransparentLaunchingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          // lighter dim, no “box”
          color: Colors.black.withOpacity(0.18),
          child: Center(
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
                  _launchingGameName != null
                      ? _launchingGameName!
                      : 'Launching game...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                    child: Center(
                      child: _miniBrandedLoader(size: 34),
                    ),
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

            // ✅ updated overlay style (transparent, no box)
            if (_isLaunchingGame) _buildTransparentLaunchingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsRow() {
    if (_isLoadingVendors) {
      return SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
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

    if (_vendors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No vendors available.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 98,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _vendors.map((vendor) {
            final bool isSelected = vendor.vendorCode == _selectedVendorCode;
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
                          colors: [
                            Color(0xFF21C8F6),
                            Color(0xFF637BFF),
                          ],
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
                            child: Image.network(
                              vendor.resolvedImageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white38,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildGamesGrid() {
    if (_isLoadingGames && _games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _miniBrandedLoader(
            size: 46,
            label: 'Loading games...',
          ),
        ),
      );
    }

    if (_games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No games available for this vendor.',
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Image.network(
                      game.displayImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.videogame_asset_outlined,
                        color: Colors.white38,
                        size: 32,
                      ),
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
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {},
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
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white,
          ),
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
                child: BrandedLoader(
                  brandName: 'Bettbit',
                  size: 64,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
