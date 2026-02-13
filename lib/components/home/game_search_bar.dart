// lib/components/home/game_search_bar.dart
import 'package:flutter/material.dart';

class GameSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String hintText;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;

  const GameSearchBar({
    super.key,
    required this.controller,
    required this.isLoading,
    this.hintText = "Search games...",
    this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: Colors.white.withOpacity(0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: Colors.white.withOpacity(0.85),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.75),
                ),
              ),
            ),
          ] else if (controller.text.trim().isNotEmpty) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
