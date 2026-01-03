// lib/services/banner_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BannerService {
  // ✅ Banner API base from .env
  static final String _apiBase =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  // actual image base (static, CDN-like)
  static const String bannerBaseUrl =
      'https://staging.nexxorra.com/assets/banner/';

  Future<List<String>> fetchBanners() async {
    final url = Uri.parse('$_apiBase/api/wallet/games/readfile/banner');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      return files;
    } else {
      throw Exception(
          'Failed to load banners (${response.statusCode}): ${response.body}');
    }
  }
}
