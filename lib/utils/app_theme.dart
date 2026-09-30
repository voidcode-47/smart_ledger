import 'package:flutter/material.dart';

/// 全局主题与设计常量
/// 风格：清爽浅色记账风（米白底 + 青绿主色 + 白色卡片）
///
/// 深色模式：由 [setDark] 全局切换（黑色背景主题触发），
/// 所有颜色字段均为动态 getter，深色下自动取深色值，
/// 页面无需逐处感知主题即可整体适配。
class AppTheme {
  AppTheme._();

  static bool _dark = false;

  /// 是否为深色模式（黑色背景主题开启时为 true）
  static bool get isDark => _dark;

  /// 由应用根部在背景主题变化时调用，切换全局深色色板
  static void setDark(bool v) => _dark = v;

  // ---------- 页面背景渐变（浅色柔和 / 深色沉稳） ----------
  static Color get gradientStart =>
      _dark ? const Color(0xFF23262C) : const Color(0xFFF6F3EC);
  static Color get gradientEnd =>
      _dark ? const Color(0xFF16191E) : const Color(0xFFE8F1EE);
  static List<Color> get gradient => [gradientStart, gradientEnd];

  // ---------- 主色（青绿） ----------
  static const Color accent = Color(0xFF0F766E); // teal-700（深青绿）
  static const Color accentLight = Color(0xFF14B8A6);
  static Color get accentBg =>
      _dark ? const Color(0xFF1E3B36) : const Color(0xFFE6F4F1); // 主色浅底

  // ---------- 文字色 ----------
  static Color get textPrimary =>
      _dark ? const Color(0xFFE8EBF0) : const Color(0xFF1F2937);
  static Color get textSecondary =>
      _dark ? const Color(0xFFB4BBC8) : const Color(0xFF6B7280);
  static Color get textHint =>
      _dark ? const Color(0xFF7A8191) : const Color(0xFF9CA3AF);

  /// 背景/表面上的文字取色（辅助说明文字等）：深色模式反白
  static Color onSurface({double alpha = 1.0}) =>
      (_dark ? Colors.white : Colors.black).withValues(alpha: alpha);

  /// 禁用态按钮/组件的底色
  static Color get disabledBg => _dark
      ? Colors.white.withValues(alpha: 0.14)
      : AppTheme.onSurface(alpha: 0.15);

  // ---------- 卡片与分割 ----------
  static Color get cardColor =>
      _dark ? const Color(0xFF272B33) : const Color(0xFFFFFFFF);
  static Color get dividerColor =>
      _dark ? const Color(0xFF353B45) : const Color(0xFFEDEDE8);

  // ---------- 玻璃拟态（Glassmorphism：模糊 + 半透明 + 高光描边 + 柔影） ----------
  /// 玻璃填充下沿（略透明，透出背景渐变）
  static Color get glassFill =>
      _dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.55);

  /// 玻璃填充上沿（更亮，模拟顶部光源）
  static Color get glassFillStrong =>
      _dark ? Colors.white.withValues(alpha: 0.11) : Colors.white.withValues(alpha: 0.78);

  /// 玻璃高光描边
  static Color get glassBorder =>
      _dark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.85);

  /// 背景模糊强度
  static const double glassBlurSigma = 16;

  /// 玻璃卡片柔影（浅色下带一丝主色，深色下用黑色托底）
  static List<BoxShadow> get glassShadow => _dark
      ? const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
        ]
      : const [
          BoxShadow(
              color: Color(0x140F766E), blurRadius: 22, offset: Offset(0, 8)),
        ];

  /// 主色渐变（Hero 卡片、主按钮、主 FAB）
  static const List<Color> accentGradient = [Color(0xFF2BB7A8), Color(0xFF0F766E)];

  /// 主色渐变对应的发光阴影色
  static const Color accentGlow = Color(0x4D0F766E);
  static Color get fieldBg =>
      _dark ? const Color(0xFF2E333D) : const Color(0xFFF2F1EC);

  // ---------- 语义色 ----------
  static Color get incomeColor =>
      _dark ? const Color(0xFF34D399) : const Color(0xFF16A34A); // 沉稳绿
  static Color get expenseColor =>
      _dark ? const Color(0xFFF87171) : const Color(0xFFDC2626); // 自然红

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
        bodyColor: dark ? const Color(0xFFE8EBF0) : textPrimary,
        displayColor: dark ? const Color(0xFFE8EBF0) : textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2E333D) : fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(
            color: dark ? const Color(0xFF7A8191) : textHint),
        prefixIconColor:
            dark ? const Color(0xFFB4BBC8) : textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            dark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
        contentTextStyle: TextStyle(
            color: dark ? const Color(0xFF1F2937) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF272B33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: dark ? const Color(0xFF353B45) : dividerColor,
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
  static TextStyle get hint =>
      TextStyle(color: AppTheme.textHint, fontSize: 12);
}
