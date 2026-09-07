import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/budget_card.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/donut_chart.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/quote_card.dart';
import '../../widgets/staggered_item.dart';
import '../../widgets/transaction_tile.dart';
import '../add_transaction/add_transaction_sheet.dart';

/// 仪表盘：当月收支结余（数字滚动）+ 消费分类圆环图 + 最近 5 条流水（交错动画）
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final slices = ref.watch(categoryBreakdownProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final listState = ref.watch(transactionListProvider);
    final month = ref.watch(selectedMonthProvider);

    final now = DateTime.now();
    final canGoNext = month.year < now.year ||
        (month.year == now.year && month.month < now.month);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
        children: [
          const QuoteCard(),
          const SizedBox(height: 12),
        _monthHeader(ref, month, canGoNext),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              _amountColumn('收入', summary.income, AppTheme.incomeColor),
              _divider(),
              _amountColumn('支出', summary.expense, AppTheme.expenseColor),
              _divider(),
              _amountColumn('结余', summary.balance, AppTheme.accent,
                  animated: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const BudgetCard(),
        const SizedBox(height: 16),
        CategoryDonutCard(slices: slices),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('最近流水', style: AppTextStyles.sectionTitle),
                  const Spacer(),
                  if (listState.isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      '暂无流水，点击 + 开始记账',
                      style:
                          TextStyle(color: Colors.black.withValues(alpha: 0.50)),
                    ),
                  ),
                )
              else
                ...recent.asMap().entries.map(
                      (e) => StaggeredItem(
                        key: ValueKey('recent_${e.value.id ?? e.key}'),
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
      ),
    );
  }

  // ---------- 月份切换 ----------
  Widget _monthHeader(WidgetRef ref, DateTime month, bool canGoNext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _shiftMonth(ref, -1),
          icon: Icon(Icons.chevron_left_rounded,
              color: Colors.black.withValues(alpha: 0.80)),
        ),
        Text(FormatUtils.monthTitle(month),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: canGoNext ? () => _shiftMonth(ref, 1) : null,
          icon: Icon(Icons.chevron_right_rounded,
              color: canGoNext
                  ? Colors.black.withValues(alpha: 0.80)
                  : Colors.black.withValues(alpha: 0.15)),
        ),
      ],
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) {
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(m.year, m.month + delta);
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.black.withValues(alpha: 0.15),
      );

  // ---------- 摘要列 ----------
  Widget _amountColumn(String label, double value, Color color,
      {bool animated = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.black.withValues(alpha: 0.60))),
          const SizedBox(height: 6),
          FittedBox(
            child: animated
                ? CountUpText(
                    value: value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  )
                : Text(
                    FormatUtils.money(value),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
