import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/utils/theme_config.dart';

void main() {
  group('ThemeConfig 背景主题精简', () {
    test('只保留白色与黑色两套主题', () {
      expect(ThemeConfig.backgrounds, hasLength(2));
      expect(ThemeConfig.backgrounds.map((t) => t.id).toList(),
          ['white', 'black']);
      expect(ThemeConfig.backgrounds.map((t) => t.name).toList(),
          ['白色', '黑色']);
    });

    test('白色主题非暗色，黑色主题标记为暗色', () {
      expect(ThemeConfig.byId('white').isDark, isFalse);
      expect(ThemeConfig.byId('black').isDark, isTrue);
    });

    test('byId 命中正确主题', () {
      expect(ThemeConfig.byId('white').name, '白色');
      expect(ThemeConfig.byId('black').name, '黑色');
    });

    test('旧版本主题 id（青绿/暖阳等）统一回退到白色', () {
      for (final legacyId in ['mint', 'sun', 'mist', 'blossom', 'jade', '']) {
        expect(ThemeConfig.byId(legacyId).id, 'white',
            reason: '未知/旧版 id「$legacyId」应回退白色');
      }
    });

    test('onBackground 黑色背景反白、白色背景保持深色（默认透明度 0.8）', () {
      expect(ThemeConfig.onBackground(true), Colors.white.withValues(alpha: 0.8));
      expect(ThemeConfig.onBackground(false), Colors.black.withValues(alpha: 0.8));
      // 透明度参数生效
      expect(ThemeConfig.onBackground(true, alpha: 0.5).a, closeTo(0.5, 0.001));
    });
  });
}
