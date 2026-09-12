import 'package:flutter/material.dart';

/// 一套背景主题（页面渐变 + 柔光斑配色）
class BackgroundTheme {
  const BackgroundTheme({
    required this.id,
    required this.name,
    required this.gradientStart,
    required this.gradientEnd,
    required this.blob1,
    required this.blob2,
    this.isDark = false,
  });

  final String id;
  final String name;
  final Color gradientStart;
  final Color gradientEnd;
  final Color blob1;
  final Color blob2;

  /// 是否为深色背景（用于决定背景上文字/图标的取色）
  final bool isDark;
}

/// 预置背景主题与持久化配置
class ThemeConfig {
  ThemeConfig._();

  static const String prefKey = 'background_theme_id';

  /// 自定义背景图片（旧版单图路径 key，已迁移到 items key）
  static const String customBgKey = 'custom_background_path';

  /// 自定义背景集合（JSON：id/path/opacity）与当前激活项
  static const String customBgItemsKey = 'custom_background_items';
  static const String customBgActiveKey = 'custom_background_active';

  /// 精简为两套主题：白色 / 黑色。
  /// 旧版本保存的主题 id（青绿/暖阳/雾蓝/樱粉/墨玉）在 [byId] 中统一回退到白色。
  static const List<BackgroundTheme> backgrounds = [
    BackgroundTheme(
      id: 'white',
      name: '白色',
      gradientStart: Color(0xFFFFFFFF),
      gradientEnd: Color(0xFFF3F4F6),
      blob1: Color(0xFFE5EDF2),
      blob2: Color(0xFFF2EFE8),
    ),
    BackgroundTheme(
      id: 'black',
      name: '黑色',
      isDark: true,
      gradientStart: Color(0xFF212226),
      gradientEnd: Color(0xFF141518),
      blob1: Color(0xFF2B2D33),
      blob2: Color(0xFF24262B),
    ),
  ];

  static BackgroundTheme byId(String id) {
    for (final t in backgrounds) {
      if (t.id == id) return t;
    }
    // 未知/旧版主题 id 统一回退到白色
    return backgrounds.first;
  }

  /// 背景之上的文字/图标取色：黑色背景反白，保证可读
  static Color onBackground(bool isDark, {double alpha = 0.80}) {
    return (isDark ? Colors.white : Colors.black).withValues(alpha: alpha);
  }
}
