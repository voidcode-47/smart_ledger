import 'dart:math';

/// 滑动方向
enum MoveDir { up, down, left, right }

/// 2048 核心逻辑（纯 Dart，便于单元测试）：
/// 4x4 棋盘、单次滑动合并（同值相邻合并且不连锁）、随机生成新块、胜负判定。
class Game2048 {
  Game2048({Random? rng}) : _rng = rng ?? Random() {
    board = List.generate(size, (_) => List.filled(size, 0));
    score = 0;
    won = false;
    _addRandomTile();
    _addRandomTile();
  }

  static const int size = 4;

  final Random _rng;
  late final List<List<int>> board;
  int score = 0;

  /// 是否已合成出 2048（达成后仍可继续挑战更高分）
  bool won = false;

  /// 随机生成一块：2（90%）或 4（10%），落在空格上
  void _addRandomTile() {
    final empty = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) empty.add((r, c));
      }
    }
    if (empty.isEmpty) return;
    final (r, c) = empty[_rng.nextInt(empty.length)];
    board[r][c] = _rng.nextDouble() < 0.9 ? 2 : 4;
  }

  /// 单行合并（左对齐）：[2,2,2,2] → [4,4,0,0]（同一步不连锁合并），
  /// 返回合并后的行与本次得分。
  static (List<int>, int) mergeLine(List<int> line) {
    final vals = [
      for (final v in line)
        if (v != 0) v
    ];
    final out = <int>[];
    var gained = 0;
    var i = 0;
    while (i < vals.length) {
      if (i + 1 < vals.length && vals[i] == vals[i + 1]) {
        final merged = vals[i] * 2;
        out.add(merged);
        gained += merged;
        i += 2;
      } else {
        out.add(vals[i]);
        i += 1;
      }
    }
    while (out.length < line.length) {
      out.add(0);
    }
    return (out, gained);
  }

  /// 执行一次滑动。棋盘发生变化时返回 true（并生成新块、累计得分）。
  bool move(MoveDir dir) {
    final before = _snapshot();
    var gained = 0;
    for (var i = 0; i < size; i++) {
      List<int> line;
      switch (dir) {
        case MoveDir.left:
          line = [for (var c = 0; c < size; c++) board[i][c]];
        case MoveDir.right:
          line = [for (var c = size - 1; c >= 0; c--) board[i][c]];
        case MoveDir.up:
          line = [for (var r = 0; r < size; r++) board[r][i]];
        case MoveDir.down:
          line = [for (var r = size - 1; r >= 0; r--) board[r][i]];
      }
      final (merged, g) = mergeLine(line);
      gained += g;
      switch (dir) {
        case MoveDir.left:
          for (var c = 0; c < size; c++) {
            board[i][c] = merged[c];
          }
        case MoveDir.right:
          for (var c = 0; c < size; c++) {
            board[i][c] = merged[size - 1 - c];
          }
        case MoveDir.up:
          for (var r = 0; r < size; r++) {
            board[r][i] = merged[r];
          }
        case MoveDir.down:
          for (var r = 0; r < size; r++) {
            board[r][i] = merged[size - 1 - r];
          }
      }
    }
    if (!_changed(before)) return false;
    score += gained;
    if (!won && board.any((row) => row.contains(2048))) won = true;
    _addRandomTile();
    return true;
  }

  /// 是否无路可走（满盘且相邻无同值）
  bool get isGameOver {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) return false;
        if (c + 1 < size && board[r][c] == board[r][c + 1]) return false;
        if (r + 1 < size && board[r][c] == board[r + 1][c]) return false;
      }
    }
    return true;
  }

  List<List<int>> _snapshot() => [
        for (final row in board) [...row]
      ];

  bool _changed(List<List<int>> before) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] != before[r][c]) return true;
      }
    }
    return false;
  }
}
