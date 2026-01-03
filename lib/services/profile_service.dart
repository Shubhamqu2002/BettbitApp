// lib/services/profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../util/crypto_utils.dart';

/// Model representing the gamer's profile
class GamerProfile {
  final String gamerId;
  final String userName;
  final String fullName;
  final String email;       // decrypted
  final String phoneNumber; // decrypted
  final String dateOfBirth; // raw "yyyy-MM-dd"
  final String gender;
  final String country;
  final String currency;
  final double totalBalance;
  final double cashBalance;
  final double promoBalance;
  final DateTime profileCreatedDate;
  final DateTime? lastTransactionDate;

  GamerProfile({
    required this.gamerId,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.country,
    required this.currency,
    required this.totalBalance,
    required this.cashBalance,
    required this.promoBalance,
    required this.profileCreatedDate,
    this.lastTransactionDate,
  });
}

/// Service responsible for fetching the gamer's profile from the wallet API
class ProfileService {
  // ✅ Base URL from .env
  static final String _baseUrl =
      dotenv.env['WALLET_BASE_URL'] ??
      (throw Exception('WALLET_BASE_URL not found in .env'));

  /// Fetch profile by gamerId (stored in SharedPreferences)
  ///
  /// Example endpoint:
  ///   GET /wallet/profile/{gamerId}
  ///
  /// Also decrypts [email] and [phoneNumber] fields using [decryptText].
  Future<GamerProfile> fetchProfile(String gamerId) async {
    final uri = Uri.parse('$_baseUrl/wallet/profile/$gamerId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load profile (HTTP ${response.statusCode})');
    }

    final Map<String, dynamic> data = json.decode(response.body);

    final decryptedEmail = decryptText(data['email'] ?? '') ?? '';
    final decryptedPhone = decryptText(data['phoneNumber'] ?? '') ?? '';

    return GamerProfile(
      gamerId: data['gamerId'] ?? '',
      userName: data['userName'] ?? '',
      fullName: data['fullName'] ?? '',
      email: decryptedEmail,
      phoneNumber: decryptedPhone,
      dateOfBirth: data['dateOfBirth'] ?? '',
      gender: data['gender'] ?? '',
      country: data['country'] ?? '',
      currency: data['currency'] ?? '',
      totalBalance: (data['totalBalance'] as num?)?.toDouble() ?? 0.0,
      cashBalance: (data['cashBalance'] as num?)?.toDouble() ?? 0.0,
      promoBalance: (data['promoBalance'] as num?)?.toDouble() ?? 0.0,
      profileCreatedDate: DateTime.tryParse(
            data['profileCreatedDate'] ?? '',
          ) ??
          DateTime.now(),
      lastTransactionDate: DateTime.tryParse(
        data['lastTransactionDate'] ?? '',
      ),
    );
  }
}
