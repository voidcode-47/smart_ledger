import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/viewmodels/theme_providers.dart';

void main() {
  group('CustomBackgroundsState.active（重启后不自动激活的回归）', () {
    const a = CustomBackgroundItem(id: 'a', path: '/x/a.jpg');
    const b = CustomBackgroundItem(id: 'b', path: '/x/b.jpg');

    test('无背景时 active 为 null', () {
      const s = CustomBackgroundsState(items: []);
      expect(s.active, isNull);
      expect(s.activeId, isNull);
    });

    test('有背景但未指定 activeId（用户选择了主题停用）：active 必须为 null', () {
      // 回归点：旧实现会回退到第一张，导致重启后自定义背景自动激活
      const s = CustomBackgroundsState(items: [a, b], activeId: null);
      expect(s.activeId, isNull);
      expect(s.active, isNull);
    });

    test('指定 activeId 时返回对应背景', () {
      const s = CustomBackgroundsState(items: [a, b], activeId: 'b');
      expect(s.active?.id, 'b');
      expect(s.active?.path, '/x/b.jpg');
    });

    test('activeId 不存在于列表时视为停用（active 为 null）', () {
      const s = CustomBackgroundsState(items: [a], activeId: 'ghost');
      expect(s.active, isNull);
    });
  });

  group('CustomBackgroundsNotifier.resolveActiveId', () {
    const ids = ['a', 'b', 'c'];

    test('activeId 有效时使用 activeId', () {
      expect(CustomBackgroundsNotifier.resolveActiveId(ids, 'b'), 'b');
      expect(CustomBackgroundsNotifier.resolveActiveId(ids, 'a'), 'a');
    });

    test('activeId 为 null（显式停用）时保持停用，不回退第一张', () {
      expect(CustomBackgroundsNotifier.resolveActiveId(ids, null), isNull);
    });

    test('activeId 不在列表中时视为无效，保持停用', () {
      expect(CustomBackgroundsNotifier.resolveActiveId(ids, 'zzz'), isNull);
    });

    test('旧版单图迁移场景才允许默认激活首张', () {
      expect(CustomBackgroundsNotifier.resolveActiveId(ids, null, migratedId: 'a'),
          'a');
      // 有 activeId 时忽略 migratedId
      expect(CustomBackgroundsNotifier.resolveActiveId(ids, 'c', migratedId: 'a'),
          'c');
      // migratedId 无效时也不回退
      expect(
          CustomBackgroundsNotifier.resolveActiveId(ids, null, migratedId: 'zzz'),
          isNull);
    });

    test('空列表始终返回 null', () {
      expect(CustomBackgroundsNotifier.resolveActiveId([], 'a'), isNull);
      expect(CustomBackgroundsNotifier.resolveActiveId([], null), isNull);
    });
  });
}
