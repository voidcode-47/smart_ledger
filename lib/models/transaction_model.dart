/// 交易类型
enum TransactionType { expense, income }

/// 一条流水记录
/// category 字段存储分类名称（对应 categories 表的 name，自定义分类支持）
class TransactionEntry {
  const TransactionEntry({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
  });

  /// 数据库主键，新建时为 null
  final int? id;

  /// 金额，恒为正数
  final double amount;
  final TransactionType type;

  /// 分类名称（用户可自定义，如“餐饮”“房租”）
  final String category;

  /// 记账日期（含时间）
  final DateTime date;
  final String note;

  bool get isIncome => type == TransactionType.income;

  /// 净额：收入为正，支出为负
  double get signedAmount => isIncome ? amount : -amount;

  TransactionEntry copyWith({
    int? id,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
  }) {
    return TransactionEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toDbMap() => {
        'amount': amount,
        'isIncome': isIncome ? 1 : 0,
        'category': category,
        'note': note,
        'createdAt': date.millisecondsSinceEpoch,
      };

  factory TransactionEntry.fromDbMap(Map<String, Object?> map) {
    return TransactionEntry(
      id: map['id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: (map['isIncome'] as int) == 1
          ? TransactionType.income
          : TransactionType.expense,
      category: (map['category'] as String?) ?? '其他',
      note: (map['note'] as String?) ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  @override
  String toString() =>
      'TransactionEntry(id: $id, $category, $amount, ${isIncome ? '收入' : '支出'}, $date)';
}

/// 兼容旧版 CSV / 旧数据库中的枚举分类名：映射为 v2 默认中文分类名。
/// 例如 food → 餐饮；无法识别的值原样返回。
String legacyCategoryName(String key) {
  switch (key.trim()) {
    case 'food':
      return '餐饮';
    case 'shopping':
      return '购物';
    case 'transport':
      return '交通';
    case 'entertainment':
      return '娱乐';
    case 'other':
      return '其他';
    default:
      return key.trim().isEmpty ? '其他' : key.trim();
  }
}
