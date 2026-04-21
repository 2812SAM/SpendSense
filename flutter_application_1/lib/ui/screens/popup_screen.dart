/// SpendSense - Popup screen for low-confidence transactions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../state/app_state.dart';

class PopupScreen extends StatelessWidget {
  final MyTransaction myTransaction;

  const PopupScreen({super.key, required this.myTransaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(myTransaction: myTransaction),
                const SizedBox(height: 32),
                const Text(
                  'What was this for?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _CategoryGrid(myTransaction: myTransaction),
                const SizedBox(height: 24),
                _VoiceButton(myTransaction: myTransaction),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip - remind me tonight'),
                  ),
                ),
              ],
            ),
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

class _CategoryGrid extends StatelessWidget {
  final MyTransaction myTransaction;

  const _CategoryGrid({required this.myTransaction});

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
      // Automatically categorize with the new one
      final formattedName =
          name.trim()[0].toUpperCase() + name.trim().substring(1).toLowerCase();
      await state.confirmCategory(myTransaction, formattedName);
      if (context.mounted) Navigator.of(context).pop();
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
              return _CategoryChip(
                label: category,
                emoji: _categoryEmoji[category] ?? '🏷️',
                onTap: () async {
                  await state.confirmCategory(myTransaction, category);
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            }),
            _CategoryChip(
              label: 'Custom',
              emoji: '➕',
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
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        alignment: Alignment.center,
        child: Text('$emoji $label', style: const TextStyle(fontSize: 13)),
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
