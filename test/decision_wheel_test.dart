import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/utils/decision_wheel.dart';

void main() {
  group('DecisionWheel.sectorAtAngle', () {
    test('顶部扇区（0° 附近）命中第 0 个', () {
      expect(DecisionWheel.sectorAtAngle(0, 4), 0);
      expect(DecisionWheel.sectorAtAngle(44.9, 4), 0);
    });

    test('四扇区：90° 为一格', () {
      expect(DecisionWheel.sectorAtAngle(90, 4), 1);
      expect(DecisionWheel.sectorAtAngle(180, 4), 2);
      expect(DecisionWheel.sectorAtAngle(270, 4), 3);
      expect(DecisionWheel.sectorAtAngle(359.9, 4), 3);
    });

    test('负角度归一化（逆时针回旋）', () {
      expect(DecisionWheel.sectorAtAngle(-90, 4), 3);
      expect(DecisionWheel.sectorAtAngle(-360, 4), 0);
    });

    test('多圈旋转取余生效', () {
      expect(DecisionWheel.sectorAtAngle(720 + 135, 4), 1);
      expect(DecisionWheel.sectorAtAngle(1080 + 90, 4), 1);
      expect(DecisionWheel.sectorAtAngle(720 + 45, 4), 0);
    });

    test('单选项恒为 0；非法数量返回 -1', () {
      expect(DecisionWheel.sectorAtAngle(123, 1), 0);
      expect(DecisionWheel.sectorAtAngle(123, 0), -1);
    });
  });

  group('DecisionWheel.parseOptions', () {
    test('按空格/逗号/顿号/分号拆分并去空', () {
      expect(
        DecisionWheel.parseOptions('米饭 面条,饺子、火锅；烧烤  '),
        ['米饭', '面条', '饺子', '火锅', '烧烤'],
      );
    });

    test('自动去重', () {
      expect(DecisionWheel.parseOptions('a a b，b'), ['a', 'b']);
    });

    test('空输入返回空列表', () {
      expect(DecisionWheel.parseOptions(''), isEmpty);
      expect(DecisionWheel.parseOptions('   '), isEmpty);
      expect(DecisionWheel.parseOptions('，、；'), isEmpty);
    });
  });

  group('DecisionWheel.presets', () {
    test('每个预设至少 2 个选项且名称非空', () {
      for (final p in DecisionWheel.presets) {
        expect(p.name.trim(), isNotEmpty);
        expect(p.options.length, greaterThanOrEqualTo(2));
        expect(p.options.toSet().length, p.options.length,
            reason: '${p.name} 选项不应重复');
      }
    });
  });
}
