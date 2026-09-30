import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_theme.dart';
import '../viewmodels/theme_providers.dart';

/// 全局背景：柔和渐变 + 淡光斑（清爽记账风；支持多套背景主题切换）
/// 若启用了自定义背景图片，则优先显示图片：
/// - 图片不透明度由 CustomBackgroundItem.opacity 控制
/// - 叠加与透明度反向的白色遮罩，保证文字始终可读
class GradientBackground extends ConsumerWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(backgroundThemeProvider);
    final custom = ref.watch(customBackgroundsProvider).active;

    final hasCustom = custom != null && File(custom.path).existsSync();
    // 图片越不透明，遮罩越淡（保证可读性的同时保留图片观感）
    final maskAlpha = 0.55 * (1.0 - (custom?.opacity ?? 1.0));

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
          if (hasCustom) ...[
            // 自定义背景图：全屏铺满，透明度可调
            Positioned.fill(
              child: Opacity(
                opacity: custom.opacity,
                child: Image.file(
                  File(custom.path),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            // 可读性遮罩（透明度反向）
            Positioned.fill(
              child: ColoredBox(
                  color: Colors.white.withValues(alpha: maskAlpha)),
            ),
          ] else ...[
            // 右上光斑（高斯模糊成柔光，供玻璃卡片透出层次）
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
            // 中上主色微光，让整体不再是纯灰白底
            Positioned(
              top: 180,
              left: -120,
              child: _blob(
                AppTheme.accentLight
                    .withValues(alpha: theme.isDark ? 0.10 : 0.08),
                260,
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size, {double sigma = 55}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
