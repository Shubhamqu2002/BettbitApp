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

    _pageController = PageController(viewportFraction: 0.9);
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
    // onPageChanged will also update, but we keep this in sync
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
    if (_isLoading) {
      return const SizedBox(
        height: 160,
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
        height: 160,
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
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index; // ✅ fix: dots now update properly
              });
            },
            itemBuilder: (context, index) {
              final url = urls[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Soft glass background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.06),
                              Colors.white.withOpacity(0.02),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Banner image
                      Image.network(
                        url,
                        fit: BoxFit.cover,
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
                      // Top gradient overlay for better look
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.35),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Optional label chip
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.black.withOpacity(0.45),
                          ),
                          child: const Text(
                            'Featured',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // dot indicators
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
