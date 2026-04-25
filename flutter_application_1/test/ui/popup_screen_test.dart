import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:spendsense/models/transaction.dart';
import 'package:spendsense/state/app_state.dart';
import 'package:spendsense/ui/screens/popup_screen.dart';

class MockAppState extends Mock implements AppState {}

void main() {
  late MockAppState mockAppState;

  setUp(() {
    mockAppState = MockAppState();
    // Default stubs
    when(() => mockAppState.allCategories).thenReturn(['Food', 'Transport', 'Shopping', 'Others']);
    when(() => mockAppState.isVoiceListening).thenReturn(false);
  });

  Widget createTestableWidget(MyTransaction tx) {
    return ChangeNotifierProvider<AppState>.value(
      value: mockAppState,
      child: MaterialApp(
        home: PopupScreen(myTransaction: tx),
      ),
    );
  }

  group('PopupScreen - Learning Card', () {
    testWidgets('should show standard Memory card for real merchants', (WidgetTester tester) async {
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

      // Initially category is null, so card might not be visible depending on implementation.
      // Let's select a category first.
      await tester.tap(find.text('🍕 Food'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Memory: Active'), findsOneWidget);
      expect(find.textContaining('automatically categorize it as "Food"'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
      
      // Verify switch is ON by default for real merchants
      final Switch memorySwitch = tester.widget(find.byType(Switch));
      expect(memorySwitch.value, isTrue);
    });

    testWidgets('should show Warning card for generic bank IDs', (WidgetTester tester) async {
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

      await tester.tap(find.text('🍕 Food'));
      await tester.pumpAndSettle();

      // Verify switch is OFF by default for generic IDs
      Switch memorySwitch = tester.widget(find.byType(Switch));
      expect(memorySwitch.value, isFalse);

      // Warning should NOT be visible yet because memory is OFF
      expect(find.textContaining('Generic bank ID detected'), findsNothing);
      expect(find.textContaining('This is a one-time categorization'), findsOneWidget);

      // Now toggle it ON
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Now the warning SHOULD be visible
      expect(find.textContaining('Generic bank ID detected'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      
      memorySwitch = tester.widget(find.byType(Switch));
      expect(memorySwitch.value, isTrue);
    });
  });
}
