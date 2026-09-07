/// 用户可自定义的记账分类（数据库 categories 表）
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isIncome,
    required this.isSystem,
    required this.sortOrder,
  });

  /// 数据库主键
  final int id;

  /// 分类名（唯一；流水的 category 字段直接存此名称）
  final String name;

  /// 图标键（映射见 CategoryUtils.iconMap）
  final String icon;

  /// 颜色 ARGB 值
  final int color;

  /// 是否为收入分类
  final bool isIncome;

  /// 是否为内置分类（内置分类不可删除，可改名）
  final bool isSystem;

  /// 排序序号（小在前）
  final int sortOrder;

  Category copyWith({
    String? name,
    String? icon,
    int? color,
    bool? isIncome,
    bool? isSystem,
    int? sortOrder,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isIncome: isIncome ?? this.isIncome,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toDbMap() => {
        'name': name,
        'icon': icon,
        'color': color,
        'isIncome': isIncome ? 1 : 0,
        'isSystem': isSystem ? 1 : 0,
        'sortOrder': sortOrder,
      };

  factory Category.fromDbMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      isIncome: (map['isIncome'] as int) == 1,
      isSystem: (map['isSystem'] as int) == 1,
      sortOrder: map['sortOrder'] as int,
    );
  }

  @override
  String toString() => 'Category(id: $id, $name, income: $isIncome, sys: $isSystem)';
}
