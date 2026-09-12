import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';
import 'glass_card.dart';

/// 本月小结：纯本地规则生成（不依赖任何 AI/网络），
/// 面向大学生与自由职业者常见的两个问题——
/// “这个月花了多少、花在哪”“这个月赚了多少、和上月比怎么样”。
class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final month = ref.watch(selectedMonthProvider);
    final all = ref.watch(transactionListProvider).value ?? const [];

    final lines = _buildLines(month, summary, breakdown, all);
    if (lines.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('本月小结', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text(
                FormatUtils.monthTitle(month),
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurface(alpha: 0.45)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(fontSize: 13, height: 1.55),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 规则模板拼装；数据全部来自本地流水，无外部依赖
  List<String> _buildLines(
    DateTime month,
    MonthSummary summary,
    List<CategorySlice> breakdown,
    List<TransactionEntry> all,
  ) {
    final lines = <String>[];
    if (summary.income <= 0 && summary.expense <= 0) return lines;

    // 1. 收支概况
    lines.add(
      '本月收入 ${FormatUtils.money(summary.income)}，'
      '支出 ${FormatUtils.money(summary.expense)}，'
      '结余 ${FormatUtils.signedMoney(summary.income - summary.expense, isIncome: summary.income >= summary.expense)}',
    );

    // 2. 日均支出 + 最大支出类别
    if (summary.expense > 0) {
      final days = DateTime(month.year, month.month + 1, 0).day;
      final daily = summary.expense / days;
      final top = _topCategory(breakdown);
      final dailyStr = daily < 10 ? daily.toStringAsFixed(1) : daily.round().toString();
      final tail = top != null
          ? '，花销最多的是「${top.category}」（${(top.amount / summary.expense * 100).round()}%）'
          : '';
      lines.add('日均支出 ¥$dailyStr$tail');
    }

    // 3. 与上月对比（支出）
    final prev = _prevMonthSummary(month, all);
    if (prev.expense > 0) {
      final diff = (summary.expense - prev.expense) / prev.expense;
      final label = diff.abs() < 0.005
          ? '支出与上月基本持平'
          : diff > 0
              ? '支出较上月上升 ${(diff * 100).round()}%'
              : '支出较上月下降 ${(diff.abs() * 100).round()}%';
      lines.add(label);
    } else if (summary.expense > 0) {
      lines.add('上月没有支出记录，本月是新的开始');
    }

    // 4. 与上月对比（收入）——自由职业者关注现金流
    if (summary.income > 0 && prev.income > 0) {
      final diff = (summary.income - prev.income) / prev.income;
      if (diff.abs() >= 0.005) {
        lines.add(
          diff > 0
              ? '收入较上月上升 ${(diff * 100).round()}%'
              : '收入较上月下降 ${(diff.abs() * 100).round()}%',
        );
      }
    } else if (summary.income > 0 && prev.income <= 0) {
      lines.add('本月首次有收入记录');
    }
    return lines;
  }

  CategorySlice? _topCategory(List<CategorySlice> breakdown) {
    if (breakdown.isEmpty) return null;
    CategorySlice? top;
    for (final s in breakdown) {
      if (top == null || s.amount > top.amount) top = s;
    }
    return top;
  }

  /// 计算上月收支（从全部流水现算，避免为单卡片维护额外 provider）
  MonthSummary _prevMonthSummary(
      DateTime month, List<TransactionEntry> all) {
    final y = month.month == 1 ? month.year - 1 : month.year;
    final m = month.month == 1 ? 12 : month.month - 1;
    var income = 0.0, expense = 0.0;
    for (final e in all) {
      if (e.date.year == y && e.date.month == m) {
        if (e.isIncome) {
          income += e.amount;
        } else {
          expense += e.amount;
        }
      }
    }
    return MonthSummary(income: income, expense: expense);
  }
}
