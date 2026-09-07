import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme_config.dart';

/// 当前背景主题（持久化到 shared_preferences）
final backgroundThemeProvider =
    StateNotifierProvider<BackgroundThemeNotifier, BackgroundTheme>(
        (ref) => BackgroundThemeNotifier());

class BackgroundThemeNotifier extends StateNotifier<BackgroundTheme> {
  BackgroundThemeNotifier() : super(ThemeConfig.backgrounds.first) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(ThemeConfig.prefKey);
      if (id != null && id != state.id) {
        state = ThemeConfig.byId(id);
      }
    } catch (_) {
      // 读取失败保持默认主题
    }
  }

  Future<void> setTheme(BackgroundTheme theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ThemeConfig.prefKey, theme.id);
    } catch (_) {
      // 持久化失败不影响本次切换
    }
  }
}

/// 自定义背景图片路径（null 表示未启用）
final customBackgroundProvider =
    StateNotifierProvider<CustomBackgroundNotifier, String?>(
        (ref) => CustomBackgroundNotifier());

class CustomBackgroundNotifier extends StateNotifier<String?> {
  CustomBackgroundNotifier() : super(null) {
    _load();
  }

  /// 自定义背景图片的保存位置（应用文档目录）
  static Future<File> _targetFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}${Platform.pathSeparator}backgrounds');
    if (!bgDir.existsSync()) bgDir.createSync(recursive: true);
    return File('${bgDir.path}${Platform.pathSeparator}custom_bg.jpg');
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString(ThemeConfig.customBgKey);
      if (p != null && File(p).existsSync()) state = p;
    } catch (_) {}
  }

  /// 保存新背景图片（复制到应用目录，避免临时文件被清理）
  Future<bool> setFrom(String sourcePath) async {
    try {
      final target = await _targetFile();
      await File(sourcePath).copy(target.path);
      state = target.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ThemeConfig.customBgKey, target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 清除自定义背景，恢复主题色背景
  Future<void> clear() async {
    final current = state;
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ThemeConfig.customBgKey);
      if (current != null && File(current).existsSync()) {
        File(current).deleteSync();
      }
    } catch (_) {}
  }
}
