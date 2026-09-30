import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_theme.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';
import 'glass_card.dart';

/// 消费分类占比卡片：圆环图 + 图例
///
/// 设计语言：数字优先
/// - 圆环用 teal 不同透明度（按金额排序：1.0 / 0.85 / 0.7 / 0.55 / 0.4 循环）
/// - 描边宽度 18，无填充阴影
/// - 中心显示总支出大数字
/// - 纯色卡片 + 1px 描边（无 GlassCard 包装）
class CategoryDonutCard extends ConsumerWidget {
  const CategoryDonutCard({super.key, required this.slices});

  final List<CategorySlice> slices;

  /// teal 透明度梯度（按金额从大到小分配）
  static const List<double> _alphaSteps = [1.0, 0.85, 0.7, 0.55, 0.4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = slices.fold(0.0, (a, s) => a + s.amount);

    // 按金额降序排序后分配透明度
    final sorted = [...slices]..sort((a, b) => b.amount.compareTo(a.amount));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('消费分类占比', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 16),
          if (slices.isEmpty)
            SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  '本月暂无支出数据',
                  style: TextStyle(color: AppTheme.textHint),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 54,
                          startDegreeOffset: -90,
                          sections: [
                            for (var i = 0; i < sorted.length; i++)
                              PieChartSectionData(
                                value: sorted[i].amount,
                                color: AppTheme.accent
                                    .withValues(alpha: _alphaSteps[i %
                                        _alphaSteps.length]),
                                radius: 18,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '总支出',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              FormatUtils.money(total),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < sorted.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(
                                      alpha: _alphaSteps[i %
                                          _alphaSteps.length]),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(sorted[i].category,
                                      style: const TextStyle(fontSize: 13))),
                              Text(
                                '${sorted[i].percent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
