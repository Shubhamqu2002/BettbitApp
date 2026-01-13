// lib/services/update/update_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class ApkVersionInfo {
  final bool force;
  final String latestVersion;
  final int latestBuild;
  final int minRequiredBuild;
  final String changeLog;
  final String fileName;
  final int fileSize;
  final String apkUrl;

  ApkVersionInfo({
    required this.force,
    required this.latestVersion,
    required this.latestBuild,
    required this.minRequiredBuild,
    required this.changeLog,
    required this.fileName,
    required this.fileSize,
    required this.apkUrl,
  });

  factory ApkVersionInfo.fromApi(Map<String, dynamic> json) {
    final resp = (json['response'] as Map?)?.cast<String, dynamic>() ?? {};

    // API sends strings for many fields
    final forceStr = (resp['force'] ?? '').toString().toLowerCase();
    final latestBuild = int.tryParse((resp['latest_build'] ?? '0').toString()) ?? 0;
    final minReqBuild =
        int.tryParse((resp['min_required_build'] ?? '0').toString()) ?? 0;

    return ApkVersionInfo(
      force: forceStr == 'true',
      latestVersion: (resp['latest_version'] ?? '').toString(),
      latestBuild: latestBuild,
      minRequiredBuild: minReqBuild,
      changeLog: (resp['change_log'] ?? '').toString(),
      fileName: (resp['file_name'] ?? '').toString(),
      fileSize: int.tryParse((resp['file_size'] ?? '0').toString()) ?? 0,
      apkUrl: (resp['apk_url'] ?? '').toString(),
    );
  }
}

class UpdateCheckResult {
  final bool needsUpdate;
  final ApkVersionInfo? info;
  final int currentBuild;
  final String currentVersion;
  final String? error;

  UpdateCheckResult({
    required this.needsUpdate,
    required this.info,
    required this.currentBuild,
    required this.currentVersion,
    required this.error,
  });
}

class UpdateService {
  final String detailsUrl;

  UpdateService({required this.detailsUrl});

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
      final currentVersion = pkg.version;

      final res = await http.get(Uri.parse(detailsUrl)).timeout(
        const Duration(seconds: 8),
      );

      if (res.statusCode != 200) {
        return UpdateCheckResult(
          needsUpdate: false,
          info: null,
          currentBuild: currentBuild,
          currentVersion: currentVersion,
          error: "Version API failed: ${res.statusCode}",
        );
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final info = ApkVersionInfo.fromApi(decoded);

      final needsUpdate = currentBuild < info.minRequiredBuild;

      if (kDebugMode) {
        debugPrint(
          "✅ [UPDATE] current=$currentVersion($currentBuild) | "
          "latest=${info.latestVersion}(${info.latestBuild}) | "
          "minRequired=${info.minRequiredBuild} | force=${info.force}",
        );
      }

      return UpdateCheckResult(
        needsUpdate: needsUpdate,
        info: info,
        currentBuild: currentBuild,
        currentVersion: currentVersion,
        error: null,
      );
    } catch (e) {
      // If version check fails, we allow app to continue (safe fallback)
      return UpdateCheckResult(
        needsUpdate: false,
        info: null,
        currentBuild: 0,
        currentVersion: '',
        error: e.toString(),
      );
    }
  }
}
