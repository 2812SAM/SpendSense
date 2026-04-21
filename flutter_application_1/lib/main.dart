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

import 'ui/screens/home_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/popup_screen.dart';
import 'ui/screens/digest_screen.dart';
import 'ui/screens/developer_tools_screen.dart';

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
    return ChangeNotifierProvider(
      create: (_) => AppState()..initialise(),
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
          '/debug': (_) => const DeveloperToolsScreen(),
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
          }
          return null;
        },
      ),
    );
  }
}
