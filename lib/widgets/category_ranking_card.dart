import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../utils/app_theme.dart';
import '../utils/category_utils.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';
import 'glass_card.dart';

/// 本月分类支出排行：分类名 + 金额 + 占比条 + 环比上月变化
class CategoryRankingCard extends ConsumerWidget {
  const CategoryRankingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(categoryRankingProvider);
    final categories =
        ref.watch(categoryMapProvider).value ?? const <String, Category>{};
    if (items.isEmpty) return const SizedBox.shrink();

    final maxAmount = items.first.amount;

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
          const Text('本月分类排行', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text(
            '按支出金额排序 · 徽标为本月对比上月变化',
            style: TextStyle(
                fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _row(items[i], colorOf(items[i].category), maxAmount, i + 1),
          ],
        ],
      ),
    );
  }

  Widget _row(CategoryRankItem item, Color color, double maxAmount, int rank) {
    final delta = item.amount - item.prevAmount;
    final isUp = delta > 0.001;
    final isDown = delta < -0.001;

    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text('$rank',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.50))),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            item.category.length > 4
                ? '${item.category.substring(0, 4)}…'
                : item.category,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxAmount <= 0 ? 0 : item.amount / maxAmount,
              minHeight: 6,
              backgroundColor: Colors.black.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          FormatUtils.money(item.amount),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            isUp
                ? '↑${FormatUtils.compactMoney(delta)}'
                : isDown
                    ? '↓${FormatUtils.compactMoney(-delta)}'
                    : '—',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUp
                  ? AppTheme.expenseColor
                  : isDown
                      ? const Color(0xFF4ADE80)
                      : Colors.black.withValues(alpha: 0.40),
            ),
          ),
        ),
      ],
    );
  }
}
