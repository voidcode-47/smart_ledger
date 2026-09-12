import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/game2048.dart';

/// 2048 小游戏：滑动合并数字，冲击最高分。
/// 支持手机滑动 / 桌面方向键；本地记录最高分，越玩越想破纪录。
class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  static const String _bestKey = 'game_2048_best';

  late Game2048 _game;
  int _best = 0;
  bool _wonNotified = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _game = Game2048();
    _loadBest();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_bestKey) ?? 0;
      if (mounted && v > 0) setState(() => _best = v);
    } catch (_) {}
  }

  Future<void> _saveBest() async {
    if (_game.score <= _best) return;
    setState(() => _best = _game.score);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, _best);
    } catch (_) {}
  }

  void _handleMove(MoveDir dir) {
    final changed = _game.move(dir);
    if (!changed) return;
    setState(() {});
    _saveBest();
    if (_game.won && !_wonNotified) {
      _wonNotified = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('达成 2048！继续挑战更高分吧'),
          duration: Duration(seconds: 2),
        ));
    }
    if (_game.isGameOver) {
      _showGameOver();
    }
  }

  void _restart() {
    setState(() {
      _game = Game2048();
      _wonNotified = false;
    });
  }

  Future<void> _showGameOver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('游戏结束'),
        content: Text(
          '本局得分：${_game.score}\n最高纪录：$_best\n再来一局刷新纪录？',
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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cardColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('2048'),
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowUp:
              _handleMove(MoveDir.up);
            case LogicalKeyboardKey.arrowDown:
              _handleMove(MoveDir.down);
            case LogicalKeyboardKey.arrowLeft:
              _handleMove(MoveDir.left);
            case LogicalKeyboardKey.arrowRight:
              _handleMove(MoveDir.right);
            default:
              return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // ---------- 得分与操作 ----------
            Row(
              children: [
                _scoreBox('得分', _game.score),
                const SizedBox(width: 10),
                _scoreBox('最高', _best),
                const Spacer(),
                TextButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('新一局'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.accentBg,
                    foregroundColor: AppTheme.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '滑动或按方向键合并相同数字，合成 2048 即达成目标',
              style: TextStyle(
                  fontSize: 12, color: Colors.black.withValues(alpha: 0.50)),
            ),
            const SizedBox(height: 16),
            // ---------- 棋盘 ----------
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(builder: (context, c) {
                  final cell = (c.maxWidth - 4 * 8) / 4;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF776E65),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanEnd: (details) {
                        final v = details.velocity.pixelsPerSecond;
                        if (v.distance < 120) return;
                        if (v.dx.abs() > v.dy.abs()) {
                          _handleMove(v.dx > 0 ? MoveDir.right : MoveDir.left);
                        } else {
                          _handleMove(v.dy > 0 ? MoveDir.down : MoveDir.up);
                        }
                      },
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: Game2048.size * Game2048.size,
                        itemBuilder: (context, i) {
                          final r = i ~/ 4, c = i % 4;
                          return _tile(_game.board[r][c], cell);
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
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

  Widget _tile(int value, double cell) {
    final (bg, fg) = _tileColor(value);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: value == 0
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: cell * 0.42,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
    );
  }

  (Color, Color) _tileColor(int value) {
    switch (value) {
      case 2:
        return (const Color(0xFFEEE4DA), const Color(0xFF776E65));
      case 4:
        return (const Color(0xFFEDE0C8), const Color(0xFF776E65));
      case 8:
        return (const Color(0xFFF2B179), Colors.white);
      case 16:
        return (const Color(0xFFF59563), Colors.white);
      case 32:
        return (const Color(0xFFF67C5F), Colors.white);
      case 64:
        return (const Color(0xFFF65E3B), Colors.white);
      case 128:
        return (const Color(0xFFEDCF72), Colors.white);
      case 256:
        return (const Color(0xFFEDCC61), Colors.white);
      case 512:
        return (const Color(0xFFEDC850), Colors.white);
      case 1024:
        return (const Color(0xFFEDC53F), Colors.white);
      case 2048:
        return (const Color(0xFFEDC22E), Colors.white);
      default:
        return (const Color(0xFF3C3A32), Colors.white);
    }
  }
}
