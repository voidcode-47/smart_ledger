import 'package:flutter/material.dart';

/// 响应式断点工具
/// - 手机竖屏 (1080x2400 逻辑宽约 411dp)  -> compact 布局（底部导航 + FAB）
/// - 桌面窗口 (1366x768 逻辑宽 1366dp)   -> 宽布局（侧边 NavigationRail）
class Responsive {
  Responsive._();

  /// 手机 / 平板分界
  static const double wideBreakpoint = 700;

  /// 桌面端侧边栏布局分界
  static const double desktopBreakpoint = 800;

  static bool isWide(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= wideBreakpoint;

  static bool isDesktop(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= desktopBreakpoint;
}
