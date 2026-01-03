// lib/components/vendors/casino_vendors.dart
import 'package:flutter/material.dart';
import 'vendor_games_section.dart';

class CasinoVendorsSection extends StatelessWidget {
  final String platform; // "TORROSPIN" / "MASCOT"
  const CasinoVendorsSection({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    return VendorGamesSection(
      category: 'CASINO',
      platform: platform,
    );
  }
}
