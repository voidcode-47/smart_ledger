import 'package:flutter/material.dart';

/// 全局主题与设计常量
/// 风格：清爽浅色记账风（米白底 + 青绿主色 + 白色卡片）
class AppTheme {
  AppTheme._();

  // ---------- 页面背景渐变（浅色柔和） ----------
  static const Color gradientStart = Color(0xFFF6F3EC); // 暖米白
  static const Color gradientEnd = Color(0xFFE8F1EE); // 淡青
  static const List<Color> gradient = [gradientStart, gradientEnd];

  // ---------- 主色（青绿） ----------
  static const Color accent = Color(0xFF0F766E); // teal-700（深青绿）
  static const Color accentLight = Color(0xFF14B8A6);
  static const Color accentBg = Color(0xFFE6F4F1); // 主色浅底

  // ---------- 文字色 ----------
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // ---------- 卡片与分割 ----------
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFEDEDE8);
  static const Color fieldBg = Color(0xFFF2F1EC);

  // ---------- 语义色 ----------
  static const Color incomeColor = Color(0xFF16A34A); // 沉稳绿
  static const Color expenseColor = Color(0xFFDC2626); // 自然红

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textHint),
        prefixIconColor: textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF374151),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: dividerColor,
    );
  }
}

/// 常用文字样式
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle pageTitle =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
  static const TextStyle sectionTitle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle hint =
      TextStyle(color: AppTheme.textHint, fontSize: 12);
}
