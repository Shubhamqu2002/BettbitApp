// lib/pages/update_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../components/gradient_background.dart';
import '../services/update/update_service.dart';
import 'login_page.dart';
import 'home_page.dart';

class UpdatePage extends StatefulWidget {
  final ApkVersionInfo info;
  final int currentBuild;
  final String currentVersion;

  const UpdatePage({
    super.key,
    required this.info,
    required this.currentBuild,
    required this.currentVersion,
  });

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _opening = false;
  bool _checking = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _statusText = "Please update to continue.";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    _statusText = widget.info.force
        ? "Update required. Download & install the APK, then come back."
        : "Update available. Install and come back to continue.";
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  /// ✅ When user returns from Chrome/installer, verify installed build again
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyInstalledVersion();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) return "${(bytes / mb).toStringAsFixed(1)} MB";
    if (bytes >= kb) return "${(bytes / kb).toStringAsFixed(1)} KB";
    return "$bytes B";
  }

  Future<void> _openDownloadLink() async {
    if (_opening) return;

    setState(() {
      _opening = true;
      _statusText = "Opening browser... Download and install the APK.";
    });

    try {
      final uri = Uri.parse(widget.info.apkUrl);

      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        throw "Could not open the download link.";
      }

      if (!mounted) return;
      setState(() {
        _statusText =
            "Browser opened ✅ Download & install the APK.\nThen come back — we’ll verify automatically.";
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to open link: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _opening = false);
    }
  }

  /// ✅ Only checks installed version/build vs latestBuild from widget.info
  /// If installedBuild >= latestBuild -> continue
  /// Else -> stay here
  Future<void> _verifyInstalledVersion() async {
    if (_checking) return;

    setState(() {
      _checking = true;
      _statusText = "Checking installed version...";
    });

    try {
      final pkg = await PackageInfo.fromPlatform();
      final installedBuild = int.tryParse(pkg.buildNumber) ?? 0;
      final installedVersion = pkg.version;

      // ✅ Updated installed -> proceed
      if (installedBuild >= widget.info.latestBuild) {
        if (!mounted) return;
        setState(() {
          _statusText =
              "Updated ✅ ($installedVersion / $installedBuild). Continuing...";
        });
        await _goNextNormally();
        return;
      }

      // ❌ Still old -> stay on update page
      if (!mounted) return;
      setState(() {
        _statusText =
            "Update not installed yet.\n"
            "Installed: $installedVersion ($installedBuild)\n"
            "Required: ${widget.info.latestVersion} (${widget.info.latestBuild})\n\n"
            "Please install the APK and come back.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Could not verify version: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  Future<void> _goNextNormally() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final gamerId = prefs.getString('gamer_id') ?? '';

    if (!mounted) return;

    final target =
        (isLoggedIn && gamerId.isNotEmpty) ? HomePage.routeName : LoginPage.routeName;

    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // Icon with glow effect
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.purple.shade400,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.system_update_alt_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            "Update Available",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "A new version is ready for you",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ✅ Status box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _checking ? Icons.sync_rounded : Icons.info_outline_rounded,
                                  color: Colors.white.withOpacity(0.75),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _statusText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.85),
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Version Info Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildVersionBox(
                                      "Current",
                                      widget.currentVersion,
                                      "${widget.currentBuild}",
                                      Colors.white.withOpacity(0.5),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    _buildVersionBox(
                                      "Latest",
                                      info.latestVersion,
                                      "${info.latestBuild}",
                                      Colors.green.shade400,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Divider(color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 20),
                                _buildInfoRow(
                                  Icons.insert_drive_file_rounded,
                                  "File Name",
                                  info.fileName,
                                ),
                                const SizedBox(height: 14),
                                _buildInfoRow(
                                  Icons.storage_rounded,
                                  "Size",
                                  _formatBytes(info.fileSize),
                                ),
                                if (info.changeLog.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Divider(color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 20),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.new_releases_rounded,
                                              color: Colors.amber.shade400,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              "What's New",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          info.changeLog,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withOpacity(0.85),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Bottom fixed section
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (info.force)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade300,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "This update is required to continue",
                                    style: TextStyle(
                                      color: Colors.orange.shade100,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (info.force) const SizedBox(height: 12),

                        // Download button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: (_opening || _checking)
                                  ? [Colors.grey.shade600, Colors.grey.shade700]
                                  : [Colors.blue.shade500, Colors.purple.shade500],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_opening || _checking)
                                    ? Colors.transparent
                                    : Colors.blue.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_opening || _checking) ? null : _openDownloadLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: (_opening || _checking)
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _checking ? "Verifying..." : "Opening browser...",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.download_rounded,
                                          color: Colors.white, size: 22),
                                      SizedBox(width: 12),
                                      Text(
                                        "Download & Update",
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Manual check button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _checking ? null : _verifyInstalledVersion,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text("I Installed, Check Again"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionBox(
    String label,
    String version,
    String build,
    Color accentColor,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                version,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              Text(
                "($build)",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.7),
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
