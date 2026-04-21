/// SpendSense — Digest Screen
/// Shown at 9 PM (and accessible from HomeScreen banner).
/// Shows all unconfirmed transactions from the day.
/// User swipes through each one and confirms categories quickly.
///
/// UX goal: all pending transactions resolved in under 30 seconds.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../state/app_state.dart';

class DigestScreen extends StatefulWidget {
  const DigestScreen({super.key});

  @override
  State<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends State<DigestScreen> {
  // Map of transactionId → selected category
  final Map<String, String> _selections = {};
  int _currentIndex = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadDigest();
    });
  }

  void _selectCategory(String txId, String category) {
    setState(() => _selections[txId] = category);
  }

  void _next() {
    final transactions = context.read<AppState>().pendingMyTransactions;
    if (_currentIndex < transactions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prev() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  Future<void> _confirmAll() async {
    final state = context.read<AppState>();
    final transactions = state.pendingMyTransactions;

    // Fill in any unselected transactions with 'Others'
    for (final tx in transactions) {
      _selections.putIfAbsent(tx.id, () => 'Others');
    }

    setState(() => _isSubmitting = true);
    await state.confirmAll(_selections);
    setState(() => _isSubmitting = false);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Evening digest'),
        centerTitle: false,
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final transactions = state.pendingMyTransactions;

          if (transactions.isEmpty) {
            return const _EmptyDigest();
          }

          return Column(
            children: [
              // ── Progress indicator ──────────────────────────────────────
              _ProgressBar(
                current: _currentIndex + 1,
                total: transactions.length,
              ),

              // ── Transaction card ────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DigestCard(
                    transaction: transactions[_currentIndex],
                    selectedCategory:
                        _selections[transactions[_currentIndex].id],
                    onCategoryTap: (cat) =>
                        _selectCategory(transactions[_currentIndex].id, cat),
                  ),
                ),
              ),

              // ── Navigation row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Back
                    if (_currentIndex > 0)
                      OutlinedButton(
                        onPressed: _prev,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Back'),
                      ),

                    const Spacer(),

                    // Next or Done
                    if (_currentIndex < transactions.length - 1)
                      FilledButton(
                        onPressed: _selections
                                .containsKey(transactions[_currentIndex].id)
                            ? _next
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                        ),
                        child: const Text('Next'),
                      )
                    else
                      FilledButton(
                        onPressed: _isSubmitting ? null : _confirmAll,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Done (${transactions.length})'),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transaction $current of $total',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              Text('${(current / total * 100).round()}% done',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual transaction card ───────────────────────────────────────────
class _DigestCard extends StatelessWidget {
  final MyTransaction transaction;
  final String? selectedCategory;
  final void Function(String) onCategoryTap;

  const _DigestCard({
    required this.transaction,
    required this.selectedCategory,
    required this.onCategoryTap,
  });

  static const Map<String, String> _emojis = {
    'Food': '🍕',
    'Transport': '🚗',
    'Shopping': '🛍',
    'Health': '💊',
    'Fun': '🎬',
    'Rent': '🏠',
    'EMI': '💳',
    'Others': '📦',
    'Loan': '💸',
  };

  Future<void> _showCustomCategoryDialog(
      BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter category name (e.g. Gym)',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await state.addCustomCategory(name);
      // Automatically select the new one
      final formattedName =
          name.trim()[0].toUpperCase() + name.trim().substring(1).toLowerCase();
      onCategoryTap(formattedName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final categories = [...state.allCategories, 'Loan'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount + merchant
              Text(
                '₹${transaction.amount.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(transaction.merchant,
                  style: TextStyle(fontSize: 18, color: Colors.grey[700])),
              const SizedBox(height: 4),
              Text(_formatTimestamp(transaction.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),

              const SizedBox(height: 28),
              const Text('What was this for?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),

              // Category chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...categories.map((cat) {
                    final selected = selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => onCategoryTap(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          '${_emojis[cat] ?? '🏷️'} $cat',
                          style: TextStyle(
                            fontSize: 13,
                            color: selected ? Colors.white : Colors.grey[800],
                            fontWeight:
                                selected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                  // Custom button
                  GestureDetector(
                    onTap: () => _showCustomCategoryDialog(context, state),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        '➕ Custom',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm · ${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────
class _EmptyDigest extends StatelessWidget {
  const _EmptyDigest();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
          const SizedBox(height: 16),
          const Text('All caught up!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('No pending transactions to review.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
