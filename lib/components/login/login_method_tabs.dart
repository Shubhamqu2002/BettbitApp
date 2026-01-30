// lib/components/login/login_method_tabs.dart
import 'package:flutter/material.dart';

class LoginMethodTabs extends StatelessWidget {
  final TabController controller;

  const LoginMethodTabs({super.key, required this.controller});

  static const Color _c1 = Color(0xFF00E5FF);
  static const Color _c2 = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _c1.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _c2.withOpacity(0.12),
            blurRadius: 30,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _c1.withOpacity(0.90),
              _c2.withOpacity(0.75),
            ],
            stops: const [0.0, 1.0],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _c1.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: _c2.withOpacity(0.28),
              blurRadius: 25,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.65),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          letterSpacing: 0.5,
        ),
        tabs: const [
          Tab(
            height: 48,
            icon: Icon(Icons.alternate_email_rounded, size: 19),
            iconMargin: EdgeInsets.only(bottom: 4),
            text: 'Email',
          ),
          Tab(
            height: 48,
            icon: Icon(Icons.sim_card_download_rounded, size: 19),
            iconMargin: EdgeInsets.only(bottom: 4),
            text: 'Phone',
          ),
        ],
      ),
    );
  }
}