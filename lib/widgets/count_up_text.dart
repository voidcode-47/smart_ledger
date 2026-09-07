import 'package:flutter/material.dart';

import '../utils/format_utils.dart';

/// 数字滚动（Count Up）文本
/// 当 value 变化时，从旧值平滑过渡到新值
class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final double value;
  final TextStyle? style;
  final Duration duration;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  /// 当前动画起点（上一次展示的值）
  double _from = 0;
  double _display = 0;

  @override
  void initState() {
    super.initState();
    _display = widget.value;
    _controller.addListener(_onTick);
  }

  void _onTick() {
    setState(() {
      _display = _from + (widget.value - _from) * _controller.value;
    });
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _from = _display; // 从当前展示值出发，动画更连贯
      });
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(FormatUtils.money(_display), style: widget.style);
  }
}
