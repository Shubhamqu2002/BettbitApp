// lib/components/banner_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../services/banner_service.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final BannerService _bannerService = BannerService();

  List<String> _bannerFiles = [];
  bool _isLoading = false;
  String? _error;

  PageController? _pageController;
  Timer? _autoTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _bannerService.fetchBanners();
      if (!mounted) return;

      setState(() {
        _bannerFiles = files;
      });

      _setupPageController();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load banners';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupPageController() {
    _pageController?.dispose();
    _autoTimer?.cancel();

    if (_bannerFiles.isEmpty) return;

    // ✅ Keep as-is (your current behavior)
    _pageController = PageController(viewportFraction: 0.96);
    _currentIndex = 0;

    if (_bannerFiles.length > 1) {
      _autoTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _autoScroll(),
      );
    }
  }

  void _autoScroll() {
    if (!mounted || _pageController == null || _bannerFiles.isEmpty) return;
    if (!_pageController!.hasClients) return;

    final nextPage = (_currentIndex + 1) % _bannerFiles.length;

    _pageController!.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );

    setState(() {
      _currentIndex = nextPage;
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Smaller height (banner-only look)
    const double bannerHeight = 120;

    if (_isLoading) {
      return const SizedBox(
        height: bannerHeight,
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: bannerHeight,
        child: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      );
    }

    if (_bannerFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final urls = _bannerFiles
        .map((file) => '${BannerService.bannerBaseUrl}$file')
        .toList();

    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final url = urls[index];

              return Padding(
                // ✅ no extra padding outside the banner (edge-to-edge inside page)
                padding: EdgeInsets.zero,
                child: Container(
                  // ✅ border + rounded corners
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    // ✅ curve the banner image corners
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      url,
                      // ✅ show full 860x220 banner without cutting
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, _, __) => Container(
                        alignment: Alignment.center,
                        color: Colors.black26,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // dot indicators (kept same)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(urls.length, (i) {
            final isActive = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: isActive ? 18 : 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF00C9A7)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}
