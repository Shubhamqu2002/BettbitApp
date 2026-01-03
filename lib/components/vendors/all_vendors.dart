// lib/components/vendors/all_vendors.dart
import 'package:flutter/material.dart';
import 'vendor_games_section.dart';

class AllVendorsSection extends StatelessWidget {
  final String platform; // "TORROSPIN" / "MASCOT"
  const AllVendorsSection({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    return VendorGamesSection(
      category: 'ALL',
      platform: platform,
    );
  }
}
