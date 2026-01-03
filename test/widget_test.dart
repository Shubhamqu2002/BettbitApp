import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:demo_gamer/main.dart'; // ✅ make sure this path is correct

void main() {
  testWidgets('App launches and shows splash screen',
      (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const IGamingApp());

    // Splash screen icon should be visible
    expect(find.byIcon(Icons.sports_esports_rounded), findsOneWidget);

    // Move time forward (simulate splash delay)
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Login screen text appears
    expect(find.text('Welcome Back 👋'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
