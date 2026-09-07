import 'package:flutter/material.dart';

import '../models/category_model.dart';
import 'app_theme.dart';

/// 分类 → 图标 / 颜色 的数据驱动工具
/// 分类本身存于数据库（categories 表），此处提供：
/// - 图标键 → Material 图标 的静态映射
/// - 预置色板（分类管理时可挑选）
/// - 按分类记录取色/取图标的辅助方法
class CategoryUtils {
  CategoryUtils._();

  /// 图标键 -> 图标。新增分类时可选这些图标。
  static const Map<String, IconData> iconMap = {
    'restaurant': Icons.restaurant_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'transport': Icons.directions_bus_rounded,
    'entertainment': Icons.sports_esports_rounded,
    'other': Icons.category_rounded,
    'income': Icons.savings_rounded,
    'home': Icons.home_rounded,
    'school': Icons.school_rounded,
    'medical': Icons.medical_services_rounded,
    'movie': Icons.movie_rounded,
    'flight': Icons.flight_rounded,
    'pets': Icons.pets_rounded,
    'fitness': Icons.fitness_center_rounded,
    'coffee': Icons.coffee_rounded,
    'phone': Icons.phone_android_rounded,
    'gift': Icons.card_giftcard_rounded,
    'book': Icons.menu_book_rounded,
    'star': Icons.star_rounded,
  };

  /// 预置色板（ARGB），分类管理时可挑选。
  static const List<int> palette = [
    0xFFF6AD55, // 橙
    0xFF63B3ED, // 蓝
    0xFF68D391, // 绿
    0xFFF687B3, // 粉
    0xFFB794F4, // 紫
    0xFFF56565, // 红
    0xFF4FD1C5, // 青
    0xFFED8936, // 深橙
    0xFFA0AEC0, // 灰
    0xFF48BB78, // 草绿
  ];

  /// 收入分类默认色
  static Color get incomeColor => AppTheme.incomeColor;

  /// 收入分类默认图标
  static IconData get incomeIcon => Icons.savings_rounded;

  /// 图标键 -> 图标（未知键回退为“其他”图标）
  static IconData iconOf(String iconKey) =>
      iconMap[iconKey] ?? Icons.category_rounded;

  /// ARGB 值 -> Color
  static Color colorOfValue(int argb) => Color(argb);

  /// 按分类记录取图标
  static IconData iconOfCategory(Category c) => iconOf(c.icon);

  /// 按分类记录取颜色
  static Color colorOfCategory(Category c) => colorOfValue(c.color);

  /// 按名称在分类列表中查找；找不到返回 null
  static Category? byName(List<Category> categories, String name) {
    for (final c in categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// 未知分类的兜底样式（灰色 + “其他”图标）
  static IconData get fallbackIcon => Icons.category_rounded;
  static Color get fallbackColor => colorOfValue(0xFFA0AEC0);
}
