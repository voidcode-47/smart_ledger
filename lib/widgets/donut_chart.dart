import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../utils/app_theme.dart';
import '../utils/category_utils.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';
import 'glass_card.dart';

/// 消费分类占比卡片：FL Chart 圆环图 + 图例（动态分类颜色）
class CategoryDonutCard extends ConsumerWidget {
  const CategoryDonutCard({super.key, required this.slices});

  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = slices.fold(0.0, (a, s) => a + s.amount);
    final categories =
        ref.watch(categoryMapProvider).value ?? const <String, Category>{};

    Color colorOf(String name) {
      final c = categories[name];
      return c != null
          ? CategoryUtils.colorOfCategory(c)
          : CategoryUtils.fallbackColor;
    }

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
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.50)),
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
                          sectionsSpace: 3,
                          centerSpaceRadius: 52,
                          startDegreeOffset: -90,
                          sections: [
                            for (final s in slices)
                              PieChartSectionData(
                                value: s.amount,
                                color: colorOf(s.category),
                                radius: 22,
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
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.60),
                              ),
                            ),
                            Text(
                              FormatUtils.money(total),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
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
                      for (final s in slices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorOf(s.category),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(s.category)),
                              Text(
                                '${s.percent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withValues(alpha: 0.70),
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
