/// SpendSense — Main Entry Point (complete)
/// Handles:
///   - First-launch onboarding check
///   - Global navigator key for notification tap routing
///   - All route declarations
///   - App state initialisation
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/transaction.dart';
import 'state/app_state.dart';
import 'models/user_goals.dart';
import 'providers/goals_provider.dart';
import 'providers/insights_provider.dart';
import 'repositories/goals_repository.dart';
import 'services/insights/insights_service.dart';
import 'services/local_storage_service.dart';

import 'ui/screens/home_screen.dart';
import 'ui/screens/insights.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/popup_screen.dart';
import 'ui/screens/digest_screen.dart';
import 'ui/screens/developer_tools_screen.dart';
import 'ui/screens/category_transactions_screen.dart';
import 'ui/screens/category_management_screen.dart';
import 'ui/screens/goals_settings_screen.dart';

import 'providers/classification_provider.dart';
import 'repositories/classification_repository.dart';
import 'services/insights/classification_detector.dart';

// ── Global navigator key ──────────────────────────────────────────────────
// Allows NotificationService to navigate without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpendSenseApp());
}

class SpendSenseApp extends StatelessWidget {
  const SpendSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState()..initialise(),
        ),
        ChangeNotifierProvider(
          create: (_) => GoalsProvider(
            GoalsRepository(LocalStorageService.instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ClassificationProvider(
            ClassificationRepository(LocalStorageService.instance),
            ClassificationDetector(),
          ),
        ),
        ChangeNotifierProxyProvider2<GoalsProvider, ClassificationProvider,
            InsightsProvider>(
          create: (_) => InsightsProvider(InsightsService(), UserGoals.empty()),
          update: (_, goalsProvider, classificationsProvider, previous) =>
              previous!
                ..onContextUpdated(
                    goalsProvider.currentGoals, classificationsProvider),
        ),
      ],
      child: MaterialApp(
        title: 'SpendSense',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
          inputDecorationTheme: const InputDecorationTheme(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        initialRoute: '/home',
        routes: {
          '/home': (_) => const HomeScreen(),
          '/setup': (_) => const SetupScreen(isOnboarding: true),
          '/digest': (_) => const DigestScreen(),
          '/insights': (_) => const InsightsScreen(),
          '/debug': (_) => const DeveloperToolsScreen(),
          '/manage-categories': (_) => const CategoryManagementScreen(),
          '/goals-settings': (_) => const GoalsSettingsScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/popup':
              final tx = settings.arguments as MyTransaction;
              return MaterialPageRoute(
                  builder: (_) => PopupScreen(myTransaction: tx));
            case '/setup-settings':
              return MaterialPageRoute(
                  builder: (_) => const SetupScreen(isOnboarding: false));
            case '/category-details':
              final category = settings.arguments as String;
              return MaterialPageRoute(
                  builder: (_) =>
                      CategoryTransactionsScreen(category: category));
          }
          return null;
        },
      ),
    );
  }
}
