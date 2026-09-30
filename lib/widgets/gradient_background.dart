import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_theme.dart';
import '../viewmodels/theme_providers.dart';

/// 全局背景
///
/// 设计语言：数字优先（默认纯色背景，无渐变无模糊）
/// 自定义背景图片时，所有效果（模糊/滤镜/暗角/遮罩/玻璃拟态）均为可选，
/// 默认全部关闭，保持性能与简洁。
class GradientBackground extends ConsumerWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  /// 滤镜矩阵（ColorFilter.matrix，5x4 = 20 个值）
  static const List<double> _kMonoMatrix = [
    0.299, 0.587, 0.114, 0, 0, //
    0.299, 0.587, 0.114, 0, 0,
    0.299, 0.587, 0.114, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _kSepiaMatrix = [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _kCoolMatrix = [
    1.0, 0, 0, 0, 0, //
    0, 1.0, 0, 0, 0,
    0, 0, 1.25, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<double> _kWarmMatrix = [
    1.25, 0, 0, 0, 0, //
    0, 1.0, 0, 0, 0,
    0, 0, 0.9, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double>? _filterMatrix(int filter) {
    switch (filter) {
      case BgFilter.mono:
        return _kMonoMatrix;
      case BgFilter.sepia:
        return _kSepiaMatrix;
      case BgFilter.cool:
        return _kCoolMatrix;
      case BgFilter.warm:
        return _kWarmMatrix;
      default:
        return null;
    }
  }

  /// 构建背景图：按需叠加 透明度 → 滤镜 → 模糊，避免不必要的图层合成
  static Widget _buildImage(CustomBackgroundItem item, List<double>? filter) {
    Widget img = Image.file(
      File(item.path),
      fit: _fit(item.fitMode),
      filterQuality: FilterQuality.medium,
    );
    if (filter != null) {
      img = ColorFiltered(colorFilter: ColorFilter.matrix(filter), child: img);
    }
    if (item.opacity < 1.0) {
      img = Opacity(opacity: item.opacity, child: img);
    }
    if (item.blur > 0) {
      img = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: item.blur,
          sigmaY: item.blur,
          tileMode: TileMode.clamp,
        ),
        child: img,
      );
    }
    return img;
  }

  static BoxFit _fit(int mode) {
    switch (mode) {
      case BgFit.contain:
        return BoxFit.contain;
      case BgFit.fill:
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(backgroundThemeProvider);
    final custom = ref.watch(customBackgroundsProvider).active;

    final hasCustom = custom != null && File(custom.path).existsSync();
    final filter = hasCustom ? _filterMatrix(custom.filter) : null;

    return ColoredBox(
      color: AppTheme.background,
      child: Stack(
        children: [
          if (hasCustom) ...[
            // 1) 背景图：仅在有模糊时才包 ImageFiltered（sigma=0 时避免多余合成）
            Positioned.fill(
              child: _buildImage(custom, filter),
            ),
            // 2) 暗角（中心透明，边缘按 vignette 强度发黑）
            if (custom.vignette > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.8,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: custom.vignette),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            // 3) 遮罩层（自定义颜色 + 透明度）
            if (custom.maskAlpha > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: Color(custom.maskColor)
                      .withValues(alpha: custom.maskAlpha),
                ),
              ),
            // 玻璃拟态效果移至 GlassCard 卡片层（卡片为毛玻璃，背景保持清晰）
          ],
          child,
        ],
      ),
    );
  }
}
