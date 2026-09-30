import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/theme_config.dart';
import '../../viewmodels/theme_providers.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/budget_card.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/donut_chart.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/quote_card.dart';
import '../../widgets/transaction_tile.dart';
import '../add_transaction/add_transaction_sheet.dart';

/// 仪表盘：本月结余大数字（signature moment）+ 预算 + 分类圆环 + 最近流水
///
/// 设计语言：数字优先
/// - Hero 大数字成为视觉锚点（48sp w800 tabular nums，teal 主色）
/// - 其他全部克制：纯色卡片 + 1px 描边 + 排版层次
/// - 无渐变、无装饰圆圈、无阴影、无 BackdropFilter
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final slices = ref.watch(categoryBreakdownProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final listState = ref.watch(transactionListProvider);
    final month = ref.watch(selectedMonthProvider);
    // 监听背景主题：切换主题时重建本页刷新颜色
    ref.watch(backgroundThemeProvider);

    final now = DateTime.now();
    final canGoNext = month.year < now.year ||
        (month.year == now.year && month.month < now.month);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          QuoteCard(),
          const SizedBox(height: 16),
          _monthHeader(ref, month, canGoNext),
          const SizedBox(height: 20),
          _balanceHero(summary),
          const SizedBox(height: 20),
          BudgetCard(),
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
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        '暂无流水，点击 + 开始记账',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...recent.map(
                    (e) => TransactionTile(
                      entry: e,
                      onEdit: e.id == null
                          ? null
                          : () => AddTransactionSheet.show(context,
                              initial: e),
                      onDelete: e.id == null
                          ? null
                          : () => ref
                              .read(transactionListProvider.notifier)
                              .remove(e.id!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 月份切换（纯色胶囊 + 1px 描边） ----------
  Widget _monthHeader(WidgetRef ref, DateTime month, bool canGoNext) {
    final dark = ref.watch(backgroundThemeProvider).isDark;
    final onBg = ThemeConfig.onBackground(dark);
    final onBgDim = ThemeConfig.onBackground(dark, alpha: 0.30);
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        borderRadius: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _shiftMonth(ref, -1),
              icon: Icon(Icons.chevron_left_rounded, color: onBg),
            ),
            Text(FormatUtils.monthTitle(month),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onBg)),
            IconButton(
              onPressed: canGoNext ? () => _shiftMonth(ref, 1) : null,
              icon: Icon(Icons.chevron_right_rounded,
                  color: canGoNext ? onBg : onBgDim),
            ),
          ],
        ),
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) {
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(m.year, m.month + delta);
  }

  // ---------- 本月结余 Hero（signature moment：大数字） ----------
  Widget _balanceHero(MonthSummary summary) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签：小灰字
          Text(
            '本月结余',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // 大数字（teal 主色，数字滚动）
          CountUpText(
            value: summary.balance,
            style: AppTextStyles.displayNumber.copyWith(color: AppTheme.accent),
          ),
          const SizedBox(height: 20),
          // 支撑数据：收入 / 支出
          Row(
            children: [
              _summaryItem('收入', FormatUtils.money(summary.income),
                  AppTheme.incomeColor),
              const SizedBox(width: 24),
              _summaryItem('支出', FormatUtils.money(summary.expense),
                  AppTheme.expenseColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
