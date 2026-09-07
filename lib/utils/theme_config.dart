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
  });

  final String id;
  final String name;
  final Color gradientStart;
  final Color gradientEnd;
  final Color blob1;
  final Color blob2;
}

/// 预置背景主题与持久化配置
class ThemeConfig {
  ThemeConfig._();

  static const String prefKey = 'background_theme_id';

  /// 自定义背景图片（持久化为图片文件路径，存于应用文档目录）
  static const String customBgKey = 'custom_background_path';

  static const List<BackgroundTheme> backgrounds = [
    BackgroundTheme(
      id: 'mint',
      name: '青绿',
      gradientStart: Color(0xFFF6F3EC),
      gradientEnd: Color(0xFFE8F1EE),
      blob1: Color(0xFF14B8A6),
      blob2: Color(0xFFE8C9A0),
    ),
    BackgroundTheme(
      id: 'sun',
      name: '暖阳',
      gradientStart: Color(0xFFFBF6EC),
      gradientEnd: Color(0xFFF6E8D8),
      blob1: Color(0xFFF0A868),
      blob2: Color(0xFFF3D9B1),
    ),
    BackgroundTheme(
      id: 'mist',
      name: '雾蓝',
      gradientStart: Color(0xFFEFF4FA),
      gradientEnd: Color(0xFFE3ECF7),
      blob1: Color(0xFF7CA8E8),
      blob2: Color(0xFFB9CDE8),
    ),
    BackgroundTheme(
      id: 'blossom',
      name: '樱粉',
      gradientStart: Color(0xFFFAF2F4),
      gradientEnd: Color(0xFFF5E6EC),
      blob1: Color(0xFFE8A0B8),
      blob2: Color(0xFFF2CDD9),
    ),
    BackgroundTheme(
      id: 'jade',
      name: '墨玉',
      gradientStart: Color(0xFFEFF3EF),
      gradientEnd: Color(0xFFDEE9E0),
      blob1: Color(0xFF4C8C6E),
      blob2: Color(0xFFA9C4B2),
    ),
  ];

  static BackgroundTheme byId(String id) {
    for (final t in backgrounds) {
      if (t.id == id) return t;
    }
    return backgrounds.first;
  }
}
