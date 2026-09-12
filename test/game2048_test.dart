import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/utils/game2048.dart';

/// 确定性随机源：nextInt 恒为 0（命中首个空格）、nextDouble 恒为 0.0（生成 2）
class _FakeRandom implements Random {
  @override
  double nextDouble() => 0.0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('Game2048.mergeLine（单行合并规则）', () {
    test('[2,2,2,2] 只合并一次不连锁 → [4,4,0,0]，得分 8', () {
      final (line, gained) = Game2048.mergeLine([2, 2, 2, 2]);
      expect(line, [4, 4, 0, 0]);
      expect(gained, 8);
    });

    test('[4,4,4,0] 左侧优先合并 → [8,4,0,0]，得分 8', () {
      final (line, gained) = Game2048.mergeLine([4, 4, 4, 0]);
      expect(line, [8, 4, 0, 0]);
      expect(gained, 8);
    });

    test('[2,4,2,4] 无相邻相同 → 原样，得分 0', () {
      final (line, gained) = Game2048.mergeLine([2, 4, 2, 4]);
      expect(line, [2, 4, 2, 4]);
      expect(gained, 0);
    });

    test('[0,0,2,0] 向左对齐 → [2,0,0,0]，得分 0', () {
      final (line, gained) = Game2048.mergeLine([0, 0, 2, 0]);
      expect(line, [2, 0, 0, 0]);
      expect(gained, 0);
    });

    test('[16,16,32,64] → [32,32,64,0]，得分 32', () {
      final (line, gained) = Game2048.mergeLine([16, 16, 32, 64]);
      expect(line, [32, 32, 64, 0]);
      expect(gained, 32);
    });
  });

  group('Game2048 滑动与状态', () {
    test('新游戏：4x4、分数 0、恰有两块、未结束', () {
      final g = Game2048(rng: _FakeRandom());
      var count = 0;
      for (final row in g.board) {
        for (final v in row) {
          if (v != 0) count++;
        }
      }
      expect(g.board.length, 4);
      expect(g.board.every((r) => r.length == 4), isTrue);
      expect(count, 2);
      expect(g.score, 0);
      expect(g.won, isFalse);
      expect(g.isGameOver, isFalse);
    });

    test('左移合并、累计得分，并在合并腾出的首个空格生成新块', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [2, 2, 2, 2];
      g.board[1] = [7, 11, 13, 17];
      g.board[2] = [7, 11, 13, 17];
      g.board[3] = [7, 11, 13, 17];
      expect(g.move(MoveDir.left), isTrue);
      expect(g.board[0], [4, 4, 2, 0]); // 新块落在 (0,2)
      expect(g.score, 8);
      expect(g.board[1], [7, 11, 13, 17]); // 其余行保持不动
    });

    test('右移：镜像合并', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [0, 2, 2, 4];
      g.board[1] = [7, 11, 13, 17];
      g.board[2] = [7, 11, 13, 17];
      g.board[3] = [7, 11, 13, 17];
      expect(g.move(MoveDir.right), isTrue);
      expect(g.board[0], [2, 0, 4, 4]); // 新块落在 (0,0)
      expect(g.score, 4);
    });

    test('上移合并：列 [2,2,3,5] → [4,3,5,2]', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [2, 7, 7, 7];
      g.board[1] = [2, 11, 11, 11];
      g.board[2] = [3, 13, 13, 13];
      g.board[3] = [5, 17, 17, 17];
      expect(g.move(MoveDir.up), isTrue);
      expect(g.board[0][0], 4);
      expect(g.board[1][0], 3);
      expect(g.board[2][0], 5);
      expect(g.board[3][0], 2); // 新块落在列尾空格
    });

    test('下移合并：列 [2,2,3,5] → [2,4,3,5]', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [2, 7, 7, 7];
      g.board[1] = [2, 11, 11, 11];
      g.board[2] = [3, 13, 13, 13];
      g.board[3] = [5, 17, 17, 17];
      expect(g.move(MoveDir.down), isTrue);
      expect(g.board[3][0], 5); // 原底部 5 保持最底
      expect(g.board[2][0], 3);
      expect(g.board[1][0], 4); // 2+2 合并结果在其上方
      expect(g.board[0][0], 2); // 新块落在列首空格
    });

    test('无法滑动时返回 false 且棋盘不变', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [1, 2, 3, 4];
      g.board[1] = [5, 6, 7, 8];
      g.board[2] = [9, 10, 11, 12];
      g.board[3] = [13, 14, 15, 16];
      expect(g.move(MoveDir.left), isFalse);
      expect(g.move(MoveDir.up), isFalse);
      expect(g.score, 0);
    });

    test('合成 2048 后 won 为 true', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [1024, 1024, 0, 0];
      g.board[1] = [7, 11, 13, 17];
      g.board[2] = [7, 11, 13, 17];
      g.board[3] = [7, 11, 13, 17];
      expect(g.move(MoveDir.left), isTrue);
      expect(g.won, isTrue);
      expect(g.board[0][0], 2048);
    });

    test('满盘且无相邻同值时游戏结束', () {
      final g = Game2048(rng: _FakeRandom());
      g.board[0] = [2, 4, 2, 4];
      g.board[1] = [4, 2, 4, 2];
      g.board[2] = [2, 4, 2, 4];
      g.board[3] = [4, 2, 4, 2];
      expect(g.isGameOver, isTrue);
      // 存在空格时未结束
      g.board[3][3] = 0;
      expect(g.isGameOver, isFalse);
    });
  });
}
