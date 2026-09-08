import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';

/// 周期记账规则：每月固定入账/支出（房租、生活费、工资、订阅等）
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.name,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.dayOfMonth,
    required this.nextDue,
    this.note = '',
  });

  final String id;
  final String name;
  final double amount;
  final bool isIncome;
  final String category;

  /// 每月第几天（1~28，避免 29-31 在短月份的溢出问题）
  final int dayOfMonth;

  /// 下次应生成日期（含）
  final DateTime nextDue;
  final String note;

  RecurringRule copyWith({DateTime? nextDue}) {
    return RecurringRule(
      id: id,
      name: name,
      amount: amount,
      isIncome: isIncome,
      category: category,
      dayOfMonth: dayOfMonth,
      nextDue: nextDue ?? this.nextDue,
      note: note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'isIncome': isIncome,
        'category': category,
        'dayOfMonth': dayOfMonth,
        'nextDue': nextDue.millisecondsSinceEpoch,
        'note': note,
      };

  static RecurringRule fromJson(Map<String, dynamic> m) {
    return RecurringRule(
      id: m['id'] as String,
      name: m['name'] as String,
      amount: (m['amount'] as num).toDouble(),
      isIncome: m['isIncome'] as bool,
      category: m['category'] as String,
      dayOfMonth: (m['dayOfMonth'] as num).toInt(),
      nextDue:
          DateTime.fromMillisecondsSinceEpoch((m['nextDue'] as num).toInt()),
      note: m['note'] as String? ?? '',
    );
  }
}

/// 周期记账规则持久化与到期生成（纯本地，无网络依赖）
class RecurringService {
  RecurringService._();

  static const String _key = 'recurring_rules';

  static Future<List<RecurringRule>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final rules = <RecurringRule>[];
      for (final e in list) {
        try {
          rules.add(RecurringRule.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // 单条解析失败跳过，不阻断其余规则
        }
      }
      return rules;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<RecurringRule> rules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(rules.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  /// 检查所有到期规则并推进日期。
  /// 注意：为避免“推进了规则但入账失败导致漏记”，本方法只返回结果，
  /// 调用方确认流水全部写入成功后再调用 [commitRules] 持久化推进。
  static Future<ProcessResult> processDue() async {
    final rules = await load();
    if (rules.isEmpty) {
      return const ProcessResult(due: [], rules: []);
    }
    return processRules(rules, DateTime.now());
  }

  /// 入账成功后将推进后的规则持久化
  static Future<void> commitRules(List<RecurringRule> rules) async {
    await save(rules);
  }

  /// 纯函数核心：给定规则与“今天”，返回应记条目与推进后的规则。
  /// 独立出来便于单元测试（不依赖 SharedPreferences 插件）。
  static ProcessResult processRules(List<RecurringRule> rules, DateTime today) {
    final due = <TransactionEntry>[];
    final updated = <RecurringRule>[];

    for (var rule in rules) {
      var guard = 0;
      // 补记所有到期月份（最多 36 次，防止异常循环）
      while (!rule.nextDue.isAfter(today) && guard < 36) {
        due.add(TransactionEntry(
          amount: rule.amount,
          type: rule.isIncome
              ? TransactionType.income
              : TransactionType.expense,
          category: rule.category,
          date: rule.nextDue,
          note: rule.note.isEmpty ? '周期：${rule.name}' : rule.note,
        ));
        rule = rule.copyWith(nextDue: _nextMonthSameDay(rule.nextDue));
        guard++;
      }
      updated.add(rule);
    }
    due.sort((a, b) => a.date.compareTo(b.date));
    return ProcessResult(due: due, rules: updated);
  }

  /// 下月同一天（短月自动落到月末，如 1/31 → 2/28 或 2/29）
  static DateTime _nextMonthSameDay(DateTime d) {
    final y = d.month == 12 ? d.year + 1 : d.year;
    final m = d.month == 12 ? 1 : d.month + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
  }
}

/// 周期规则处理结果
class ProcessResult {
  const ProcessResult({required this.due, required this.rules});

  final List<TransactionEntry> due;
  final List<RecurringRule> rules;
}
