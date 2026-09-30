// CategoryUtils 纯逻辑单元测试：图标/颜色映射与按名查找
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/models/category_model.dart';
import 'package:smart_ledger/utils/category_utils.dart';

Category _cat(String name, {String icon = 'other', int color = 0xFFA0AEC0}) =>
    Category(
      id: 1,
      name: name,
      icon: icon,
      color: color,
      isIncome: false,
      isSystem: true,
      sortOrder: 0,
    );

void main() {
  group('CategoryUtils.iconOf', () {
    test('已知图标键返回对应 Material 图标', () {
      expect(CategoryUtils.iconOf('restaurant'), Icons.restaurant_rounded);
      expect(CategoryUtils.iconOf('transport'), Icons.directions_bus_rounded);
    });

    test('未知图标键回退到「其他」图标', () {
      expect(CategoryUtils.iconOf('not-exists'), Icons.category_rounded);
    });

    test('iconOfCategory 与 colorOfCategory 读取分类字段', () {
      final c = _cat('餐饮', icon: 'restaurant', color: 0xFFF6AD55);
      expect(CategoryUtils.iconOfCategory(c), Icons.restaurant_rounded);
      expect(CategoryUtils.colorOfCategory(c), const Color(0xFFF6AD55));
    });
  });

  group('CategoryUtils.byName', () {
    final cats = [_cat('餐饮'), _cat('购物'), _cat('其他')];

    test('按名称精确匹配', () {
      expect(CategoryUtils.byName(cats, '购物')?.name, '购物');
    });

    test('找不到时返回 null', () {
      expect(CategoryUtils.byName(cats, '不存在'), isNull);
    });
  });
}
