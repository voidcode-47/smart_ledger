import 'dart:math';

/// 移动方向
enum SnakeDir { up, down, left, right }

/// 贪吃蛇核心逻辑（纯 Dart，便于单元测试）：
/// 固定网格、头前尾后、吃食增长、撞墙/撞身结束、禁止 180° 反向。
class SnakeGame {
  SnakeGame({this.width = 15, this.height = 15, Random? rng})
      : _rng = rng ?? Random() {
    final cx = width ~/ 2, cy = height ~/ 2;
    snake = [Point(cx, cy), Point(cx - 1, cy), Point(cx - 2, cy)];
    dir = SnakeDir.right;
    score = 0;
    gameOver = false;
    _spawnFood();
  }

  final int width;
  final int height;
  final Random _rng;

  /// 蛇身坐标，头在前
  late final List<Point<int>> snake;
  late SnakeDir dir;
  late Point<int> food;
  int score = 0;
  bool gameOver = false;

  /// 生成食物（避开蛇身；无空位则判胜结束）
  void _spawnFood() {
    final occupied = snake.map((p) => '${p.x},${p.y}').toSet();
    final free = <Point<int>>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!occupied.contains('$x,$y')) free.add(Point(x, y));
      }
    }
    if (free.isEmpty) {
      gameOver = true; // 蛇占满全屏：胜利结束
      return;
    }
    food = free[_rng.nextInt(free.length)];
  }

  /// 尝试转向；禁止 180° 反向（否则一帧内自撞）
  void changeDir(SnakeDir d) {
    if (_isOpposite(d, dir)) return;
    dir = d;
  }

  static bool _isOpposite(SnakeDir a, SnakeDir b) {
    return (a == SnakeDir.up && b == SnakeDir.down) ||
        (a == SnakeDir.down && b == SnakeDir.up) ||
        (a == SnakeDir.left && b == SnakeDir.right) ||
        (a == SnakeDir.right && b == SnakeDir.left);
  }

  /// 前进一步。吃到食物返回 true（分数 +1 且身体增长）。
  bool step() {
    if (gameOver) return false;
    final head = snake.first;
    final next = switch (dir) {
      SnakeDir.up => Point(head.x, head.y - 1),
      SnakeDir.down => Point(head.x, head.y + 1),
      SnakeDir.left => Point(head.x - 1, head.y),
      SnakeDir.right => Point(head.x + 1, head.y),
    };
    // 撞墙
    if (next.x < 0 || next.x >= width || next.y < 0 || next.y >= height) {
      gameOver = true;
      return false;
    }
    // 撞自己（未增长时尾巴即将让出该格，允许进占）
    final willGrow = next == food;
    final bodyToCheck = willGrow ? snake : snake.sublist(0, snake.length - 1);
    if (bodyToCheck.any((p) => p == next)) {
      gameOver = true;
      return false;
    }
    snake.insert(0, next);
    if (willGrow) {
      score++;
      _spawnFood();
      return true;
    }
    snake.removeLast();
    return false;
  }
}
