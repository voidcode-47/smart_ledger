import 'package:flutter_riverpod/flutter_riverpod.dart';
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
