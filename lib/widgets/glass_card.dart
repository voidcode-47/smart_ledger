import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// 玻璃拟态卡片：背景高斯模糊 + 半透明渐变填充 + 顶部高光描边 + 柔影
/// （Glassmorphism：frosted glass / light reflection / z-depth）
///
/// 传入 [color] 时使用指定纯色填充（不随主题做透明渐变），
/// 但仍保留模糊、描边与阴影，保证视觉统一。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppTheme.glassShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppTheme.glassBlurSigma,
            sigmaY: AppTheme.glassBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: color != null
                    ? [color!, color!]
                    : [AppTheme.glassFillStrong, AppTheme.glassFill],
              ),
              borderRadius: radius,
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
