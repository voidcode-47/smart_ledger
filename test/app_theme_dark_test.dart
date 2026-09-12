import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ledger/utils/app_theme.dart';

/// 深色模式色板切换：黑色背景主题会触发全局深色色板，
/// 卡片/文字/辅助色必须随 [AppTheme.setDark] 切换且互不串扰。
void main() {
  tearDown(() => AppTheme.setDark(false));

  test('默认浅色模式：白卡片、深色文字、黑辅助文字', () {
    expect(AppTheme.isDark, isFalse);
    expect(AppTheme.cardColor, const Color(0xFFFFFFFF));
    expect(AppTheme.textPrimary, const Color(0xFF1F2937));
    expect(AppTheme.onSurface(), Colors.black);
  });

  test('深色模式：深卡片、浅色文字、白辅助文字', () {
    AppTheme.setDark(true);
    expect(AppTheme.isDark, isTrue);
    expect(AppTheme.cardColor, isNot(const Color(0xFFFFFFFF)));
    expect(AppTheme.textPrimary, isNot(const Color(0xFF1F2937)));
    expect(AppTheme.onSurface(), Colors.white);
    expect(AppTheme.onSurface(alpha: 0.5), Colors.white.withValues(alpha: 0.5));
  });

  test('切换回浅色模式后恢复原值', () {
    AppTheme.setDark(true);
    AppTheme.setDark(false);
    expect(AppTheme.cardColor, const Color(0xFFFFFFFF));
    expect(AppTheme.textPrimary, const Color(0xFF1F2937));
  });

  test('darkTheme 为深色亮度，light theme 为浅色亮度', () {
    expect(AppTheme.theme().brightness, Brightness.light);
    expect(AppTheme.darkTheme().brightness, Brightness.dark);
  });
}
