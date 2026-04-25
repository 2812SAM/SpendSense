/// SpendSense - Popup screen for low-confidence transactions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/transaction.dart';
import '../../state/app_state.dart';

class PopupScreen extends StatefulWidget {
  final MyTransaction myTransaction;

  const PopupScreen({super.key, required this.myTransaction});

  @override
  State<PopupScreen> createState() => _PopupScreenState();
}

class _PopupScreenState extends State<PopupScreen> {
  String? _selectedCategory;
  bool _rememberCategory = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing category if it's not ASK_USER
    if (widget.myTransaction.category != 'ASK_USER') {
      _selectedCategory = widget.myTransaction.category;
    }

    // Smart default: If the merchant is a generic bank ID, don't auto-check "Remember"
    if (AppConstants.isGenericId(widget.myTransaction.merchant)) {
      _rememberCategory = false;
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Future<void> _confirm() async {
    if (_selectedCategory == null) return;

    final state = context.read<AppState>();
    await state.confirmCategory(
      widget.myTransaction,
      _selectedCategory!,
      isDynamic: !_rememberCategory,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(myTransaction: widget.myTransaction),
                      const SizedBox(height: 32),
                      const Text(
                        'What was this for?',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      _CategoryGrid(
                        myTransaction: widget.myTransaction,
                        selectedCategory: _selectedCategory,
                        onSelected: _onCategorySelected,
                      ),
                      const SizedBox(height: 24),

                      // ── Learning Card (High Visibility) ──────────────────────────────
                      if (_selectedCategory != null) ...[
                        _LearningCard(
                          merchant: widget.myTransaction.merchant,
                          category: _selectedCategory!,
                          value: _rememberCategory,
                          isGeneric: AppConstants.isGenericId(
                              widget.myTransaction.merchant),
                          onChanged: (val) =>
                              setState(() => _rememberCategory = val),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _VoiceButton(myTransaction: widget.myTransaction),
                    ],
                  ),
                ),
              ),

              // ── Action Buttons ──────────────────────────────────────────
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Remind me tonight'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _selectedCategory == null ? null : _confirm,
                      child: const Text('Confirm'),
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
}

class _Header extends StatelessWidget {
  final MyTransaction myTransaction;

  const _Header({required this.myTransaction});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '₹${myTransaction.amount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          myTransaction.merchant,
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(myTransaction.timestamp),
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour == 0
            ? 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix · ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _LearningCard extends StatelessWidget {
  final String merchant;
  final String category;
  final bool value;
  final bool isGeneric;
  final ValueChanged<bool> onChanged;

  const _LearningCard({
    required this.merchant,
    required this.category,
    required this.value,
    required this.isGeneric,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? (isGeneric
                ? Colors.orange[50]
                : theme.colorScheme.primaryContainer.withValues(alpha: 0.3))
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? (isGeneric
                  ? Colors.orange[300]!
                  : theme.colorScheme.primary.withValues(alpha: 0.5))
              : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGeneric
                    ? Icons.warning_amber_rounded
                    : Icons.psychology_rounded,
                color: value
                    ? (isGeneric
                        ? Colors.orange[700]
                        : theme.colorScheme.primary)
                    : Colors.grey[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ? 'Memory: Active' : 'Memory: Disabled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: value
                        ? (isGeneric
                            ? Colors.orange[900]
                            : theme.colorScheme.primary)
                        : Colors.grey[700],
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor:
                    isGeneric ? Colors.orange[700] : theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value
                ? 'Next time SpendSense sees "$merchant", it will automatically categorize it as "$category".'
                : 'This is a one-time categorization. SpendSense will ask you again next time.',
            style: TextStyle(
              fontSize: 13,
              color: value
                  ? (isGeneric ? Colors.orange[900] : Colors.black87)
                  : Colors.grey[600],
              height: 1.4,
            ),
          ),
          if (value && isGeneric) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Generic bank ID detected. Remembering this might affect unrelated future payments.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final MyTransaction myTransaction;
  final String? selectedCategory;
  final Function(String) onSelected;

  const _CategoryGrid({
    required this.myTransaction,
    required this.selectedCategory,
    required this.onSelected,
  });

  static const Map<String, String> _categoryEmoji = {
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
      final formattedName =
          name.trim()[0].toUpperCase() + name.trim().substring(1).toLowerCase();
      onSelected(formattedName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final categories = [...state.allCategories, 'Loan'];

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            ...categories.map((category) {
              final selected = selectedCategory == category;
              return _CategoryChip(
                label: category,
                emoji: _categoryEmoji[category] ?? '🏷️',
                selected: selected,
                onTap: () => onSelected(category),
              );
            }),
            _CategoryChip(
              label: 'Custom',
              emoji: '➕',
              selected: false,
              onTap: () => _showCustomCategoryDialog(context, state),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey[300]!,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  final MyTransaction myTransaction;

  const _VoiceButton({required this.myTransaction});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final listening = state.isVoiceListening;
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: listening
                ? null
                : () async {
                    final confirmed =
                        await state.confirmWithVoice(myTransaction);
                    if (confirmed && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
            icon: Icon(listening ? Icons.mic : Icons.mic_none, size: 20),
            label: Text(listening ? 'Listening...' : 'Describe with voice'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}
