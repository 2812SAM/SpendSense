import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/classification_provider.dart';
import '../../models/expense_classification.dart';

class GoalsSettingsScreen extends StatefulWidget {
  final bool isOnboarding;

  const GoalsSettingsScreen({super.key, this.isOnboarding = false});

  @override
  State<GoalsSettingsScreen> createState() => _GoalsSettingsScreenState();
}

class _GoalsSettingsScreenState extends State<GoalsSettingsScreen> {
  late TextEditingController _monthlyController;
  final Map<String, TextEditingController> _categoryControllers = {};
  double _currentMonthlyLimit = 0.0;

  @override
  void initState() {
    super.initState();
    final goals = context.read<GoalsProvider>().currentGoals;
    _currentMonthlyLimit = goals.monthlyTotalLimit > 0
        ? goals.monthlyTotalLimit
        : (widget.isOnboarding ? 20000.0 : 0.0);

    _monthlyController = TextEditingController(
      text: _currentMonthlyLimit > 0
          ? _currentMonthlyLimit.toStringAsFixed(0)
          : '',
    );

    _monthlyController.addListener(() {
      setState(() {
        _currentMonthlyLimit = double.tryParse(_monthlyController.text) ?? 0.0;
      });
    });

    for (final category in ['Food', 'Shopping', 'Fun', 'Entertainment']) {
      final catGoal = goals.categoryLimits[category] ?? 0.0;
      _categoryControllers[category] = TextEditingController(
        text: catGoal > 0 ? catGoal.toStringAsFixed(0) : '',
      );
    }
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    for (var controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<GoalsProvider>();
    await provider.updateMonthlyLimit(_currentMonthlyLimit);

    for (final entry in _categoryControllers.entries) {
      final parsedLimit = double.tryParse(entry.value.text) ?? 0;
      if (parsedLimit >= 0) {
        await provider.updateCategoryLimit(entry.key, parsedLimit);
      }
    }

    if (mounted) {
      if (widget.isOnboarding) {
        await Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.pop(context);
      }
    }
  }

  double _calculateTotalRecurring() {
    final classifications =
        context.read<ClassificationProvider>().classifications;
    double total = 0;
    for (final c in classifications) {
      if (c.nature == ExpenseNature.recurring && c.expectedAmount != null) {
        total += c.expectedAmount!;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalRecurring = _calculateTotalRecurring();
    final safeToSpend = _currentMonthlyLimit - totalRecurring;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: widget.isOnboarding
          ? null
          : AppBar(
              title: const Text('Budget & Goals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isOnboarding) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'What is your total monthly income or budget?',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the total amount coming in. SpendSense will automatically deduct your fixed bills to calculate what is safe to spend.',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey[600], height: 1.4),
                  ),
                  const SizedBox(height: 32),
                ],

                const Text(
                  'TOTAL MONTHLY BUDGET',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextFormField(
                    controller: _monthlyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Safe to Spend Calculator Widget
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Budget',
                              style: TextStyle(color: Color(0xFF4B5563))),
                          Text('₹${_currentMonthlyLimit.toStringAsFixed(0)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fixed Bills (Auto-detected)',
                              style: TextStyle(color: Color(0xFF4B5563))),
                          Text('- ₹${totalRecurring.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFC7D2FE)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Safe to Spend',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                  fontSize: 16)),
                          Text(
                              '₹${safeToSpend > 0 ? safeToSpend.toStringAsFixed(0) : "0"}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                  fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  'FLEXIBLE CATEGORY LIMITS (OPTIONAL)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: _categoryControllers.entries.map((entry) {
                      final isLast =
                          entry.key == _categoryControllers.entries.last.key;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: Color(0xFFF3F4F6))),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: entry.value,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  border: InputBorder.none,
                                  hintText: 'No limit',
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.isOnboarding ? 'Continue' : 'Save Goals',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
