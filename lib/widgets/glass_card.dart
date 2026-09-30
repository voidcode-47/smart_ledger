import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_theme.dart';
import '../viewmodels/theme_providers.dart';

/// 卡片容器
///
/// 设计语言：数字优先（Linear / Things 3 风格）
/// 根据自定义背景的 cardMode 呈现三种样式：
/// - CardMode.solid：纯色背景 + 1px 描边（默认，无背景可见）
/// - CardMode.glass：毛玻璃（BackdropFilter 模糊 + 半透明色 + 描边）
/// - CardMode.transparent：半透明纯色（背景清晰透出，无模糊）
///
/// 保留 API（child/padding/borderRadius/color）向后兼容
class GlassCard extends ConsumerWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(customBackgroundsProvider).active;
    final mode = active?.cardMode ?? CardMode.solid;
    final glassBlur = active?.glassBlur ?? 12.0;
    final glassColor = active != null ? Color(active.glassColor) : Colors.white;
    final glassAlpha = active?.glassAlpha ?? 0.3;

    final cardColor = color ?? AppTheme.cardColor;

    switch (mode) {
      case CardMode.glass:
        // 毛玻璃：背景模糊后透出卡片
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: glassBlur,
              sigmaY: glassBlur,
              tileMode: TileMode.clamp,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: glassColor.withValues(alpha: glassAlpha),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: AppTheme.dividerColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        );
      case CardMode.transparent:
        // 半透明纯色：背景清晰透出，无模糊
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: glassColor.withValues(alpha: glassAlpha),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppTheme.dividerColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: child,
        );
      case CardMode.solid:
      default:
        // 纯色卡片 + 1px 描边
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.dividerColor, width: 1),
          ),
          child: child,
        );
    }
  }
}
