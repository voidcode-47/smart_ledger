import 'package:flutter/material.dart';

/// 全局主题与设计常量
///
/// 设计语言：数字优先（参考 Linear / Things 3）
/// - 纯色背景，无渐变光斑
/// - teal 主色仅用于关键交互、Hero 数字、语义色
/// - 用字重 + 字号建立层次，不用阴影/渐变/模糊
/// - 一个 signature moment（仪表盘 Hero 大数字），其他全部克制
class AppTheme {
  AppTheme._();

  static bool _dark = false;

  /// 是否为深色模式（黑色背景主题开启时为 true）
  static bool get isDark => _dark;

  /// 由应用根部在背景主题变化时调用，切换全局深色色板
  static void setDark(bool v) => _dark = v;

  // ---------- 页面背景（纯色，无渐变） ----------
  /// 页面背景：浅色 #FAFAFA / 深色 #0A0A0A
  static Color get background =>
      _dark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);

  /// 卡片表面：浅色 #FFFFFF / 深色 #141414
  static Color get surface =>
      _dark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);

  // ---------- 主色（teal，仅按钮/选中/Hero/语义） ----------
  static const Color accent = Color(0xFF0F766E); // teal-700
  static const Color accentLight = Color(0xFF14B8A6);
  static Color get accentBg =>
      _dark ? const Color(0xFF1E3B36) : const Color(0xFFE6F4F1);

  // ---------- 文字色（中性色驱动层次） ----------
  static Color get textPrimary =>
      _dark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A);
  static Color get textSecondary =>
      _dark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);
  static Color get textHint =>
      _dark ? const Color(0xFF737373) : const Color(0xFFA3A3A3);

  /// 背景/表面上的文字取色：深色模式反白
  static Color onSurface({double alpha = 1.0}) =>
      (_dark ? Colors.white : Colors.black).withValues(alpha: alpha);

  /// 禁用态按钮/组件的底色
  static Color get disabledBg => _dark
      ? Colors.white.withValues(alpha: 0.14)
      : AppTheme.onSurface(alpha: 0.15);

  // ---------- 卡片与分割 ----------
  /// 卡片色（= surface，纯色无装饰）
  static Color get cardColor => surface;
  static Color get dividerColor =>
      _dark ? const Color(0xFF262626) : const Color(0xFFE5E5E5);

  // ---------- 输入框背景 ----------
  static Color get fieldBg =>
      _dark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

  // ---------- 语义色 ----------
  static Color get incomeColor =>
      _dark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
  static Color get expenseColor =>
      _dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  // ---------- 兼容层（旧 glass* API 退化为纯色，避免编译错误） ----------
  /// 旧 glassFill：退化为 cardColor（纯色，无半透明）
  static Color get glassFill => cardColor;
  /// 旧 glassFillStrong：退化为 cardColor
  static Color get glassFillStrong => cardColor;
  /// 旧 glassBorder：退化为 dividerColor（1px 描边）
  static Color get glassBorder => dividerColor;
  /// 旧 glassBlurSigma：保留常量但 GlassCard 不再用
  static const double glassBlurSigma = 0;
  /// 旧 glassShadow：退化为空（无阴影）
  static List<BoxShadow> get glassShadow => const [];
  /// 旧 accentGradient：退化为纯 teal（无渐变）
  static const List<Color> accentGradient = [accent, accent];
  /// 旧 accentGlow：退化为透明（无发光）
  static const Color accentGlow = Color(0x00000000);

  // ---------- 页面背景渐变（gradient_background 仍用，但改纯色） ----------
  static Color get gradientStart => background;
  static Color get gradientEnd => background;
  static List<Color> get gradient => [gradientStart, gradientEnd];

  static ThemeData theme() => _build(Brightness.light);

  /// 深色模式（黑色背景主题时使用）
  static ThemeData darkTheme() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F766E),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: dark ? const Color(0xFFFAFAFA) : textPrimary,
        displayColor: dark ? const Color(0xFFFAFAFA) : textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A1A1A) : fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle:
            TextStyle(color: dark ? const Color(0xFF737373) : textHint),
        prefixIconColor:
            dark ? const Color(0xFFA3A3A3) : textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            dark ? const Color(0xFFE5E7EB) : const Color(0xFF141414),
        contentTextStyle: TextStyle(
            color: dark ? const Color(0xFF0A0A0A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF141414) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: dark ? const Color(0xFF262626) : dividerColor,
    );
  }
}

/// 常用文字样式（数字优先排版）
class AppTextStyles {
  AppTextStyles._();

  /// Hero 大数字（仪表盘结余）：56sp w800 tabular nums
  static const TextStyle displayNumber = TextStyle(
    fontSize: 50,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// H1 页面标题：28sp w700
  static const TextStyle pageTitle =
      TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5);

  /// H2 区块标题：18sp w700
  static const TextStyle sectionTitle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  /// Caption 小标签：11sp w500 灰色
  static TextStyle get caption => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
      );

  /// Numeric 金额：16sp w600 tabular nums
  static const TextStyle numeric = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle get hint =>
      TextStyle(color: AppTheme.textHint, fontSize: 13);
}
