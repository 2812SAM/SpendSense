import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HeroSection extends StatelessWidget {
  final double totalSpending;
  final double budget;
  final int transactionCount;
  final String topCategory;
  final List<double> trendData;

  const HeroSection({
    super.key,
    required this.totalSpending,
    required this.budget,
    required this.transactionCount,
    required this.topCategory,
    required this.trendData,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (totalSpending / budget).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Chart (aura layer)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Opacity(
                  opacity: 0.4,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: trendData
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: const Color(0xFF4F46E5),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                const Color(0xFF4F46E5).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Frosted overlay for text legibility
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content Layer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Left: Total Spending + Metadata Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'May Spending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Dynamic scaling for large numbers
                        _ScalingCurrency(amount: totalSpending),
                        const SizedBox(height: 12),
                        // Metadata chips (replacing 3-card summary)
                        Wrap(
                          spacing: 8,
                          children: [
                            _MetadataChip(
                              icon: Icons.receipt_outlined,
                              label: '$transactionCount transactions',
                              color: const Color(0xFF10B981),
                            ),
                            _MetadataChip(
                              icon: Icons.category_outlined,
                              label: 'Top: $topCategory',
                              color: const Color(0xFFF59E0B),
                              onTap: topCategory == '-'
                                  ? null
                                  : () {
                                      Navigator.pushNamed(
                                        context,
                                        '/category-details',
                                        arguments: topCategory,
                                      );
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: Budget Ring
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation(
                            progress > 0.9
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF4F46E5),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Text(
                              'of budget',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}

// Enhancement #2: Dynamic Font Scaling for large currency values
class _ScalingCurrency extends StatelessWidget {
  final double amount;

  const _ScalingCurrency({required this.amount});

  @override
  Widget build(BuildContext context) {
    final formatted = amount.toStringAsFixed(0);
    // Scale down by 15% if exceeds 7 digits
    final fontSize = formatted.length > 7 ? 28.0 * 0.85 : 28.0;

    return Text(
      '₹$formatted',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: const Color(0xFF111827),
        letterSpacing: -0.5,
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MetadataChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
