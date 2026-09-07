import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

// ==================== 全局筛选状态 ====================

/// 仪表盘当前月份（默认当月）
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 统计页时间范围（天）：7 或 30
final trendRangeProvider = StateProvider<int>((ref) => 7);

/// 统计页分类筛选（null = 全部；值为分类名称）
final trendCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// 分类表版本号：分类增删改后自增，触发 categoriesProvider 与相关界面刷新
final categoryVersionProvider = StateProvider<int>((ref) => 0);

/// 预算版本号：预算设置/清除后自增
final budgetVersionProvider = StateProvider<int>((ref) => 0);

/// 月份 key（'yyyy-MM'）
String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

// ==================== 核心数据源 ====================

/// 全量流水（从数据库加载；增、删、改、导入后自动刷新）
class TransactionListNotifier
    extends StateNotifier<AsyncValue<List<TransactionEntry>>> {
  TransactionListNotifier() : super(const AsyncValue.loading()) {
    reload();
  }

  Future<void> reload() async {
    try {
      final list = await DatabaseService.instance.listAll();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(TransactionEntry entry) async {
    await DatabaseService.instance.insert(entry);
    await reload();
  }

  Future<void> update(int id, TransactionEntry entry) async {
    await DatabaseService.instance.update(id, entry);
    await reload();
  }

  Future<void> remove(int id) async {
    await DatabaseService.instance.delete(id);
    await reload();
  }

  Future<void> importAll(List<TransactionEntry> entries) async {
    await DatabaseService.instance.insertAll(entries);
    await reload();
  }
}

final transactionListProvider = StateNotifierProvider<
    TransactionListNotifier, AsyncValue<List<TransactionEntry>>>(
  (ref) => TransactionListNotifier(),
);

/// 分类列表（来自数据库；分类增删改后自动刷新）
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(categoryVersionProvider);
  return DatabaseService.instance.listCategories();
});

/// 支出分类（按 sortOrder 排序）
final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final all = await ref.watch(categoriesProvider.future);
  return all.where((c) => !c.isIncome).toList();
});

/// 收入分类
final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final all = await ref.watch(categoriesProvider.future);
  return all.where((c) => c.isIncome).toList();
});

/// 分类名 -> 分类 的查找映射（供 UI 取图标/颜色）
final categoryMapProvider = FutureProvider<Map<String, Category>>((ref) async {
  final all = await ref.watch(categoriesProvider.future);
  return {for (final c in all) c.name: c};
});

/// 当前选中月份的预算金额（null = 未设置）
final budgetProvider = FutureProvider<double?>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  ref.watch(budgetVersionProvider);
  return DatabaseService.instance.getBudget(monthKey(month));
});

/// 本月支出分类排行：金额、占比、上月环比
class CategoryRankItem {
  const CategoryRankItem({
    required this.category,
    required this.amount,
    required this.prevAmount,
    required this.percent,
  });

  final String category;
  final double amount;
  final double prevAmount;
  final double percent; // 占本月总支出百分比
}

final categoryRankingProvider = Provider<List<CategoryRankItem>>((ref) {
  final list = ref.watch(transactionListProvider).value ?? const [];
  final month = ref.watch(selectedMonthProvider);
  final prev = DateTime(month.year, month.month - 1);

  final cur = <String, double>{};
  final prevAmt = <String, double>{};
  for (final e in list) {
    if (e.isIncome) continue;
    if (e.date.year == month.year && e.date.month == month.month) {
      cur[e.category] = (cur[e.category] ?? 0) + e.amount;
    } else if (e.date.year == prev.year && e.date.month == prev.month) {
      prevAmt[e.category] = (prevAmt[e.category] ?? 0) + e.amount;
    }
  }
  final total = cur.values.fold(0.0, (a, b) => a + b);
  if (total == 0) return const [];

  final items = cur.entries
      .map((e) => CategoryRankItem(
            category: e.key,
            amount: e.value,
            prevAmount: prevAmt[e.key] ?? 0,
            percent: e.value / total * 100,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return items;
});

// ==================== 派生数据（View 消费） ====================

/// 月份收支摘要
class MonthSummary {
  const MonthSummary({required this.income, required this.expense});

  final double income;
  final double expense;

  double get balance => income - expense;
}

final monthSummaryProvider = Provider<MonthSummary>((ref) {
  final list = ref.watch(transactionListProvider).value ?? const [];
  final month = ref.watch(selectedMonthProvider);

  var income = 0.0, expense = 0.0;
  for (final e in list) {
    if (e.date.year == month.year && e.date.month == month.month) {
      if (e.isIncome) {
        income += e.amount;
      } else {
        expense += e.amount;
      }
    }
  }
  return MonthSummary(income: income, expense: expense);
});

/// 分类占比切片
class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.amount,
    required this.percent,
  });

  /// 分类名称
  final String category;
  final double amount;
  final double percent; // 0 - 100
}

/// 当月消费分类占比（仅支出，按金额降序）
final categoryBreakdownProvider = Provider<List<CategorySlice>>((ref) {
  final list = ref.watch(transactionListProvider).value ?? const [];
  final month = ref.watch(selectedMonthProvider);

  final totals = <String, double>{};
  for (final e in list) {
    if (e.isIncome) continue;
    if (e.date.year == month.year && e.date.month == month.month) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
  }
  final total = totals.values.fold(0.0, (a, b) => a + b);
  if (total == 0) return const [];

  return totals.entries
      .map((e) => CategorySlice(
            category: e.key,
            amount: e.value,
            percent: e.value / total * 100,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
});

/// 最近 5 条流水
final recentTransactionsProvider = Provider<List<TransactionEntry>>((ref) {
  final list = ref.watch(transactionListProvider).value ?? const [];
  return list.take(5).toList();
});

/// 每日趋势点
class DailyPoint {
  const DailyPoint({required this.day, required this.expense});

  final DateTime day;
  final double expense;
}

/// 近 N 天每日支出趋势（始终统计支出；可按分类筛选）
final dailyTrendProvider = Provider<List<DailyPoint>>((ref) {
  final list = ref.watch(transactionListProvider).value ?? const [];
  final days = ref.watch(trendRangeProvider);
  final filter = ref.watch(trendCategoryFilterProvider);

  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day)
      .add(const Duration(days: 1));
  final start = end.subtract(Duration(days: days));

  final buckets = <String, double>{};
  for (final e in list) {
    if (e.isIncome) continue;
    if (filter != null && e.category != filter) continue;
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    if (day.isBefore(start) || !day.isBefore(end)) continue;
    final key = '${day.year}-${day.month}-${day.day}';
    buckets[key] = (buckets[key] ?? 0) + e.amount;
  }

  return [
    for (var i = 0; i < days; i++)
      () {
        final day = start.add(Duration(days: i));
        final key = '${day.year}-${day.month}-${day.day}';
        return DailyPoint(day: day, expense: buckets[key] ?? 0);
      }(),
  ];
});

/// 趋势筛选对应的明细流水（时间倒序）
final trendDetailProvider = Provider<List<TransactionEntry>>((ref) {
  final list = ref.watch(transactionListProvider).value ?? const [];
  final days = ref.watch(trendRangeProvider);
  final filter = ref.watch(trendCategoryFilterProvider);

  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day)
      .add(const Duration(days: 1));
  final start = end.subtract(Duration(days: days));

  return list
      .where((e) => !e.isIncome)
      .where((e) => filter == null || e.category == filter)
      .where((e) {
        final day = DateTime(e.date.year, e.date.month, e.date.day);
        return !day.isBefore(start) && day.isBefore(end);
      })
      .toList();
});

// ==================== 数据库信息（备份/恢复页） ====================

/// 数据库基本信息：Schema 版本 + 流水条数
class DbInfo {
  const DbInfo({required this.version, required this.count});

  final int version;
  final int count;
}

final dbInfoProvider = FutureProvider<DbInfo>((ref) async {
  final db = await DatabaseService.instance.database;
  final versionRows = await db.rawQuery('PRAGMA user_version');
  final version = (versionRows.first['user_version'] as int?) ?? 0;
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
  final count = (rows.first['c'] as int?) ?? 0;
  return DbInfo(version: version, count: count);
});
