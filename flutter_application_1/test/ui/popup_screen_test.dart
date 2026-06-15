import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/state/app_state.dart';
import 'package:spendsense/ui/screens/popup_screen.dart';

import 'package:spendsense/providers/classification_provider.dart';
import 'package:spendsense/models/expense_classification.dart';

class MockAppState extends Mock implements AppState {}

class MockClassificationProvider extends Mock
    implements ClassificationProvider {}

void main() {
  late MockAppState mockAppState;
  late MockClassificationProvider mockCP;

  setUp(() {
    mockAppState = MockAppState();
    mockCP = MockClassificationProvider();

    // Default stubs
    when(() => mockAppState.allCategories)
        .thenReturn(['Food', 'Transport', 'Shopping', 'Others']);
    when(() => mockAppState.isVoiceListening).thenReturn(false);

    // Stub natureOf for classification provider
    when(() => mockCP.natureOf(any(), any()))
        .thenReturn(ExpenseNature.sometime);
  });

  Widget createTestableWidget(MyTransaction tx) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: mockAppState),
        ChangeNotifierProvider<ClassificationProvider>.value(value: mockCP),
      ],
      child: MaterialApp(
        home: PopupScreen(myTransaction: tx),
      ),
    );
  }

  group('PopupScreen - Redesigned UI', () {
    testWidgets('should show auto-categorize option for real merchants',
        (WidgetTester tester) async {
      final tx = MyTransaction(
        id: '1',
        timestamp: DateTime.now(),
        amount: 100,
        merchant: 'Starbucks',
        category: 'ASK_USER',
        confidence: 'LOW',
        type: 'EXPENSE',
        note: '',
        rawSms: 'Spent 100 at Starbucks',
      );

      await tester.pumpWidget(createTestableWidget(tx));
      await tester.pumpAndSettle();

      // Initially category is null
      // Let's select a category first.
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.text('Auto-categorize in future'), findsOneWidget);
      expect(
          find.text('Apply this to all future payments here'), findsOneWidget);

      // Verify it's NOT checked by default in new UI logic
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });

    testWidgets('should allow toggling auto-categorize',
        (WidgetTester tester) async {
      final tx = MyTransaction(
        id: '2',
        timestamp: DateTime.now(),
        amount: 500,
        merchant: 'AX-SBIUPI',
        category: 'ASK_USER',
        confidence: 'LOW',
        type: 'EXPENSE',
        note: '',
        rawSms: 'Sent 500 from AX-SBIUPI',
      );

      await tester.pumpWidget(createTestableWidget(tx));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      // Should be unchecked
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

      // Toggle it ON
      await tester.tap(find.text('Auto-categorize in future'));
      await tester.pumpAndSettle();

      // Should be checked
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
