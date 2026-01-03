// lib/components/vendors/hot_vendors.dart
import 'package:flutter/material.dart';
import 'vendor_games_section.dart';

class HotVendorsSection extends StatelessWidget {
  final String platform; // "TORROSPIN" / "MASCOT"
  const HotVendorsSection({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    return VendorGamesSection(
      category: 'HOT',
      platform: platform,
    );
  }
}
