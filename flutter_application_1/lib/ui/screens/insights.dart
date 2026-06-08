import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/insights_snapshot.dart';
import '../../models/insight_finding.dart';
import '../../models/savings_opportunity.dart';

import '../../providers/insights_provider.dart';

import '../../providers/classification_provider.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _selectedInsightIndex = 0;
  int _weeklyTouchedIndex = -1;
  int _monthlyTouchedIndex = -1;
  String? _hoveredCardId;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<InsightsProvider>().snapshot;
    // final isLoading = context.watch<InsightsProvider>().isLoading;

    return Scaffold(
      backgroundColor: _InsightsPalette.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              _InsightsPalette.background,
              _InsightsPalette.pageGlow,
              _InsightsPalette.background,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _buildStickyHeader(snapshot),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 672),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildPendingConfirmationsCard(),
                          _buildFinancialHealthCard(snapshot),
                          const SizedBox(height: 24),
                          _buildInsightsSection(snapshot),
                          const SizedBox(height: 24),
                          _buildSpendingPatternsSection(snapshot),
                          const SizedBox(height: 24),
                          _buildTopCategoriesSection(snapshot),
                          const SizedBox(height: 24),
                          _buildSavingsOpportunitiesSection(snapshot),
                          const SizedBox(height: 24),
                          _buildEmptyStateCard(snapshot),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader(InsightsSnapshot snapshot) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: _InsightsPalette.background.withValues(alpha: 0.86),
            border: const Border(
              bottom: BorderSide(color: _InsightsPalette.border),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Your Insights',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _InsightsPalette.mutedText,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Personal Coach',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: _InsightsPalette.foreground,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                _InsightsPalette.purpleSoft,
                                _InsightsPalette.purple,
                                _InsightsPalette.blue,
                              ],
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _InsightsPalette.background,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.psychology_rounded,
                              color: _InsightsPalette.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (snapshot.weeklySpending.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: snapshot.weeklyImprovement >= 0
                              ? _InsightsPalette.emeraldTint
                              : _InsightsPalette.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (snapshot.weeklyImprovement >= 0
                                    ? _InsightsPalette.emerald
                                    : _InsightsPalette.red)
                                .withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(snapshot.weeklyImprovement >= 0 ? '🎉' : '⚠️',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Text(
                              snapshot.weeklyImprovement >= 0
                                  ? 'You spent ${snapshot.weeklyImprovement.abs().toStringAsFixed(0)}% less this week'
                                  : 'You spent ${snapshot.weeklyImprovement.abs().toStringAsFixed(0)}% more this week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: snapshot.weeklyImprovement >= 0
                                    ? _InsightsPalette.emerald
                                    : _InsightsPalette.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingConfirmationsCard() {
    return Consumer<ClassificationProvider>(
      builder: (context, cp, _) {
        if (!cp.hasPendingConfirmations) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _InsightsPalette.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _InsightsPalette.foreground.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: _InsightsPalette.purple, size: 20),
                    SizedBox(width: 8),
                    Text('We found some recurring payments',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Confirm to get more accurate insights and burn rate tracking.',
                    style: TextStyle(
                        color: _InsightsPalette.mutedText, fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cp.pendingConfirmation
                      .map((c) => FilterChip(
                            label: Text(c.merchantOrCategory),
                            selected:
                                true, // We could make this toggleable, but for simplicity we'll just show them
                            onSelected: (_) {}, // No-op for now
                            selectedColor: _InsightsPalette.purpleSoft,
                            checkmarkColor: _InsightsPalette.purple,
                            labelStyle: const TextStyle(
                                color: _InsightsPalette.foreground,
                                fontWeight: FontWeight.w500),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => cp.dismissPendingConfirmation(),
                      style: TextButton.styleFrom(
                          foregroundColor: _InsightsPalette.mutedText),
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () =>
                          cp.confirmDetected(cp.pendingConfirmation),
                      style: FilledButton.styleFrom(
                          backgroundColor: _InsightsPalette.purple),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialHealthCard(InsightsSnapshot snapshot) {
    return MouseRegion(
      onEnter: (_) => _setHoveredCard('hero'),
      onExit: (_) => _clearHoveredCard('hero'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          0,
          _hoveredCardId == 'hero' ? -2 : 0,
          0,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _InsightsPalette.heroPurple,
              _InsightsPalette.background,
              _InsightsPalette.heroBlue,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: _hoveredCardId == 'hero' ? 0.08 : 0.05),
              blurRadius: _hoveredCardId == 'hero' ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Financial Health Score',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _InsightsPalette.mutedText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${snapshot.healthScore}',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: _InsightsPalette.foreground,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                _ScoreRing(score: snapshot.healthScore),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _InsightsPalette.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                snapshot.healthStatus,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _InsightsPalette.emerald,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your financial health is calculated based on spending consistency and category distribution.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _InsightsPalette.bodyText,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: _InsightsPalette.border, height: 1),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Icon(
                  snapshot.monthTrend <= 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 18,
                  color: snapshot.monthTrend <= 0
                      ? _InsightsPalette.emerald
                      : _InsightsPalette.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  '${snapshot.monthTrend >= 0 ? '+' : ''}${snapshot.monthTrend.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: snapshot.monthTrend <= 0
                        ? _InsightsPalette.emerald
                        : _InsightsPalette.orange,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'vs last month',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _InsightsPalette.mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection(InsightsSnapshot snapshot) {
    if (snapshot.findings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: _InsightsPalette.purple,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI Behavioral Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _InsightsPalette.foreground,
                ),
              ),
            ),
            Text(
              '${_selectedInsightIndex + 1} of ${snapshot.findings.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _InsightsPalette.mutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List<Widget>.generate(
          snapshot.findings.length,
          (int index) => Padding(
            padding: EdgeInsets.only(
                bottom: index == snapshot.findings.length - 1 ? 0 : 12),
            child: _buildInsightCard(snapshot.findings[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(InsightFinding insight, int index) {
    final isSelected = index == _selectedInsightIndex;
    final isHovered = _hoveredCardId == 'insight_$index';

    return MouseRegion(
      onEnter: (_) => _setHoveredCard('insight_$index'),
      onExit: (_) => _clearHoveredCard('insight_$index'),
      child: GestureDetector(
        onTap: () => setState(() => _selectedInsightIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? _InsightsPalette.selectedSurface
                : isHovered
                    ? _InsightsPalette.secondary
                    : _InsightsPalette.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? _InsightsPalette.purpleSoft
                  : isHovered
                      ? _InsightsPalette.purpleSoft.withValues(alpha: 0.6)
                      : _InsightsPalette.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isSelected || isHovered ? 0.06 : 0.03),
                blurRadius: isSelected || isHovered ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                insight.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      insight.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _InsightsPalette.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      insight.description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: _InsightsPalette.bodyText,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: isSelected
                          ? const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'View details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _InsightsPalette.purple,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 15,
                                    color: _InsightsPalette.purple,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _InsightTrendBadge(trend: insight.trend),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpendingPatternsSection(InsightsSnapshot snapshot) {
    if (snapshot.weeklySpending.isEmpty && snapshot.monthlyTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(
              Icons.track_changes_rounded,
              size: 20,
              color: _InsightsPalette.blue,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Spending Pattern Visualization',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _InsightsPalette.foreground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _InsightsPalette.background,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (snapshot.weeklySpending.isNotEmpty) ...[
                const Text(
                  'Weekly Breakdown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _InsightsPalette.foreground,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 220, child: _buildWeeklyBarChart(snapshot)),
                const SizedBox(height: 24),
              ],
              if (snapshot.monthlyTrend.isNotEmpty) ...[
                if (snapshot.weeklySpending.isNotEmpty)
                  const Divider(color: _InsightsPalette.border, height: 1),
                const SizedBox(height: 24),
                const Text(
                  'Monthly Trend',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _InsightsPalette.foreground,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: _buildMonthlyLineChart(snapshot)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyBarChart(InsightsSnapshot snapshot) {
    final maxAmount = snapshot.weeklySpending
        .fold<double>(0, (maxVal, datum) => math.max(maxVal, datum.amount));
    final maxY = (maxAmount / 1000).ceil() * 1000.0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final maxWidth = constraints.maxWidth;
        final reservedBottom = maxWidth < 360 ? 34.0 : 28.0;
        final reservedLeft = maxWidth < 360 ? 36.0 : 40.0;

        return BarChart(
          BarChartData(
            maxY: maxY == 0 ? 1000.0 : maxY,
            minY: 0.0,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              horizontalInterval: maxY == 0 ? 200.0 : maxY / 4,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: _InsightsPalette.grid,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                if (!mounted) return;
                final nextIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                setState(() => _weeklyTouchedIndex = nextIndex);
              },
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 10,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tooltipMargin: 10,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => _InsightsPalette.foreground,
                getTooltipItem: (
                  BarChartGroupData group,
                  int groupIndex,
                  BarChartRodData rod,
                  int rodIndex,
                ) {
                  return BarTooltipItem(
                    '${snapshot.weeklySpending[group.x.toInt()].label}\n₹${rod.toY.toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: reservedLeft,
                  interval: maxY == 0 ? 200.0 : maxY / 4,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      '₹${(value / 1000).toStringAsFixed(value == 0 ? 0 : 1)}k',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _InsightsPalette.mutedText,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: reservedBottom,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= snapshot.weeklySpending.length) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        snapshot.weeklySpending[index].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: index == _weeklyTouchedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == _weeklyTouchedIndex
                              ? _InsightsPalette.foreground
                              : _InsightsPalette.mutedText,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List<BarChartGroupData>.generate(
              snapshot.weeklySpending.length,
              (int index) {
                final datum = snapshot.weeklySpending[index];
                final isActive = index == _weeklyTouchedIndex;

                return BarChartGroupData(
                  x: index,
                  barsSpace: 0,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: datum.amount,
                      width: 18,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      color: _weeklyBarColor(index),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY == 0 ? 1000.0 : maxY,
                        color: _InsightsPalette.secondary,
                      ),
                    ),
                  ],
                  showingTooltipIndicators:
                      isActive ? const <int>[0] : const <int>[],
                );
              },
            ),
          ),
          swapAnimationDuration: const Duration(milliseconds: 250),
        );
      },
    );
  }

  Widget _buildMonthlyLineChart(InsightsSnapshot snapshot) {
    final maxAmount = snapshot.monthlyTrend
        .fold<double>(0, (maxVal, datum) => math.max(maxVal, datum.amount));
    final minAmount = snapshot.monthlyTrend.fold<double>(
        maxAmount, (minVal, datum) => math.min(minVal, datum.amount));

    final maxY = (maxAmount * 1.1 / 500).ceil() * 500.0;
    final minY = (minAmount * 0.9 / 500).floor() * 500.0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final maxWidth = constraints.maxWidth;
        final reservedBottom = maxWidth < 360 ? 38.0 : 30.0;
        final reservedLeft = maxWidth < 360 ? 44.0 : 48.0;

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (snapshot.monthlyTrend.length - 1).toDouble(),
            minY: minY,
            maxY: maxY == minY ? minY + 1000 : maxY,
            gridData: FlGridData(
              show: true,
              horizontalInterval: (maxY - minY) == 0 ? 200 : (maxY - minY) / 4,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: _InsightsPalette.grid,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                if (!mounted) return;
                final spots = response?.lineBarSpots;
                final nextIndex = spots != null && spots.isNotEmpty
                    ? spots.first.x.toInt()
                    : -1;
                setState(() => _monthlyTouchedIndex = nextIndex);
              },
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 10,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => _InsightsPalette.foreground,
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((LineBarSpot spot) {
                    final datum = snapshot.monthlyTrend[spot.x.toInt()];
                    return LineTooltipItem(
                      '${datum.label}\n₹${spot.y.toInt()}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: reservedLeft,
                  interval: (maxY - minY) == 0 ? 200 : (maxY - minY) / 4,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      '₹${(value / 1000).toStringAsFixed(1)}k',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _InsightsPalette.mutedText,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: reservedBottom,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= snapshot.monthlyTrend.length) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        snapshot.monthlyTrend[index].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: index == _monthlyTouchedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == _monthlyTouchedIndex
                              ? _InsightsPalette.foreground
                              : _InsightsPalette.mutedText,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                isCurved: true,
                color: _InsightsPalette.purple,
                barWidth: 3,
                curveSmoothness: 0.25,
                spots: List<FlSpot>.generate(
                  snapshot.monthlyTrend.length,
                  (int index) => FlSpot(
                    index.toDouble(),
                    snapshot.monthlyTrend[index].amount,
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (
                    FlSpot spot,
                    double percent,
                    LineChartBarData barData,
                    int index,
                  ) {
                    final isActive = spot.x.toInt() == _monthlyTouchedIndex;
                    return FlDotCirclePainter(
                      radius: isActive ? 5.5 : 4.5,
                      color: _InsightsPalette.purple,
                      strokeWidth: 2,
                      strokeColor: _InsightsPalette.background,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      _InsightsPalette.purple.withValues(alpha: 0.18),
                      _InsightsPalette.purple.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        );
      },
    );
  }

  Widget _buildTopCategoriesSection(InsightsSnapshot snapshot) {
    if (snapshot.topCategories.isEmpty) return const SizedBox.shrink();

    final maxAmount = snapshot.topCategories.fold<double>(
      0,
      (double currentMax, CategoryInsight item) =>
          math.max(currentMax, item.amount),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Top Spending Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _InsightsPalette.foreground,
          ),
        ),
        const SizedBox(height: 16),
        ...List<Widget>.generate(
          snapshot.topCategories.length,
          (int index) => Padding(
            padding: EdgeInsets.only(
                bottom: index == snapshot.topCategories.length - 1 ? 0 : 12),
            child: _buildCategoryCard(
                snapshot.topCategories[index], maxAmount, index),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
      CategoryInsight category, double maxAmount, int index) {
    final isHovered = _hoveredCardId == 'category_$index';

    return MouseRegion(
      onEnter: (_) => _setHoveredCard('category_$index'),
      onExit: (_) => _clearHoveredCard('category_$index'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _InsightsPalette.background,
          borderRadius: BorderRadius.circular(10),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isHovered ? 0.07 : 0.04),
              blurRadius: isHovered ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: category.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    category.name[0],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _InsightsPalette.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${category.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _InsightsPalette.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCategoryTrend(category.trend),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: maxAmount == 0 ? 0 : category.amount / maxAmount,
                backgroundColor: _InsightsPalette.secondary,
                valueColor: AlwaysStoppedAnimation<Color>(category.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTrend(double trend) {
    if (trend == 0) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: _InsightsPalette.mutedText,
        ),
      );
    }

    final isUp = trend > 0;
    final color = isUp ? _InsightsPalette.orange : _InsightsPalette.emerald;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${trend.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsOpportunitiesSection(InsightsSnapshot snapshot) {
    if (snapshot.savingsOpportunities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Savings Opportunities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _InsightsPalette.foreground,
          ),
        ),
        const SizedBox(height: 16),
        ...List<Widget>.generate(
          snapshot.savingsOpportunities.length,
          (int index) => Padding(
            padding: EdgeInsets.only(
              bottom:
                  index == snapshot.savingsOpportunities.length - 1 ? 0 : 12,
            ),
            child:
                _buildSavingsCard(snapshot.savingsOpportunities[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsCard(SavingsOpportunity opportunity, int index) {
    final isHovered = _hoveredCardId == 'saving_$index';

    return MouseRegion(
      onEnter: (_) => _setHoveredCard('saving_$index'),
      onExit: (_) => _clearHoveredCard('saving_$index'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isHovered
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    _InsightsPalette.emeraldTint,
                    _InsightsPalette.background,
                  ],
                )
              : null,
          color: isHovered ? null : _InsightsPalette.background,
          borderRadius: BorderRadius.circular(10),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isHovered ? 0.07 : 0.04),
              blurRadius: isHovered ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              opportunity.emoji,
              style: const TextStyle(fontSize: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          opportunity.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _InsightsPalette.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _InsightsPalette.emeraldTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          opportunity.potentialAmount,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _InsightsPalette.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opportunity.description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _InsightsPalette.bodyText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isHovered
                              ? const Color(0xFF047857)
                              : _InsightsPalette.emerald,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: isHovered
                            ? const Color(0xFF047857)
                            : _InsightsPalette.emerald,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(InsightsSnapshot snapshot) {
    if (snapshot.isInitialised && snapshot.topCategories.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _InsightsPalette.blueTint,
            _InsightsPalette.selectedSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        snapshot.isInitialised
            ? 'Confirm more transactions to see deeper personalized insights! 🧠'
            : 'Your spending patterns are still being understood. Confirm more transactions to see your personalized insights! 🧠',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: _InsightsPalette.bodyText,
        ),
      ),
    );
  }

  void _setHoveredCard(String id) {
    if (!mounted || _hoveredCardId == id) return;
    setState(() => _hoveredCardId = id);
  }

  void _clearHoveredCard(String id) {
    if (!mounted || _hoveredCardId != id) return;
    setState(() => _hoveredCardId = null);
  }

  Color _weeklyBarColor(int index) {
    if (index == 5 || index == 6) return _InsightsPalette.pink; // Weekend
    return _InsightsPalette.purple;
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _ScoreRingPainter.colorFor(score);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _ScoreRingPainter(
              progress: value,
              color: color,
            ),
            child: Center(
              child: Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _InsightsPalette.mutedText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  static Color colorFor(int score) {
    if (score >= 80) return _InsightsPalette.emerald;
    if (score >= 60) return _InsightsPalette.orange;
    return _InsightsPalette.red;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 8;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = _InsightsPalette.border;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _InsightTrendBadge extends StatelessWidget {
  const _InsightTrendBadge({required this.trend});

  final InsightTrend trend;

  @override
  Widget build(BuildContext context) {
    switch (trend) {
      case InsightTrend.up:
        return const Icon(
          Icons.trending_up_rounded,
          size: 18,
          color: _InsightsPalette.orange,
        );
      case InsightTrend.down:
        return const Icon(
          Icons.trending_down_rounded,
          size: 18,
          color: _InsightsPalette.emerald,
        );
      case InsightTrend.stable:
        return Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: _InsightsPalette.cyan,
            shape: BoxShape.circle,
          ),
        );
    }
  }
}

class _InsightsPalette {
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF252525);
  static const Color bodyText = Color(0xFF4B5563);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color secondary = Color(0xFFF8F8F8);
  static const Color selectedSurface = Color(0xFFF5F1FF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color grid = Color(0xFFF0F0F0);
  static const Color purpleSoft = Color(0xFFA78BFA);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color emerald = Color(0xFF10B981);
  static const Color pink = Color(0xFFEC4899);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFFF6B6B);
  static const Color blue = Color(0xFF4C6EF5);
  static const Color cyan = Color(0xFF15AABF);
  static const Color heroPurple = Color(0x33A78BFA);
  static const Color heroBlue = Color(0x334C6EF5);
  static const Color pageGlow = Color(0x4DE8BDF7);
  static const Color blueTint = Color(0xFFEFF6FF);
  static const Color emeraldTint = Color(0xFFECFDF5);
}
