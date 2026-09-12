import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_theme.dart';
import '../../utils/decision_wheel.dart';

/// 随机转盘：选择困难时的决策小工具。
/// 内置多组预设（吃什么/喝什么/去哪儿玩…），可增删自定义选项，
/// 转盘旋转动画结束后高亮结果，选项列表持久化保存。
class DecisionWheelScreen extends StatefulWidget {
  const DecisionWheelScreen({super.key});

  @override
  State<DecisionWheelScreen> createState() => _DecisionWheelScreenState();
}

class _DecisionWheelScreenState extends State<DecisionWheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // 注意：不能是 final —— 每次转动都会重新绑定一段新的 Tween 动画，
  // final 会在第二次点击时抛 LateInitializationError（转盘“只能转一次”的根因）。
  late Animation<double> _spinAnim;

  List<String> _options = [];
  double _rotation = 0; // 累计旋转角度（度，顺时针）
  bool _spinning = false;
  String? _result;
  final _addCtrl = TextEditingController();
  int _lastPreset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _controller.addListener(() {
      if (mounted) setState(() => _rotation = _spinAnim.value);
    });
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      final idx = DecisionWheel.sectorAtAngle(_rotation, _options.length);
      setState(() {
        _result = idx >= 0 ? _options[idx] : null;
        _spinning = false;
      });
    });
    _loadOptions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(DecisionWheel.prefKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (list.isNotEmpty) {
          if (mounted) setState(() => _options = list);
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _options = [...DecisionWheel.presets[_lastPreset].options];
      });
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(DecisionWheel.prefKey, jsonEncode(_options));
    } catch (_) {}
  }

  void _applyPreset(int index) {
    if (_spinning) return;
    setState(() {
      _lastPreset = index;
      _options = [...DecisionWheel.presets[index].options];
      _result = null;
    });
    _persist();
  }

  void _addOptions() {
    final parsed = DecisionWheel.parseOptions(_addCtrl.text);
    if (parsed.isEmpty) return;
    setState(() {
      for (final s in parsed) {
        if (!_options.contains(s)) _options.add(s);
      }
      _result = null;
      _addCtrl.clear();
    });
    _persist();
  }

  void _removeOption(int index) {
    if (_spinning) return;
    setState(() {
      _options.removeAt(index);
      _result = null;
    });
    _persist();
  }

  void _spin() {
    if (_spinning || _options.isEmpty) return;
    setState(() {
      _spinning = true;
      _result = null;
    });
    final rng = Random();
    // 5~9 圈 + 随机偏移，保证每次结果不重复预谋
    final target =
        5 * 360 + rng.nextDouble() * 4 * 360 + rng.nextDouble() * 360;
    _spinAnim = Tween<double>(begin: _rotation, end: _rotation + target)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final wheelSize = MediaQuery.of(context).size.shortestSide - 64;
    final colors = DecisionWheel.sectorColors(_options.length);

    return Scaffold(
      backgroundColor: AppTheme.cardColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('随机转盘'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ---------- 结果区 ----------
          SizedBox(
            height: 64,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _result == null
                    ? Text(
                        _spinning ? '转起来…' : '选择困难？点击下方按钮转一下',
                        key: const ValueKey('hint'),
                        style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurface(alpha: 0.55)),
                      )
                    : Container(
                        key: ValueKey(_result),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.celebration_rounded,
                                color: AppTheme.accent, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '就决定是「$_result」',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ---------- 转盘 ----------
          Center(
            child: SizedBox(
              width: wheelSize,
              height: wheelSize,
              child: GestureDetector(
                onTap: _options.length > 1 ? _spin : null,
                child: CustomPaint(
                  painter: _WheelPainter(
                    options: _options,
                    colors: colors,
                    rotationDeg: _rotation,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ---------- 开始按钮 ----------
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.onSurface(alpha: 0.15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _options.length > 1 && !_spinning ? _spin : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始转！',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          // ---------- 预设 ----------
          Text('预设',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface(alpha: 0.65))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < DecisionWheel.presets.length; i++)
                ChoiceChip(
                  label: Text(DecisionWheel.presets[i].name),
                  selected: _lastPreset == i,
                  selectedColor: AppTheme.accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _lastPreset == i
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  side: BorderSide.none,
                  showCheckmark: false,
                  onSelected: (_) => _applyPreset(i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // ---------- 选项编辑 ----------
          Row(
            children: [
              Text('当前选项（${_options.length}）',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(alpha: 0.65))),
              const Spacer(),
              if (_options.length > 1)
                TextButton.icon(
                  onPressed: _spinning
                      ? null
                      : () {
                          setState(() {
                            _options = [];
                            _result = null;
                          });
                          _persist();
                        },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.expenseColor),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('还没有选项，请在下方添加',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.onSurface(alpha: 0.50))),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _options.length; i++)
                  InputChip(
                    label: Text(_options[i]),
                    backgroundColor: AppTheme.accentBg,
                    labelStyle:
                        const TextStyle(fontSize: 12, color: AppTheme.accent),
                    side: BorderSide.none,
                    onDeleted: _spinning ? null : () => _removeOption(i),
                    deleteIcon: const Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.accent),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  enabled: !_spinning,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: '添加选项，可用空格 / 逗号一次输入多个',
                    hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurface(alpha: 0.40)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addOptions(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white),
                onPressed: _spinning ? null : _addOptions,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '提示：点一下转盘也可以开始转动；选项少于 2 个时无法转动。',
            style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppTheme.onSurface(alpha: 0.40)),
          ),
        ],
      ),
    );
  }
}

/// 转盘绘制：彩色扇区 + 沿半径方向的可读文字 + 顶部指针
class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.options,
    required this.colors,
    required this.rotationDeg,
  });

  final List<String> options;
  final List<Color> colors;
  final double rotationDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = options.length;
    final rotation = rotationDeg * pi / 180;
    final sweep = 2 * pi / count;
    const gap = 0.03; // 扇区间细缝（度）

    // 扇区
    for (var i = 0; i < count; i++) {
      final start = -pi / 2 + rotation + i * sweep;
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        sweep - gap,
        true,
        paint,
      );
    }

    // 扇区文字（沿半径方向，左侧扇区翻转保证正向）
    for (var i = 0; i < count; i++) {
      final mid = -pi / 2 + rotation + (i + 0.5) * sweep;
      var angle = mid;
      var offset = radius * 0.56;
      if (mid > pi / 2 && mid < 3 * pi / 2) {
        angle += pi;
        offset = -radius * 0.56;
      }
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: options[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * 1.05);
      tp.paint(canvas, Offset(-tp.width / 2 + offset, -tp.height / 2));
      canvas.restore();
    }

    // 外圈描边
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // 顶部指针
    final pointer = Path()
      ..moveTo(center.dx - 12, center.dy - radius + 10)
      ..lineTo(center.dx + 12, center.dy - radius + 10)
      ..lineTo(center.dx, center.dy - radius - 8)
      ..close();
    canvas.drawPath(pointer, Paint()..color = AppTheme.expenseColor);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) {
    if (old.rotationDeg != rotationDeg) return true;
    if (old.options.length != options.length) return true;
    for (var i = 0; i < options.length; i++) {
      if (old.options[i] != options[i]) return true;
    }
    return false;
  }
}
