/// SpendSense - Home screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/recent_transactions_service.dart';
import '../../state/app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AggregatedTransaction> _recent = [];
  MonthlySummary? _summary;
  bool _loading = true;
  bool _reloadInFlight = false;
  AppState? _appState;

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

      if (mounted) {
        setState(() {
          _recent = recent;
          _summary = summary;
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: const Text(
          'SpendSense',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/setup-settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return RefreshIndicator(
            onRefresh: _loadData,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StatusPill(state: state),
                              const SizedBox(height: 16),
                              if (_summary != null)
                                _MonthlySummaryRow(summary: _summary!),
                              const SizedBox(height: 16),
                              if (state.pendingMyTransactions.isNotEmpty)
                                _PendingBanner(
                                    count: state.pendingMyTransactions.length),
                              const SizedBox(height: 20),
                              Text(
                                'Recent',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      if (_recent.isEmpty)
                        const SliverToBoxAdapter(child: _EmptyState())
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 3,
                              ),
                              child:
                                  _AggregatedTransactionRow(tx: _recent[index]),
                            ),
                            childCount: _recent.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final AppState state;

  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final isProcessing = state.txState == TxState.processing;
    final hasPermissionIssue = !state.isSmsReady;
    Color color;
    String label;

    if (hasPermissionIssue) {
      color = Colors.red;
      label = 'SMS permission required';
    } else if (isProcessing) {
      color = Colors.orange;
      label = 'Processing transaction...';
    } else {
      color = Colors.green;
      label = 'Listening in background';
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}

class _MonthlySummaryRow extends StatelessWidget {
  final MonthlySummary summary;

  const _MonthlySummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final monthName = _monthName(summary.month.month);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: '$monthName spending',
            value: summary.formattedTotal,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Transactions',
            value: '${summary.txCount}',
            color: Colors.green[700]!,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Top category',
            value: summary.topCategory,
            color: Colors.orange[700]!,
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month];
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;

  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/digest'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.pending_actions_outlined,
              color: Color(0xFF2563EB),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count ${count == 1 ? "transaction needs" : "transactions need"} categorisation',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Color(0xFF2563EB),
            ),
          ],
        ),
      ),
    );
  }
}

class _AggregatedTransactionRow extends StatelessWidget {
  final AggregatedTransaction tx;

  const _AggregatedTransactionRow({required this.tx});

  static const Map<String, String> _emojis = {
    'Food': '🍕',
    'Transport': '🚗',
    'Shopping': '🛍',
    'Health': '💊',
    'Fun': '🎬',
    'Rent': '🏠',
    'EMI': '💳',
    'Loan': '💸',
    'Others': '📦',
  };

  static const Map<String, Color> _categoryColors = {
    'Food': Color(0xFFFEF3C7),
    'Transport': Color(0xFFDCFCE7),
    'Shopping': Color(0xFFF3E8FF),
    'Health': Color(0xFFFFE4E6),
    'Fun': Color(0xFFE0F2FE),
    'Rent': Color(0xFFFFF7ED),
    'EMI': Color(0xFFF0FDF4),
    'Loan': Color(0xFFFFF1F2),
    'Others': Color(0xFFF9FAFB),
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _emojis[tx.category] ?? '🏷️';
    final background = _categoryColors[tx.category] ?? const Color(0xFFF9FAFB);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.category,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 1),
                Text(
                  'Last spend: ${_shortTime(tx.lastTransactionAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          Text(
            '₹${tx.totalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
        ],
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
    return '$hour:$minute $suffix';
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
