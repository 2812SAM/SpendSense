import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spendsense/main.dart' as app;
import 'package:spendsense/core/constants.dart';
import 'package:spendsense/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Journey - Golden Path', () {
    testWidgets('SMS arrives, gets locally parsed, and shows on Home Screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Access AppState
      final context = tester.element(find.byType(MaterialApp));
      final appState = context.read<AppState>();

      // Wait for initialization to settle (permissions etc)
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      const sms = 'Alert: You\'ve spent Rs. 150.00 at Starbucks on 2026-04-25. Ref: TXN1';
      const sender = 'AD-HDFCBK';

      // Simulate SMS
      await appState.onPaymentSmsReceived(sms, sender);
      
      // Wait for the waterfall and sync to finish (reaching 'logged' or 'error' state)
      int retry = 0;
      while (appState.txState != TxState.logged && appState.txState != TxState.error && retry < 10) {
        await tester.pump(const Duration(milliseconds: 200));
        retry++;
      }
      
      await tester.pumpAndSettle();

      // Verify it appeared in the list
      expect(find.text('Starbucks'), findsOneWidget);
      expect(find.textContaining('150'), findsOneWidget);
    });

    testWidgets('Unknown SMS triggers popup and manual categorization', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      final appState = context.read<AppState>();

      // Wait for initialization
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      const sms = 'Payment of Rs. 49 received at Store X. Happy Shopping! Ref: TXN2';
      const sender = 'UNKNOWN';

      // Simulate Unknown SMS
      await appState.onPaymentSmsReceived(sms, sender);
      
      // Wait for navigation to Popup
      int retry = 0;
      while (appState.txState != TxState.awaitingUser && retry < 10) {
        await tester.pump(const Duration(milliseconds: 200));
        retry++;
      }
      await tester.pumpAndSettle();

      // Verify the Popup screen appeared
      expect(find.text('What was this for?'), findsOneWidget);
      expect(find.text('Store X'), findsOneWidget);

      // Select a category
      await tester.tap(find.text('🍕 Food'));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Wait for return to Home and list update
      retry = 0;
      while (appState.txState != TxState.logged && appState.txState != TxState.error && retry < 10) {
        await tester.pump(const Duration(milliseconds: 200));
        retry++;
      }
      await tester.pumpAndSettle();

      expect(find.text('Store X'), findsOneWidget);
    });
  });
}
