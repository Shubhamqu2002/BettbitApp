import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API item model
class GameCategoryItem {
  final int id;
  final String categoryName;
  final int status;
  final int sequence;
  final String imageUrl;

  GameCategoryItem({
    required this.id,
    required this.categoryName,
    required this.status,
    required this.sequence,
    required this.imageUrl,
  });

  factory GameCategoryItem.fromJson(Map<String, dynamic> json) {
    return GameCategoryItem(
      id: (json['id'] ?? 0) as int,
      categoryName: (json['categoryName'] ?? '').toString().trim(),
      status: (json['status'] ?? 0) as int,
      sequence: (json['sequence'] ?? 999999) as int,
      imageUrl: (json['imageUrl'] ?? '').toString().trim(),
    );
  }

  /// ✅ Build full icon URL: https://bettbit.com/ + assets/...
  String get fullImageUrl {
    const base = 'https://bettbit.com/';
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    final cleanBase = base.endsWith('/') ? base : '$base/';
    final cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    return '$cleanBase$cleanPath';
  }

  String get uiLabel => categoryName.replaceAll('-', ' ');
}

class GameCategoriesService {
  GameCategoriesService._();
  static final GameCategoriesService instance = GameCategoriesService._();

  static const String _endpoint =
      'https://walletservice.bettbit.com/api/wallet/games/get-by-sequence';

  void _log(String msg) {
    if (kDebugMode) debugPrint('🧩 GameCategoriesService: $msg');
  }

  Future<List<GameCategoryItem>> fetchCategories() async {
    final uri = Uri.parse(_endpoint);

    final res = await http.get(uri, headers: {
      'accept': 'application/json, text/plain, */*',
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log('HTTP ${res.statusCode} ${res.body}');
      throw Exception('Failed to load categories');
    }

    final decoded = jsonDecode(res.body);
    final content = (decoded is Map && decoded['content'] is List)
        ? (decoded['content'] as List)
        : <dynamic>[];

    final items = content
        .whereType<Map<String, dynamic>>()
        .map(GameCategoryItem.fromJson)
        // ✅ only active
        .where((e) => e.status == 1 && e.categoryName.isNotEmpty)
        .toList();

    // ✅ sort by sequence
    items.sort((a, b) => a.sequence.compareTo(b.sequence));
    return items;
  }
}
