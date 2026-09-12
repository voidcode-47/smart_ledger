import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/utils/snake_game.dart';

void main() {
  group('SnakeGame 基础移动', () {
    test('初始状态：蛇长 3、朝右、分数 0、未结束', () {
      final g = SnakeGame(width: 15, height: 15);
      expect(g.snake.length, 3);
      expect(g.dir, SnakeDir.right);
      expect(g.score, 0);
      expect(g.gameOver, isFalse);
      expect(g.food.x, inInclusiveRange(0, 14));
      expect(g.food.y, inInclusiveRange(0, 14));
    });

    test('前进一格：头前移、尾后缩、长度不变', () {
      final g = SnakeGame(width: 15, height: 15);
      final before = List<Point<int>>.from(g.snake);
      g.step();
      expect(g.snake.length, before.length);
      expect(g.snake.first.x, before.first.x + 1);
      expect(g.snake.first.y, before.first.y);
    });
  });

  group('SnakeGame 吃食与增长', () {
    test('吃到食物：分数 +1、身体增长、头落于原食物格', () {
      final g = SnakeGame(width: 15, height: 15, rng: Random(7));
      // 把食物放到蛇头正前方，记录位置（进食后食物会被重新生成）
      g.food = Point(g.snake.first.x + 1, g.snake.first.y);
      final oldFood = g.food;
      final lengthBefore = g.snake.length;
      final ate = g.step();
      expect(ate, isTrue);
      expect(g.score, 1);
      expect(g.snake.length, lengthBefore + 1);
      expect(g.snake.first, oldFood);
    });

    test('未吃食物：分数不变、长度不变', () {
      final g = SnakeGame(width: 15, height: 15, rng: Random(7));
      // 把食物放到远处
      g.food = const Point(0, 0);
      final ate = g.step();
      expect(ate, isFalse);
      expect(g.score, 0);
      expect(g.snake.length, 3);
    });
  });

  group('SnakeGame 碰撞判定', () {
    test('撞墙结束', () {
      final g = SnakeGame(width: 15, height: 15);
      g.snake[0] = const Point(0, 0);
      g.dir = SnakeDir.up;
      g.step();
      expect(g.gameOver, isTrue);
    });

    test('撞自己结束（非尾部格）', () {
      final g = SnakeGame(width: 15, height: 15);
      // 蛇身弯成 U 形，头朝上会撞到第二节身体
      g.snake
        ..clear()
        ..addAll(const [
          Point(2, 2), Point(2, 1), Point(1, 1), Point(1, 2),
        ]);
      g.dir = SnakeDir.up;
      g.step();
      expect(g.gameOver, isTrue);
    });

    test('未增长时允许走进旧尾巴让出的格子', () {
      final g = SnakeGame(width: 15, height: 15);
      // 蛇围成一个环：头旁边就是尾巴
      g.snake
        ..clear()
        ..addAll(const [
          Point(2, 1), Point(2, 2), Point(1, 2), Point(1, 1),
        ]);
      g.dir = SnakeDir.left; // 下一步会走进 (1,1)，即旧尾巴位置
      g.step();
      expect(g.gameOver, isFalse);
      expect(g.snake.length, 4); // 未增长，长度不变
    });

    test('游戏结束后 step 不再生效', () {
      final g = SnakeGame(width: 15, height: 15);
      g.snake[0] = const Point(0, 0);
      g.dir = SnakeDir.up;
      g.step();
      expect(g.gameOver, isTrue);
      final len = g.snake.length;
      g.step();
      expect(g.snake.length, len);
    });
  });

  group('SnakeGame 方向控制', () {
    test('禁止 180° 反向', () {
      final g = SnakeGame(width: 15, height: 15);
      g.changeDir(SnakeDir.left); // 与当前 right 相反，应被忽略
      expect(g.dir, SnakeDir.right);
      g.changeDir(SnakeDir.down); // 垂直转向允许
      expect(g.dir, SnakeDir.down);
      g.changeDir(SnakeDir.up); // 与 down 相反，应被忽略
      expect(g.dir, SnakeDir.down);
    });
  });
}
