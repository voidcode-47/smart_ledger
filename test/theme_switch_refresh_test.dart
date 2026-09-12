import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_ledger/main.dart';
import 'package:smart_ledger/utils/theme_config.dart';
import 'package:smart_ledger/viewmodels/theme_providers.dart';

/// 主题切换回归测试：背景主题切换后，仪表盘上的卡片/文字颜色必须立即刷新。
/// （曾因 const 子树 + 页面未监听主题，切到白色后格言卡片仍停留在深色）
void main() {
  Color? sourceTextColor(WidgetTester tester) {
    for (final t in tester.widgetList<Text>(find.textContaining('——'))) {
      final color = t.style?.color;
      if (color != null) return color;
    }
    return null;
  }

  testWidgets('切换主题后仪表盘格言卡片颜色立即刷新', (tester) async {
    SharedPreferences.setMockInitialValues({'background_theme_id': 'white'});
    final container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const SmartLedgerApp(),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 白色主题：格言来源文字为黑色系（onSurface 0.5）
    final lightColor = sourceTextColor(tester);
    expect(lightColor, isNotNull);
    expect(lightColor!.computeLuminance() < 0.5, isTrue,
        reason: '白色主题下格言来源文字应为深色');

    // 切换到黑色主题
    await container
        .read(backgroundThemeProvider.notifier)
        .setTheme(ThemeConfig.backgrounds.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 黑色主题：格言来源文字应变为白色系
    final darkColor = sourceTextColor(tester);
    expect(darkColor, isNotNull);
    expect(darkColor!.computeLuminance() > 0.5, isTrue,
        reason: '黑色主题下格言来源文字应为浅色');

    // 切回白色主题再验证
    await container
        .read(backgroundThemeProvider.notifier)
        .setTheme(ThemeConfig.backgrounds.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final backColor = sourceTextColor(tester);
    expect(backColor, isNotNull);
    expect(backColor!.computeLuminance() < 0.5, isTrue,
        reason: '切回白色后格言来源文字应恢复深色');
  });
}
