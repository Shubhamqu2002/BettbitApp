import 'dart:convert';
import 'package:http/http.dart' as http;

class BrandInfo {
  final String brandName;
  final String brandEmail;
  final String mobileNumber;
  final String description;
  final String brandAddress;
  final String telegramId;
  final List<String> files;

  BrandInfo({
    required this.brandName,
    required this.brandEmail,
    required this.mobileNumber,
    required this.description,
    required this.brandAddress,
    required this.telegramId,
    required this.files,
  });

  factory BrandInfo.fromJson(Map<String, dynamic> json) {
    return BrandInfo(
      brandName: (json['brandName'] ?? '').toString(),
      brandEmail: (json['brandEmail'] ?? '').toString(),
      mobileNumber: (json['mobileNumber'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      brandAddress: (json['brandAddress'] ?? '').toString(),
      telegramId: (json['telegramId'] ?? '').toString(),
      files: (json['files'] is List)
          ? (json['files'] as List).map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}

class BrandService {
  static const String _apiUrl =
      'https://walletservice.bettbit.com/api/wallet/games/readfile/logo';

  // Your required base URL format:
  // https://bettbit.com/assets/logo/<FILE_NAME>
  static const String _logoBaseUrl = 'https://bettbit.com/assets/logo/';

  Future<BrandInfo> fetchBrandInfo() async {
    final res = await http.get(Uri.parse(_apiUrl));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to fetch brand info. Status: ${res.statusCode}');
    }

    final decoded = json.decode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid brand info response');
    }

    return BrandInfo.fromJson(decoded);
  }

  /// Returns full logo url using first file from API
  /// e.g. https://bettbit.com/assets/logo/BETTBIT_LOGO.svg
  Future<String?> fetchLogoUrl() async {
    final info = await fetchBrandInfo();
    if (info.files.isEmpty) return null;

    final fileName = info.files.first.trim();
    if (fileName.isEmpty) return null;

    return '$_logoBaseUrl$fileName';
  }
}
