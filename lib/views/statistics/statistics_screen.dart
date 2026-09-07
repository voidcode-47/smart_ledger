import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/category_utils.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/category_ranking_card.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/staggered_item.dart';
import '../../widgets/trend_line_chart.dart';
import '../../widgets/transaction_tile.dart';
import '../add_transaction/add_transaction_sheet.dart';

/// 统计报表：近 7/30 天支出趋势折线图 + 分类筛选 + 明细列表
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(dailyTrendProvider);
    final details = ref.watch(trendDetailProvider);
    final range = ref.watch(trendRangeProvider);
    final filter = ref.watch(trendCategoryFilterProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        const Text('统计报表', style: AppTextStyles.pageTitle),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('支出趋势', style: AppTextStyles.sectionTitle)),
                  _rangeChip(ref, 7, '近7天', range),
                  const SizedBox(width: 8),
                  _rangeChip(ref, 30, '近30天', range),
                ],
              ),
              const SizedBox(height: 16),
              TrendLineChart(points: points),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const CategoryRankingCard(),
        const SizedBox(height: 16),
        _categoryFilter(ref, filter, categoriesAsync),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('明细（${details.length} 条）',
                  style: AppTextStyles.sectionTitle),
              const SizedBox(height: 4),
              if (details.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('该筛选范围内暂无支出',
                        style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.50))),
                  ),
                )
              else
                ...details.asMap().entries.map(
                      (e) => StaggeredItem(
                        key: ValueKey('detail_${e.value.id ?? e.key}'),
                        index: e.key,
                        child: TransactionTile(
                          entry: e.value,
                          onEdit: e.value.id == null
                              ? null
                              : () => AddTransactionSheet.show(context,
                                  initial: e.value),
                          onDelete: e.value.id == null
                              ? null
                              : () => ref
                                  .read(transactionListProvider.notifier)
                                  .remove(e.value.id!),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- 近 7 / 30 天切换 ----------
  Widget _rangeChip(WidgetRef ref, int value, String label, int current) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.accent,
      backgroundColor: Colors.black.withValues(alpha: 0.10),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppTheme.textSecondary,
      ),
      side: BorderSide.none,
      showCheckmark: false,
      onSelected: (_) => ref.read(trendRangeProvider.notifier).state = value,
    );
  }

  // ---------- 分类筛选（动态分类） ----------
  Widget _categoryFilter(
      WidgetRef ref, String? filter, AsyncValue<List<Category>> categoriesAsync) {
    Widget chip(String label, {String? value, Color? selectedColor}) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor:
              selectedColor ?? AppTheme.accent,
          backgroundColor: Colors.black.withValues(alpha: 0.06),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
          side: BorderSide.none,
          showCheckmark: false,
          onSelected: (_) =>
              ref.read(trendCategoryFilterProvider.notifier).state = value,
        ),
      );
    }

    return categoriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) => Wrap(
        children: [
          chip('全部'),
          for (final c in categories)
            chip(
              c.name,
              value: c.name,
              selectedColor:
                  CategoryUtils.colorOfCategory(c).withValues(alpha: 0.9),
            ),
        ],
      ),
    );
  }
}
