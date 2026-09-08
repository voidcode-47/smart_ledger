import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/models/transaction_model.dart';
import 'package:smart_ledger/services/recurring_service.dart';

RecurringRule _rule({
  String id = 'r1',
  String name = '房租',
  double amount = 1500,
  bool isIncome = false,
  String category = '居住',
  int day = 1,
  required DateTime nextDue,
}) {
  return RecurringRule(
    id: id,
    name: name,
    amount: amount,
    isIncome: isIncome,
    category: category,
    dayOfMonth: day,
    nextDue: nextDue,
    note: '',
  );
}

void main() {
  group('RecurringService.processRules', () {
    test('未到期规则不生成任何流水', () {
      final today = DateTime(2026, 9, 8);
      final r = _rule(nextDue: DateTime(2026, 10, 1));
      final result = RecurringService.processRules([r], today);
      expect(result.due, isEmpty);
      expect(result.rules.single.nextDue, DateTime(2026, 10, 1));
    });

    test('到期规则生成一笔并推进到下月', () {
      final today = DateTime(2026, 9, 8);
      final r = _rule(amount: 1500, nextDue: DateTime(2026, 9, 1));
      final result = RecurringService.processRules([r], today);
      expect(result.due, hasLength(1));
      final e = result.due.single;
      expect(e.amount, 1500);
      expect(e.type, TransactionType.expense);
      expect(e.date, DateTime(2026, 9, 1));
      expect(e.note, '周期：房租');
      // 下次推进到 10 月 1 日
      expect(result.rules.single.nextDue, DateTime(2026, 10, 1));
    });

    test('收入类型正确标记', () {
      final today = DateTime(2026, 9, 8);
      final r = _rule(
          isIncome: true,
          name: '工资',
          category: '工资',
          nextDue: DateTime(2026, 9, 5));
      final result = RecurringService.processRules([r], today);
      expect(result.due.single.type, TransactionType.income);
    });

    test('错过多月会补记所有到期月份（升序）', () {
      final today = DateTime(2026, 9, 8);
      // 上次生成在 7 月：8 月、9 月两笔到期
      final r = _rule(nextDue: DateTime(2026, 8, 1));
      final result = RecurringService.processRules([r], today);
      expect(result.due, hasLength(2));
      expect(result.due[0].date, DateTime(2026, 8, 1));
      expect(result.due[1].date, DateTime(2026, 9, 1));
      expect(result.rules.single.nextDue, DateTime(2026, 10, 1));
    });

    test('短月顺延：1/31 的下月为 2/28 或 2/29', () {
      final today = DateTime(2026, 3, 1);
      final r = _rule(nextDue: DateTime(2026, 1, 31));
      final result = RecurringService.processRules([r], today);
      // 1/31 到期 → 2/28（2026 非闰年）→ 3/28（到期日 3/1 前）
      expect(result.due, hasLength(2));
      expect(result.due[0].date, DateTime(2026, 1, 31));
      expect(result.due[1].date, DateTime(2026, 2, 28));
      expect(result.rules.single.nextDue, DateTime(2026, 3, 28));
    });

    test('同日生成：到期日等于今天也会入账', () {
      final today = DateTime(2026, 9, 8);
      final r = _rule(nextDue: DateTime(2026, 9, 8));
      final result = RecurringService.processRules([r], today);
      expect(result.due, hasLength(1));
    });

    test('跨年推进正确', () {
      final today = DateTime(2027, 1, 5);
      final r = _rule(nextDue: DateTime(2026, 12, 1));
      final result = RecurringService.processRules([r], today);
      expect(result.due, hasLength(2));
      expect(result.due[0].date, DateTime(2026, 12, 1));
      expect(result.due[1].date, DateTime(2027, 1, 1));
      expect(result.rules.single.nextDue, DateTime(2027, 2, 1));
    });

    test('异常规则最多补记 36 次后停止', () {
      final today = DateTime(2099, 1, 1);
      final r = _rule(nextDue: DateTime(2000, 1, 1));
      final result = RecurringService.processRules([r], today);
      expect(result.due.length, 36);
    });
  });
}
