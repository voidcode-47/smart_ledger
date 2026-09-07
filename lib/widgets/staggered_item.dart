import 'dart:async';

import 'package:flutter/material.dart';

/// 列表项交错入场动画（Staggered Animation）
/// 按列表序号依次延迟播放：淡入 + 从下方轻微上滑
class StaggeredItem extends StatefulWidget {
  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 360),
    this.maxDelayIndex = 8,
  });

  /// 列表中的位置（用于计算交错延迟）
  final int index;
  final Widget child;
  final Duration duration;

  /// 超出该序号的项目不再增加延迟，避免长列表尾部等待过久
  final int maxDelayIndex;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  late final Animation<double> _animation =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delayMs = 50 * widget.index.clamp(0, widget.maxDelayIndex);
    Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
