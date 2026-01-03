import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/brand_service.dart';

class DashboardHeader extends StatefulWidget implements PreferredSizeWidget {
  final String? fullName;
  final double? totalBalance; // kept for compatibility
  final String? currency; // kept for compatibility
  final VoidCallback onBalanceTap; // kept for compatibility
  final VoidCallback onLogoutTap;
  final VoidCallback onMenuTap;

  /// Platform / brand for UI: "TORROSPIN" or "MASCOT"
  final String selectedPlatform;
  final ValueChanged<String> onPlatformChanged;

  const DashboardHeader({
    super.key,
    required this.fullName,
    required this.totalBalance,
    required this.currency,
    required this.onBalanceTap,
    required this.onLogoutTap,
    required this.onMenuTap,
    required this.selectedPlatform,
    required this.onPlatformChanged,
  });

  // ❌ Not changed (as you asked)
  @override
  Size get preferredSize => const Size.fromHeight(65);

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  final BrandService _brandService = BrandService();

  Future<String?>? _logoUrlFuture;

  @override
  void initState() {
    super.initState();
    _logoUrlFuture = _brandService.fetchLogoUrl();
  }

  String get _platformLabel {
    if (widget.selectedPlatform.toUpperCase() == 'MASCOT') return 'Mascot';
    return 'Torrospin';
  }

  IconData get _platformIcon {
    if (widget.selectedPlatform.toUpperCase() == 'MASCOT') {
      return Icons.sports_esports_rounded;
    }
    return Icons.casino_rounded;
  }

  List<Color> get _platformGradient {
    if (widget.selectedPlatform.toUpperCase() == 'MASCOT') {
      return [const Color(0xFFFF6584), const Color(0xFFFF7B9C)];
    }
    return [const Color(0xFF00C9A7), const Color(0xFF00D4FF)];
  }

  /// ✅ Slightly bigger logo + more left, still responsive (no overflow)
  Widget _buildLogo(String? logoUrl) {
    return Container(
      // Less left padding -> logo looks more left-sided
      padding: const EdgeInsets.only(left: 2, right: 6),
      alignment: Alignment.centerLeft,
      child: SizedBox(
        // Slightly bigger (but safe because Expanded controls width)
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              // Give a "natural" logo width target; it will shrink automatically
              width: 170,
              height: 50,
              child: _LogoRenderer(logoUrl: logoUrl),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.black.withOpacity(0.35),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            // Hamburger button
            Container(
              margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: widget.onMenuTap,
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Menu',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),

            // ✅ Keeps it overflow-safe on small devices
            Expanded(
              child: FutureBuilder<String?>(
                future: _logoUrlFuture,
                builder: (context, snap) {
                  final url = (snap.connectionState == ConnectionState.done &&
                          snap.hasData &&
                          (snap.data ?? '').toString().trim().isNotEmpty)
                      ? snap.data
                      : null;

                  return _buildLogo(url);
                },
              ),
            ),
          ],
        ),
      ),

      // RIGHT SIDE - Platform selector
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  _platformGradient[0].withOpacity(0.2),
                  _platformGradient[1].withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _platformGradient[0].withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _platformGradient[0].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  widget.onPlatformChanged(value);
                },
                elevation: 16,
                color: const Color(0xFF1a1a2e),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                offset: const Offset(0, 44),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'TORROSPIN',
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF00C9A7),
                                  Color(0xFF00D4FF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.casino_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Torrospin',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.selectedPlatform.toUpperCase() ==
                              'TORROSPIN')
                            const Icon(Icons.check_rounded,
                                size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'MASCOT',
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF6584),
                                  Color(0xFFFF7B9C),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.sports_esports_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Mascot',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.selectedPlatform.toUpperCase() == 'MASCOT')
                            const Icon(Icons.check_rounded,
                                size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _platformGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          _platformIcon,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _platformLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoRenderer extends StatelessWidget {
  final String? logoUrl;

  const _LogoRenderer({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.trim().isEmpty) {
      return Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      );
    }

    return SvgPicture.network(
      logoUrl!,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      placeholderBuilder: (_) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
