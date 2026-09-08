import 'package:intl/intl.dart';

/// 金额与日期格式化工具
class FormatUtils {
  FormatUtils._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

  /// 1234.5 -> ¥1,234.50
  static String money(double amount) => '¥${_money.format(amount)}';

  /// 带符号金额：收入 +¥x，支出 -¥x
  static String signedMoney(double amount, {required bool isIncome}) =>
      '${isIncome ? '+' : '-'}${money(amount.abs())}';

  /// -> 9/6
  static String dayLabel(DateTime d) => DateFormat('M/d').format(d);

  /// -> 2026年9月
  static String monthTitle(DateTime m) => DateFormat('yyyy年M月').format(m);

  /// -> 2026-09-06
  static String fullDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// -> 9月6日
  static String monthDay(DateTime d) => DateFormat('M月d日').format(d);

  /// 紧凑金额：>=10000 显示 x.x万；否则保留两位小数
  static String compactMoney(double amount) {
    final abs = amount.abs();
    if (abs >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return _money.format(amount);
  }

  /// 导出文件名用：20260906_153000
  static String fileStamp(DateTime d) => DateFormat('yyyyMMdd_HHmmss').format(d);
}
