import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/snake_game.dart';

/// 贪吃蛇小游戏：吃食物变长、撞墙/撞身结束。
/// 速度随分数逐步提升（节奏越来越刺激），本地记录最高分，
/// 支持滑动 / 方向键 / 屏幕方向键操作，可暂停。
class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  static const String _bestKey = 'game_snake_best';
  static const int _gridSize = 15;

  late SnakeGame _game;
  int _best = 0;
  bool _paused = false;
  Timer? _timer;
  Offset _swipe = Offset.zero;
  final FocusNode _focusNode = FocusNode();

  /// 速度随分数提升：200ms 起步，每分 -4ms，最快 80ms
  int get _intervalMs => max(80, 200 - _game.score * 4);

  @override
  void initState() {
    super.initState();
    _game = SnakeGame(width: _gridSize, height: _gridSize);
    _loadBest();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_bestKey) ?? 0;
      if (mounted && v > 0) setState(() => _best = v);
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _intervalMs), (_) {
      if (!mounted || _paused || _game.gameOver) return;
      _tick();
    });
  }

  void _tick() {
    final ate = _game.step();
    if (_game.gameOver) {
      _timer?.cancel();
      setState(() {});
      _saveBest();
      _showGameOver();
      return;
    }
    setState(() {});
    if (ate) {
      _saveBest();
      // 分数变化导致速度档位变化时重建计时器
      _startTimer();
    }
  }

  Future<void> _saveBest() async {
    if (_game.score <= _best) return;
    setState(() => _best = _game.score);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, _best);
    } catch (_) {}
  }

  void _changeDir(SnakeDir d) {
    if (_paused || _game.gameOver) return;
    _game.changeDir(d);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _game = SnakeGame(width: _gridSize, height: _gridSize);
      _paused = false;
    });
    _startTimer();
  }

  Future<void> _showGameOver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('游戏结束'),
        content: Text(
          '本局得分：${_game.score}\n最高纪录：$_best\n再来一局冲击新纪录？',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('关闭')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('再来一局'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cardColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('贪吃蛇'),
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowUp:
              _changeDir(SnakeDir.up);
            case LogicalKeyboardKey.arrowDown:
              _changeDir(SnakeDir.down);
            case LogicalKeyboardKey.arrowLeft:
              _changeDir(SnakeDir.left);
            case LogicalKeyboardKey.arrowRight:
              _changeDir(SnakeDir.right);
            case LogicalKeyboardKey.space:
              _togglePause();
            default:
              return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ---------- 得分与操作 ----------
            Row(
              children: [
                _scoreBox('得分', _game.score),
                const SizedBox(width: 10),
                _scoreBox('最高', _best),
                const Spacer(),
                IconButton(
                  tooltip: _paused ? '继续' : '暂停',
                  onPressed: _game.gameOver ? null : _togglePause,
                  icon: Icon(
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: AppTheme.accent),
                ),
                IconButton(
                  tooltip: '重开',
                  onPressed: _restart,
                  icon:
                      const Icon(Icons.refresh_rounded, color: AppTheme.accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(builder: (context, c) {
                  final size = c.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _swipe = Offset.zero,
                    onPanUpdate: (d) {
                      _swipe += d.delta;
                      if (_swipe.dx.abs() > 24 || _swipe.dy.abs() > 24) {
                        if (_swipe.dx.abs() > _swipe.dy.abs()) {
                          _changeDir(
                              _swipe.dx > 0 ? SnakeDir.right : SnakeDir.left);
                        } else {
                          _changeDir(
                              _swipe.dy > 0 ? SnakeDir.down : SnakeDir.up);
                        }
                        _swipe = Offset.zero;
                      }
                    },
                    child: CustomPaint(
                      size: Size(size, size),
                      painter: _SnakePainter(
                        game: _game,
                        paused: _paused,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // ---------- 方向键 ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _padButton(
                    Icons.arrow_back_rounded, () => _changeDir(SnakeDir.left)),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _padButton(Icons.arrow_upward_rounded,
                        () => _changeDir(SnakeDir.up)),
                    const SizedBox(height: 12),
                    _padButton(Icons.arrow_downward_rounded,
                        () => _changeDir(SnakeDir.down)),
                  ],
                ),
                const SizedBox(width: 12),
                _padButton(Icons.arrow_forward_rounded,
                    () => _changeDir(SnakeDir.right)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '滑动棋盘 / 方向键控制方向；空格或暂停键可随时暂停。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.black.withValues(alpha: 0.50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppTheme.accentBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: AppTheme.accent, size: 26),
        ),
      ),
    );
  }

  Widget _scoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.accent)),
          Text('$value',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent)),
        ],
      ),
    );
  }
}

/// 棋盘绘制：浅色网格 + 蛇身（头深色）+ 食物红点 + 暂停遮罩
class _SnakePainter extends CustomPainter {
  _SnakePainter({required this.game, required this.paused});

  final SnakeGame game;
  final bool paused;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / game.width;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );

    // 背景
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFFEDEDE8),
    );

    // 网格线
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < game.width; i++) {
      final x = i * cell;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, x), Offset(size.width, x), gridPaint);
    }

    // 食物
    final foodCenter = Offset(
      game.food.x * cell + cell / 2,
      game.food.y * cell + cell / 2,
    );
    canvas.drawCircle(
        foodCenter, cell * 0.34, Paint()..color = AppTheme.expenseColor);

    // 蛇身
    for (var i = game.snake.length - 1; i >= 0; i--) {
      final p = game.snake[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          p.x * cell + 1.5,
          p.y * cell + 1.5,
          cell - 3,
          cell - 3,
        ),
        Radius.circular(cell * 0.28),
      );
      final isHead = i == 0;
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isHead
              ? AppTheme.accent
              : AppTheme.accent.withValues(alpha: 0.55),
      );
    }

    // 暂停 / 结束遮罩
    if (paused || game.gameOver) {
      canvas.drawRRect(
          rrect, Paint()..color = Colors.black.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) {
    return old.game != game || old.paused != paused;
  }
}
