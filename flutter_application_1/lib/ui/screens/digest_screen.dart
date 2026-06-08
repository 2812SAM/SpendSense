/// SpendSense — Digest Screen (Premium Redesign)
/// Shown at 9 PM (and accessible from HomeScreen banner).
/// Shows all unconfirmed transactions from the day.
/// User swipes through each one and confirms categories quickly.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../services/category_service.dart';
import '../../core/constants.dart';
import '../widgets/custom_category_dialog.dart';

class DigestScreen extends StatefulWidget {
  const DigestScreen({super.key});

  @override
  State<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends State<DigestScreen> {
  // Map of transactionId → selected category
  final Map<String, String> _selections = {};
  // Map of transactionId → isDynamic (Should we NOT remember this?)
  final Map<String, bool> _dynamicMap = {};
  // Track how many were confirmed in this session for the progress bar
  int _sessionConfirmedCount = 0;

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
    setState(() {
      if (_selections[txId] == category) {
        _selections.remove(txId);
      } else {
        _selections[txId] = category;
        // Default to "Do NOT Remember" (isDynamic: true) when a category is picked
        _dynamicMap.putIfAbsent(txId, () => true);
      }
    });
  }

  void _toggleRemember(String txId) {
    setState(() {
      _dynamicMap[txId] = !(_dynamicMap[txId] ?? true);
    });
  }

  Future<void> _ignore(String txId) async {
    final transactions = context.read<AppState>().pendingMyTransactions;
    final tx = transactions.firstWhere((t) => t.id == txId);

    setState(() => _isSubmitting = true);
    final state = context.read<AppState>();
    await state.confirmCategory(tx, AppConstants.categoryIgnored);
    setState(() => _isSubmitting = false);

    if (transactions.length <= 1) {
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _sessionConfirmedCount++;
        if (_currentIndex >= transactions.length - 1) {
          _currentIndex = transactions.length - 2;
        }
      });
    }
  }

  void _next() {
    final transactions = context.read<AppState>().pendingMyTransactions;
    if (_currentIndex < transactions.length - 1) {
      setState(() {
        _sessionConfirmedCount++;
        _currentIndex++;
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        if (_sessionConfirmedCount > 0) _sessionConfirmedCount--;
      });
    }
  }

  Future<void> _confirmAll() async {
    final state = context.read<AppState>();
    final transactions = state.pendingMyTransactions;

    // Fill in any unselected transactions with 'Others'
    for (final tx in transactions) {
      _selections.putIfAbsent(tx.id, () => 'Others');
      _dynamicMap.putIfAbsent(tx.id, () => true);
    }

    setState(() => _isSubmitting = true);
    await state.confirmAll(_selections, dynamicMap: _dynamicMap);
    setState(() => _isSubmitting = false);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveAndExit() async {
    if (_selections.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSubmitting = true);
    final state = context.read<AppState>();
    await state.confirmAll(_selections, dynamicMap: _dynamicMap);
    setState(() => _isSubmitting = false);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Evening digest',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _saveAndExit,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final transactions = state.pendingMyTransactions;

          if (transactions.isEmpty) {
            return const _EmptyDigest();
          }

          final currentTx = transactions[_currentIndex];

          return Column(
            children: [
              _ProgressBar(
                current: _currentIndex + 1,
                total: transactions.length,
                completedCount: _sessionConfirmedCount,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: _DigestCard(
                    transaction: currentTx,
                    selectedCategory: _selections[currentTx.id],
                    isDynamic: _dynamicMap[currentTx.id] ?? true,
                    onCategoryTap: (cat) => _selectCategory(currentTx.id, cat),
                    onRememberToggle: () => _toggleRemember(currentTx.id),
                    onVoiceConfirmed: (confirmed) {
                      if (confirmed) {
                        setState(() => _sessionConfirmedCount++);
                      }
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_currentIndex > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _prev,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Back',
                                style: TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (_currentIndex > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _currentIndex < transactions.length - 1
                                ? (_selections.containsKey(currentTx.id)
                                    ? _next
                                    : null)
                                : (_isSubmitting ? null : _confirmAll),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _currentIndex < transactions.length - 1
                                        ? 'Next'
                                        : 'Finish Review',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed:
                            _isSubmitting ? null : () => _ignore(currentTx.id),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9CA3AF),
                        ),
                        child: const Text('Ignore this transaction'),
                      ),
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

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final int completedCount;
  const _ProgressBar({
    required this.current,
    required this.total,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviewing $current of $total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                '${(completedCount / total * 100).round()}% completed',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completedCount / total,
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigestCard extends StatefulWidget {
  final MyTransaction transaction;
  final String? selectedCategory;
  final bool isDynamic;
  final void Function(String) onCategoryTap;
  final VoidCallback onRememberToggle;
  final void Function(bool) onVoiceConfirmed;

  const _DigestCard({
    required this.transaction,
    required this.selectedCategory,
    required this.isDynamic,
    required this.onCategoryTap,
    required this.onRememberToggle,
    required this.onVoiceConfirmed,
  });

  @override
  State<_DigestCard> createState() => _DigestCardState();
}

class _DigestCardState extends State<_DigestCard> {
  Map<String, String> _emojis = {};

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    final emojis = await CategoryService.instance.getAllCategoriesWithEmojis();
    if (mounted) setState(() => _emojis = emojis);
  }

  Future<void> _showCustomCategoryDialog(
      BuildContext context, AppState state) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CustomCategoryDialog(),
    );

    if (result != null) {
      final name = result['name']!;
      final desc = result['desc'] ?? '';
      await state.addCustomCategory(name, description: desc);
      final formattedName =
          name.trim()[0].toUpperCase() + name.trim().substring(1).toLowerCase();
      widget.onCategoryTap(formattedName);
      await _loadEmojis();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final categories = [...state.allCategories, 'Loan'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transaction Details Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
                ),
                child: Column(
                  children: [
                    Text(
                      '₹${widget.transaction.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.transaction.merchant,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(widget.transaction.timestamp),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Category Selection
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECT CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: [
                        ...categories.map((cat) {
                          final isSelected = widget.selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => widget.onCategoryTap(cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _emojis[cat] ?? '🏷️',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () =>
                              _showCustomCategoryDialog(context, state),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD1D5DB),
                                width: 1,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 18, color: Color(0xFF4F46E5)),
                                SizedBox(width: 6),
                                Text(
                                  'Custom',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Remember Selection
                    if (widget.selectedCategory != null)
                      GestureDetector(
                        onTap: widget.onRememberToggle,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: !widget.isDynamic
                                ? const Color(0xFFEEF2FF)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !widget.isDynamic
                                  ? const Color(0xFFC7D2FE)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                !widget.isDynamic
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: !widget.isDynamic
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-categorize in future',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    Text(
                                      'Apply this to all future payments here',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Voice Action
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.isVoiceListening
                            ? null
                            : () async {
                                final confirmed = await state
                                    .confirmWithVoice(widget.transaction);
                                widget.onVoiceConfirmed(confirmed);
                              },
                        icon: Icon(
                            state.isVoiceListening ? Icons.mic : Icons.mic_none,
                            size: 20),
                        label: Text(state.isVoiceListening
                            ? 'Listening...'
                            : 'Describe with voice'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final months = [
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
      'Dec'
    ];
    return '$hour:$minute $ampm · ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _EmptyDigest extends StatelessWidget {
  const _EmptyDigest();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1FAE5), width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 64, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No pending transactions to review.\nYou\'re a financial superstar!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go Home'),
            ),
          ),
        ],
      ),
    );
  }
}
