import 'package:flutter/material.dart';

class DepositTheme {
  static const c1 = Color(0xFF21C8F6);
  static const c2 = Color(0xFF4C1D95);
  static const c3 = Color(0xFF9B5CFF);

  static const success = Color(0xFF22C55E);
  static const warn = Color(0xFFFF8A00);

  static LinearGradient bgGradient() => const LinearGradient(
        colors: [c1, c3, c2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient cardGradient() => LinearGradient(
        colors: [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static BoxDecoration glassCard() => BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: cardGradient(),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: c2.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      );
}
