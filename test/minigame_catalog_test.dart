import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ledger/utils/minigame_catalog.dart';

void main() {
  group('小游戏目录配置', () {
    test('id 全局唯一', () {
      final ids = MiniGame.all.map((g) => g.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复 id');
    });

    test('离线游戏均已打包且资源完整', () {
      for (final g in MiniGame.offline) {
        expect(g.assetIndex, isNotNull, reason: '${g.id} 缺少 assetIndex');
        expect(g.onlineUrl, isNull, reason: '${g.id} 不应是联网游戏');
        final f = File(g.assetIndex!);
        expect(f.existsSync(), isTrue, reason: '${g.id} 的 ${g.assetIndex} 不存在');
        expect(f.lengthSync(), greaterThan(0),
            reason: '${g.id} 的 index.html 为空');
      }
    });

    test('联网游戏必须带在线地址且不引用本地资产', () {
      for (final g in MiniGame.online) {
        expect(g.onlineUrl, isNotNull, reason: '${g.id} 缺少 onlineUrl');
        expect(g.assetIndex, isNull, reason: '${g.id} 不应引用本地资产');
        expect(g.needsNetwork, isTrue);
      }
      expect(MiniGame.offline.length, greaterThanOrEqualTo(6),
          reason: '离线游戏数量应充足');
      expect(MiniGame.online.length, greaterThanOrEqualTo(1),
          reason: '至少一款联网游戏');
    });

    test('byId 可命中任意游戏', () {
      for (final g in MiniGame.all) {
        expect(MiniGame.byId(g.id)?.id, g.id);
      }
      expect(MiniGame.byId('not-exist'), isNull);
    });
  });

  group('虚拟按键布局', () {
    test('无需按键的游戏返回空布局', () {
      for (final g in MiniGame.offline.where((x) => x.input == MiniGameInput.none)) {
        expect(g.virtualKeys, isEmpty, reason: '${g.id} 不应有虚拟按键');
      }
    });

    test('十字方向键布局包含上左下右与暂停', () {
      final keys = const MiniGame(
        id: 'x',
        title: 'x',
        subtitle: '',
        icon: '',
        license: '',
        source: '',
        input: MiniGameInput.dPad,
      ).virtualKeys;
      final codes = keys.map((k) => k.code).toSet();
      expect(
          codes,
          containsAll([
            'ArrowUp',
            'ArrowDown',
            'ArrowLeft',
            'ArrowRight',
          ]));
      expect(keys.any((k) => k.keyCode == 32), isTrue, reason: '需要空格(暂停)');
    });

    test('俄罗斯方块布局包含左右下旋转与开始', () {
      final keys = const MiniGame(
        id: 'x',
        title: 'x',
        subtitle: '',
        icon: '',
        license: '',
        source: '',
        input: MiniGameInput.dPadRotate,
      ).virtualKeys;
      final codes = keys.map((k) => k.code).toSet();
      expect(codes, containsAll(['ArrowLeft', 'ArrowRight', 'ArrowDown']));
      expect(keys.any((k) => k.keyCode == 38), isTrue, reason: '需要旋转(上)');
      expect(keys.any((k) => k.keyCode == 32), isTrue, reason: '需要开始(空格)');
    });

    test('左右键布局（打砖块）含左右与暂停', () {
      final keys = const MiniGame(
        id: 'x',
        title: 'x',
        subtitle: '',
        icon: '',
        license: '',
        source: '',
        input: MiniGameInput.leftRight,
      ).virtualKeys;
      final codes = keys.map((k) => k.code).toSet();
      expect(codes, containsAll(['ArrowLeft', 'ArrowRight']));
      expect(keys.any((k) => k.keyCode == 80), isTrue, reason: '需要 P 暂停');
    });

    test('键码均在合法区间', () {
      for (final g in MiniGame.all) {
        for (final k in g.virtualKeys) {
          expect(k.keyCode, inInclusiveRange(32, 80),
              reason: '${g.id} 按键 ${k.label} 码值异常');
          expect(k.label, isNotEmpty);
          expect(k.key, isNotEmpty);
        }
      }
    });
  });
}
