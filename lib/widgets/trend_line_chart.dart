import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';

/// 每日支出趋势折线图（FL Chart LineChart）
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: AppTheme.textHint),
          ),
        ),
      );
    }

    final maxVal = points.map((p) => p.expense).reduce(math.max);
    final labelInterval = points.length <= 10 ? 1.0 : 5.0;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal <= 0 ? 10 : maxVal * 1.3,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppTheme.dividerColor,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surface,
              tooltipBorder:
                  BorderSide(color: AppTheme.dividerColor, width: 1),
              tooltipRoundedRadius: 10,
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map((spot) {
                    final i = spot.spotIndex;
                    final p = points[i];
                    return LineTooltipItem(
                      '${FormatUtils.dayLabel(p.day)}\n¥${FormatUtils.money(p.expense)}',
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                        height: 1.4,
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: labelInterval,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      FormatUtils.dayLabel(points[i].day),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textHint,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].expense),
              ],
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              barWidth: 1.5,
              color: AppTheme.accent,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
