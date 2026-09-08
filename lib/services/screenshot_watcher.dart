import 'package:flutter/services.dart';

/// 截屏监听桥（Android）：启动原生媒体库监听，
/// 检测到新截图时回调 [onScreenshot]（图片已复制到应用缓存目录）。
class ScreenshotWatcher {
  ScreenshotWatcher._();

  static const MethodChannel _channel =
      MethodChannel('smart_ledger/screenshot');

  /// 截屏图片回调（path 为本地缓存文件路径）
  static void Function(String path)? onScreenshot;

  static bool _started = false;

  static bool get isStarted => _started;

  /// 启动监听。返回 started / no_permission / error。
  /// [requestPermission] 为 true 时，若缺权限会自动发起系统权限请求
  /// （App 冷启动自动开启时传 false，避免每次启动都弹权限框）。
  static Future<String> start({bool requestPermission = true}) async {
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshot') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          onScreenshot?.call(path);
        }
      }
      return null;
    });
    try {
      return await _channel.invokeMethod<String>(
              'startWatch', {'request': requestPermission}) ??
          'error';
    } catch (_) {
      return 'error';
    }
  }

  static Future<void> stop() async {
    _started = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod('stopWatch');
    } catch (_) {}
  }

  /// 查询原生侧监听是否真正生效（权限授予后需重新查询）
  static Future<bool> isWatching() async {
    try {
      return await _channel.invokeMethod<bool>('isWatching') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳转到系统应用设置页（引导用户授予照片权限）
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }
}
