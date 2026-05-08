import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendsense/ui/screens/setup_screen.dart';

void main() {
  testWidgets('setup screen renders onboarding content', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: SetupScreen(isOnboarding: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SpendSense'), findsOneWidget);
    expect(find.text('AI Engine (Optional)'), findsOneWidget);
    expect(find.text('Google Sheets Sync (Optional)'), findsOneWidget);
    expect(find.text('Start tracking'), findsOneWidget);
  });
}
