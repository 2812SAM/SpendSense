/// SpendSense - Popup screen (Premium Redesign)
/// Shown for immediate feedback when a transaction is received in the foreground.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../services/category_service.dart';
import '../widgets/custom_category_dialog.dart';

import '../../models/expense_classification.dart';
import '../../providers/classification_provider.dart';

class PopupScreen extends StatefulWidget {
  final MyTransaction myTransaction;

  const PopupScreen({super.key, required this.myTransaction});

  @override
  State<PopupScreen> createState() => _PopupScreenState();
}

class _PopupScreenState extends State<PopupScreen> {
  String? _selectedCategory;
  ExpenseNature? _selectedNature;
  bool _rememberCategory = false;
  Map<String, String> _emojis = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing category if it's not ASK_USER
    if (widget.myTransaction.category != 'ASK_USER') {
      _selectedCategory = widget.myTransaction.category;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCategory != null) {
        final cp = context.read<ClassificationProvider>();
        setState(() {
          _selectedNature =
              cp.natureOf(widget.myTransaction.merchant, _selectedCategory!);
        });
      }
    });

    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    final emojis = await CategoryService.instance.getAllCategoriesWithEmojis();
    if (mounted) setState(() => _emojis = emojis);
  }

  void _onCategorySelected(String category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
        _selectedNature = null;
      } else {
        _selectedCategory = category;
        // Logic: When a category is first picked, we DO NOT auto-check "Remember"
        // The user must explicitly opt-in.
        _rememberCategory = false;
        _selectedNature = context
            .read<ClassificationProvider>()
            .natureOf(widget.myTransaction.merchant, category);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selectedCategory == null) return;

    final cp = context.read<ClassificationProvider>();
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    if (_selectedNature != null) {
      await cp.setClassification(
        _selectedCategory!,
        _selectedNature!,
      );
    }

    await state.confirmCategory(
      widget.myTransaction,
      _selectedCategory!,
      isDynamic: !_rememberCategory,
    );

    navigator.pop();
  }

  Future<void> _ignore() async {
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);
    await state.confirmCategory(
      widget.myTransaction,
      AppConstants.categoryIgnored,
    );
    navigator.pop();
  }

  Future<void> _showCustomCategoryDialog() async {
    final state = context.read<AppState>();
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
      _onCategorySelected(formattedName);
      unawaited(_loadEmojis());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = [...state.allCategories, 'Loan'];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Confirm Payment',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            border: Border(
                                bottom: BorderSide(
                                    color: Color(0xFFF3F4F6), width: 1)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '₹${widget.myTransaction.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.myTransaction.merchant,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(widget.myTransaction.timestamp),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Selection
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
                                    final isSelected = _selectedCategory == cat;
                                    return GestureDetector(
                                      onTap: () => _onCategorySelected(cat),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF4F46E5)
                                              : const Color(0xFFF9FAFB),
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                                              style:
                                                  const TextStyle(fontSize: 16),
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
                                    onTap: _showCustomCategoryDialog,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFD1D5DB),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_rounded,
                                              size: 18,
                                              color: Color(0xFF4F46E5)),
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

                              // Remember Toggle
                              if (_selectedCategory != null)
                                GestureDetector(
                                  onTap: () => setState(() =>
                                      _rememberCategory = !_rememberCategory),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _rememberCategory
                                          ? const Color(0xFFEEF2FF)
                                          : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _rememberCategory
                                            ? const Color(0xFFC7D2FE)
                                            : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _rememberCategory
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          color: _rememberCategory
                                              ? const Color(0xFF4F46E5)
                                              : const Color(0xFF9CA3AF),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                          final navigator =
                                              Navigator.of(context);
                                          final confirmed =
                                              await state.confirmWithVoice(
                                                  widget.myTransaction);
                                          if (confirmed) {
                                            navigator.pop();
                                          }
                                        },
                                  icon: Icon(
                                      state.isVoiceListening
                                          ? Icons.mic
                                          : Icons.mic_none,
                                      size: 20),
                                  label: Text(state.isVoiceListening
                                      ? 'Listening...'
                                      : 'Describe with voice'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: const BorderSide(
                                        color: Color(0xFFE5E7EB)),
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
              ),
            ),

            // Bottom Actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              color: const Color(0xFFF9FAFB),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Tonight',
                            style: TextStyle(
                                color: Color(0xFF4B5563),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: (_selectedCategory == null || _isSaving)
                              ? null
                              : _confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text(
                                  'Confirm',
                                  style: TextStyle(
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
                      onPressed: _isSaving ? null : _ignore,
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
        ),
      ),
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
    return '$hour:$minute $suffix · ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}
