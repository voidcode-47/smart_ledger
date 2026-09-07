import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/theme_providers.dart';

/// 全局背景：柔和渐变 + 淡光斑（清爽记账风；支持多套背景主题切换）
class GradientBackground extends ConsumerWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(backgroundThemeProvider);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.gradientStart, theme.gradientEnd],
        ),
      ),
      child: Stack(
        children: [
          // 右上光斑
          Positioned(
            top: -100,
            right: -80,
            child: _blob(theme.blob1.withValues(alpha: 0.12), 280),
          ),
          // 左下光斑
          Positioned(
            bottom: -120,
            left: -100,
            child: _blob(theme.blob2.withValues(alpha: 0.16), 320),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
