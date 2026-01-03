// lib/components/vendors/slot_vendors.dart
import 'package:flutter/material.dart';
import 'vendor_games_section.dart';

class SlotVendorsSection extends StatelessWidget {
  final String platform; // "TORROSPIN" / "MASCOT"
  const SlotVendorsSection({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    return VendorGamesSection(
      category: 'SLOT',
      platform: platform,
    );
  }
}
