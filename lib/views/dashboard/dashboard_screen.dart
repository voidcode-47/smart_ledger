import 'dart:ui';

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
    // 监听背景主题：切换主题时重建本页，让 AppTheme 动态色（卡片/文字/收入支出色）立即刷新
    ref.watch(backgroundThemeProvider);

    final now = DateTime.now();
    final canGoNext = month.year < now.year ||
        (month.year == now.year && month.month < now.month);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
        children: [
          // ignore: prefer_const_constructors —— 必须非 const：主题切换时强制重建刷新卡片颜色
          QuoteCard(),
          const SizedBox(height: 12),
          _monthHeader(ref, month, canGoNext),
          const SizedBox(height: 14),
          _balanceHero(summary),
          const SizedBox(height: 16),
          // ignore: prefer_const_constructors —— 必须非 const：主题切换时强制重建刷新卡片颜色
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
                const SizedBox(height: 4),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        '暂无流水，点击 + 开始记账',
                        style: TextStyle(
                            color: AppTheme.onSurface(alpha: 0.50)),
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

  // ---------- 月份切换（玻璃胶囊） ----------
  Widget _monthHeader(WidgetRef ref, DateTime month, bool canGoNext) {
    // 黑色背景下反白，保证背景上的文字/图标可读
    final dark = ref.watch(backgroundThemeProvider).isDark;
    final onBg = ThemeConfig.onBackground(dark);
    final onBgDim = ThemeConfig.onBackground(dark, alpha: 0.30);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.glassFillStrong,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(ref, -1),
                  icon: Icon(Icons.chevron_left_rounded, color: onBg),
                ),
                Text(FormatUtils.monthTitle(month),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onBg)),
                IconButton(
                  onPressed: canGoNext ? () => _shiftMonth(ref, 1) : null,
                  icon: Icon(Icons.chevron_right_rounded,
                      color: canGoNext ? onBg : onBgDim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) {
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(m.year, m.month + delta);
  }

  // ---------- 本月收支 Hero 卡：主色渐变 + 柔光装饰 ----------
  Widget _balanceHero(MonthSummary summary) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.accentGradient,
        ),
        boxShadow: const [
          BoxShadow(
              color: AppTheme.accentGlow,
              blurRadius: 24,
              offset: Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -46,
              right: -28,
              child: _heroCircle(130, 0.10),
            ),
            Positioned(
              bottom: -64,
              left: 130,
              child: _heroCircle(120, 0.07),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Row(
                children: [
                  _heroColumn('收入', FormatUtils.money(summary.income)),
                  _heroDivider(),
                  _heroColumn('支出', FormatUtils.money(summary.expense)),
                  _heroDivider(),
                  _heroColumn('结余', null, animatedValue: summary.balance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCircle(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white.withValues(alpha: 0.25),
      );

  /// Hero 卡摘要列：[animatedValue] 非 null 时使用数字滚动（结余）
  Widget _heroColumn(String label, String? text, {double? animatedValue}) {
    const amountStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 0.3,
    );
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          FittedBox(
            child: animatedValue != null
                ? CountUpText(value: animatedValue, style: amountStyle)
                : Text(text!, style: amountStyle),
          ),
        ],
      ),
    );
  }
}
