import 'package:flutter/material.dart';

/// 列表项简单 fade-in 入场（200ms）
///
/// 设计语言：数字优先
/// - 移除 staggered 交错延迟（AI 味装饰，长列表尾部等待过久）
/// - 仅保留单次淡入，克制
class StaggeredItem extends StatefulWidget {
  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.maxDelayIndex = 8,
  });

  /// 列表中的位置（保留参数向后兼容，不再用于交错延迟）
  final int index;
  final Widget child;
  final Duration duration;
  final int maxDelayIndex;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}
