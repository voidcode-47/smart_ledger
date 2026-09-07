import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局异常捕获与崩溃日志：
/// - 捕获 Dart 层未处理异常，写入应用文档目录 crash.log
/// - 启动时检查日志，若上次运行出现异常则弹窗展示，支持一键复制发给开发者
/// 说明：原生层（如 ML Kit JNI）崩溃无法被 Dart 捕获，但本日志能覆盖绝大多数
/// Dart 层问题；日志为空时的原生崩溃，需结合机型/系统信息排查。
class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  File? _logFile;
  bool _installed = false;

  Future<File> _ensureFile() async {
    if (_logFile != null) return _logFile!;
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}crash.log');
    _logFile = f;
    return f;
  }

  /// 安装全局异常捕获（在 runApp 前调用一次）
  Future<void> install() async {
    if (_installed) return;
    _installed = true;
    await _ensureFile();

    FlutterError.onError = (details) {
      _write('FlutterError: ${details.exception}\n${details.stack}');
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _write('Uncaught: $error\n$stack');
      // 返回 true：阻止默认闪退，界面继续可用（便于用户看到提示后反馈）
      return true;
    };
  }

  void _write(String body) {
    final f = _logFile;
    if (f == null) return;
    try {
      final entry = '==== ${DateTime.now()} ====\n$body\n\n';
      f.writeAsStringSync(entry, mode: FileMode.append);
      // 防日志无限增长：超过 64KB 时保留最近 32KB
      if (f.lengthSync() > 64 * 1024) {
        final all = f.readAsStringSync();
        f.writeAsStringSync(all.substring(all.length - 32 * 1024));
      }
    } catch (_) {
      // 日志写入失败不影响应用
    }
  }

  /// 读取崩溃日志全文（空串表示无记录）
  Future<String> readLog() async {
    try {
      final f = await _ensureFile();
      if (!await f.exists()) return '';
      final content = await f.readAsString();
      return content.trim();
    } catch (_) {
      return '';
    }
  }

  /// 清空日志（用户确认查看后）
  Future<void> clear() async {
    try {
      final f = await _ensureFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
