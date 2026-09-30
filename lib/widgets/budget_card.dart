import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';
import 'glass_card.dart';

/// 月度预算卡片：已支出 / 预算进度条 + 剩余（或超支）提示 + 点击设置
class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetProvider);
    final monthExpense = ref.watch(monthSummaryProvider).expense;
    final month = ref.watch(selectedMonthProvider);

    return GlassCard(
      child: budgetAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Text('预算读取失败：$e',
            style: TextStyle(fontSize: 12, color: AppTheme.expenseColor)),
        data: (budget) {
          if (budget == null) {
            return _empty(context, ref, month);
          }
          final remaining = budget - monthExpense;
          final ratio = budget <= 0 ? 0.0 : (monthExpense / budget).clamp(0.0, 1.0);
          final over = remaining < 0;
          final progressColor = over
              ? AppTheme.expenseColor
              : ratio >= 0.8
                  ? const Color(0xFFFAAD14)
                  : AppTheme.accent;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('本月预算', style: AppTextStyles.sectionTitle),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _showBudgetDialog(context, ref, budget),
                    child: const Text('调整', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.money(monthExpense),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 3),
                    child: Text(' / ${FormatUtils.money(budget)}',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      over
                          ? '超支 ${FormatUtils.money(-remaining)}'
                          : '剩余 ${FormatUtils.money(remaining)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: over
                            ? AppTheme.expenseColor
                            : AppTheme.incomeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: AppTheme.dividerColor,
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '已支出 ${(ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textHint),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref, DateTime month) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showBudgetDialog(context, ref, null),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.savings_outlined,
                size: 26, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本月预算',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '点击为 ${FormatUtils.monthTitle(month)} 设置预算，随时掌握超支情况',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetDialog(
      BuildContext context, WidgetRef ref, double? current) async {
    final ctrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(2) : '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('设置月度预算'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '预算金额（元）',
            prefixText: '¥ ',
            hintText: current == null ? '输入 0 或留空可清除' : '输入 0 可清除',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final amount = double.tryParse(ctrl.text.trim()) ?? 0;
    await DatabaseService.instance
        .setBudget(monthKey(ref.read(selectedMonthProvider)), amount);
    ref.read(budgetVersionProvider.notifier).state++;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(amount > 0 ? '预算已设置' : '预算已清除'),
          duration: const Duration(seconds: 2)));
  }
}
