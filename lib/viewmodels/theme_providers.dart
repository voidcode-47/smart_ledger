import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme_config.dart';

/// 一张自定义背景：图片 + 透明度
class CustomBackgroundItem {
  const CustomBackgroundItem({
    required this.id,
    required this.path,
    this.opacity = 0.85,
  });

  final String id;
  final String path;

  /// 图片不透明度（0.2 ~ 1.0）
  final double opacity;

  CustomBackgroundItem copyWith({double? opacity}) {
    return CustomBackgroundItem(
      id: id,
      path: path,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'opacity': opacity,
      };

  static CustomBackgroundItem fromJson(Map<String, dynamic> m) {
    return CustomBackgroundItem(
      id: m['id'] as String,
      path: m['path'] as String,
      opacity: (m['opacity'] as num?)?.toDouble() ?? 0.85,
    );
  }
}

/// 自定义背景集合状态：多张背景 + 当前激活项
class CustomBackgroundsState {
  const CustomBackgroundsState({required this.items, this.activeId});

  final List<CustomBackgroundItem> items;
  final String? activeId;

  CustomBackgroundItem? get active {
    if (items.isEmpty) return null;
    for (final it in items) {
      if (it.id == activeId) return it;
    }
    return items.first;
  }
}

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

/// 自定义背景列表（多张 + 激活项 + 各自透明度），持久化到 shared_preferences
final customBackgroundsProvider =
    StateNotifierProvider<CustomBackgroundsNotifier, CustomBackgroundsState>(
        (ref) => CustomBackgroundsNotifier());

class CustomBackgroundsNotifier
    extends StateNotifier<CustomBackgroundsState> {
  CustomBackgroundsNotifier()
      : super(const CustomBackgroundsState(items: [])) {
    _load();
  }

  /// 背景图片保存目录（应用文档目录/backgrounds）
  static Future<Directory> _bgDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}${Platform.pathSeparator}backgrounds');
    if (!bgDir.existsSync()) bgDir.createSync(recursive: true);
    return bgDir;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ThemeConfig.customBgItemsKey);
      final activeId = prefs.getString(ThemeConfig.customBgActiveKey);

      // 旧版单图数据迁移
      final legacyPath = prefs.getString(ThemeConfig.customBgKey);
      final items = <CustomBackgroundItem>[];
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          try {
            final it = CustomBackgroundItem.fromJson(e as Map<String, dynamic>);
            if (File(it.path).existsSync()) items.add(it);
          } catch (_) {}
        }
      }
      if (items.isEmpty && legacyPath != null && File(legacyPath).existsSync()) {
        items.add(CustomBackgroundItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: legacyPath,
        ));
        await prefs.remove(ThemeConfig.customBgKey);
      }
      if (items.isEmpty) return;

      state = CustomBackgroundsState(
        items: items,
        activeId: (activeId != null && items.any((i) => i.id == activeId))
            ? activeId
            : items.first.id,
      );
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ThemeConfig.customBgItemsKey,
        jsonEncode(state.items.map((e) => e.toJson()).toList()),
      );
      if (state.activeId != null) {
        await prefs.setString(ThemeConfig.customBgActiveKey, state.activeId!);
      }
    } catch (_) {}
  }

  /// 新增一张背景（复制到应用目录）并激活
  Future<bool> addFrom(String sourcePath) async {
    try {
      final dir = await _bgDir();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final target = File('${dir.path}${Platform.pathSeparator}bg_$id.jpg');
      await File(sourcePath).copy(target.path);
      final item = CustomBackgroundItem(id: id, path: target.path);
      state = CustomBackgroundsState(
        items: [...state.items, item],
        activeId: item.id,
      );
      await _persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除一张背景（同时删除文件）
  Future<void> remove(String id) async {
    final target = state.items.where((e) => e.id == id).firstOrNull;
    if (target == null) return;
    final remaining = state.items.where((e) => e.id != id).toList();
    String? nextActive = state.activeId;
    if (state.activeId == id) {
      nextActive = remaining.isEmpty ? null : remaining.first.id;
    }
    state = CustomBackgroundsState(items: remaining, activeId: nextActive);
    try {
      if (File(target.path).existsSync()) File(target.path).deleteSync();
    } catch (_) {}
    await _persist();
  }

  Future<void> setActive(String id) async {
    if (!state.items.any((e) => e.id == id)) return;
    state = CustomBackgroundsState(items: state.items, activeId: id);
    await _persist();
  }

  /// 调节透明度（0.2 ~ 1.0）
  Future<void> setOpacity(String id, double opacity) async {
    final v = opacity.clamp(0.2, 1.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items)
          e.id == id ? e.copyWith(opacity: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 用裁剪后的新文件替换指定背景（删除旧文件）
  Future<void> replaceWithCropped(String id, String croppedPath) async {
    final target = state.items.where((e) => e.id == id).firstOrNull;
    if (target == null) return;
    try {
      if (File(target.path).existsSync()) File(target.path).deleteSync();
      await File(croppedPath).copy(target.path);
    } catch (_) {
      return;
    }
    state = CustomBackgroundsState(items: state.items, activeId: state.activeId);
    await _persist();
  }

  /// 清空全部自定义背景
  Future<void> clearAll() async {
    for (final e in state.items) {
      try {
        if (File(e.path).existsSync()) File(e.path).deleteSync();
      } catch (_) {}
    }
    state = const CustomBackgroundsState(items: []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ThemeConfig.customBgItemsKey);
      await prefs.remove(ThemeConfig.customBgActiveKey);
    } catch (_) {}
  }
}
