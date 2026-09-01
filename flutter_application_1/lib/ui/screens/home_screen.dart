/// SpendSense - Home screen with Premium Redesign.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/recent_transactions_service.dart';
import '../../services/category_service.dart';
import '../../state/app_state.dart';
import '../../providers/classification_provider.dart';
import '../widgets/hero_section.dart';
import '../widgets/transaction_row.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AggregatedTransaction> _recent = [];
  MonthlySummary? _summary;
  List<double> _trendData = [0, 0, 0, 0, 0, 0, 0];
  Map<String, String> _categoryEmojis = {};
  bool _loading = true;
  bool _reloadInFlight = false;
  AppState? _appState;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAppState = context.read<AppState>();
    if (_appState == nextAppState) return;

    _appState?.removeListener(_handleAppStateChange);
    _appState = nextAppState;
    _appState?.addListener(_handleAppStateChange);
  }

  @override
  void dispose() {
    _appState?.removeListener(_handleAppStateChange);
    super.dispose();
  }

  void _handleAppStateChange() {
    _loadData(showSpinner: false);
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (_reloadInFlight) return;
    _reloadInFlight = true;

    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }

    try {
      final service = RecentTransactionsService.instance;
      final recent = await service.fetchAggregatedRecent();
      final summary = await service.fetchMonthlySummary();
      final trend = await service.fetchTrendData();
      final emojis =
          await CategoryService.instance.getAllCategoriesWithEmojis();

      // Initialize Classification Provider
      final rawTransactions = await service.fetchRecent(limit: 500);
      if (mounted) {
        await context.read<ClassificationProvider>().init(rawTransactions);
      }

      if (mounted) {
        setState(() {
          _recent = recent;
          _summary = summary;
          _trendData = trend;
          _categoryEmojis = emojis;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('SpendSense Error: Failed to load home data: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load transactions. Please restart.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      _reloadInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            return RefreshIndicator(
              onRefresh: _loadData,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // App Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SpendSense',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              // AI Active indicator
                              Row(
                                children: [
                                  _StatusIndicator(state: state),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.settings_outlined),
                                    color: const Color(0xFF6B7280),
                                    onPressed: () => Navigator.pushNamed(
                                        context, '/setup-settings'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    // Hero Section
                                    if (_summary != null)
                                      HeroSection(
                                        totalSpending: _summary!.totalSpent,
                                        budget: 15000, // Placeholder budget
                                        transactionCount: _summary!.txCount,
                                        topCategory: _summary!.topCategory,
                                        trendData: _trendData,
                                      ),
                                    // Recent Header
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 24, 20, 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Recent',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              // Navigate to all history
                                            },
                                            child: const Text(
                                              'See all',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_recent.isEmpty)
                                const SliverToBoxAdapter(child: _EmptyState())
                              else
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final tx = _recent[index];
                                      return TransactionRow(
                                        category: tx.category,
                                        emoji: _categoryEmojis[tx.category] ??
                                            '🏷️',
                                        timestamp:
                                            _shortTime(tx.lastTransactionAt),
                                        amount: tx.totalAmount,
                                        isSynced: true, // Placeholder
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/category-details',
                                          arguments: tx.category,
                                        ),
                                      );
                                    },
                                    childCount: _recent.length,
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 100)),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/digest');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/insights');
          } else {
            setState(() => _currentNavIndex = index);
          }
        },
        reviewBadgeCount:
            context.watch<AppState>().pendingMyTransactions.length,
        onAddPressed: () {
          // Open manual entry sheet
        },
      ),
    );
  }

  String _shortTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour == 0
            ? 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return 'Last spend: $hour:$minute $suffix';
  }
}

class _StatusIndicator extends StatelessWidget {
  final AppState state;

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    final isProcessing = state.txState == TxState.processing;
    final hasPermissionIssue = !state.isSmsReady;

    Color color;
    String label;

    if (hasPermissionIssue) {
      color = Colors.red;
      label = 'Issue';
    } else if (isProcessing) {
      color = Colors.orange;
      label = 'Processing';
    } else {
      color = const Color(0xFF10B981);
      label = 'AI Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            'Make a UPI payment and it will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
