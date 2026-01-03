// lib/components/register/register_method_tabs.dart
import 'package:flutter/material.dart';

class RegisterMethodTabs extends StatelessWidget {
  final TabController controller;

  const RegisterMethodTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00C9A7).withOpacity(0.85),
              Colors.white.withOpacity(0.14),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        tabs: const [
          Tab(icon: Icon(Icons.email_outlined, size: 18), text: 'Email'),
          Tab(icon: Icon(Icons.phone_iphone_rounded, size: 18), text: 'Phone'),
        ],
      ),
    );
  }
}
