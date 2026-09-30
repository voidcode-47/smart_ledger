import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';
import '../utils/theme_config.dart';

/// 滤镜预设索引
abstract class BgFilter {
  static const int none = 0;
  static const int mono = 1; // 黑白
  static const int sepia = 2; // 怀旧
  static const int cool = 3; // 冷调
  static const int warm = 4; // 暖调
}

/// 卡片呈现模式
abstract class CardMode {
  static const int solid = 0; // 纯色不透明卡片（默认，无背景可见）
  static const int glass = 1; // 毛玻璃卡片（背景模糊后透出）
  static const int transparent = 2; // 半透明纯色卡片（背景清晰透出，无模糊）
}

/// 图片填充方式
abstract class BgFit {
  static const int cover = 0;
  static const int contain = 1;
  static const int fill = 2;
}

/// 文字取色模式
abstract class BgTextMode {
  static const int auto = -1;
  static const int forceLight = 0;
  static const int forceDark = 1;
}

/// 一张自定义背景：图片 + 透明度 + 丰富效果（全部可选，默认关闭）
class CustomBackgroundItem {
  const CustomBackgroundItem({
    required this.id,
    required this.path,
    this.opacity = 0.85,
    this.blur = 0.0,
    this.filter = BgFilter.none,
    this.vignette = 0.0,
    this.maskColor = 0xFFFFFFFF,
    this.maskAlpha = 0.0,
    this.cardMode = CardMode.solid,
    this.glassBlur = 12.0,
    this.glassColor = 0xFFFFFFFF,
    this.glassAlpha = 0.3,
    this.fitMode = BgFit.cover,
    this.textMode = BgTextMode.auto,
  });

  final String id;
  final String path;

  /// 图片不透明度（0.2 ~ 1.0）
  final double opacity;

  /// 图片高斯模糊 sigma（0 ~ 20）
  final double blur;

  /// 滤镜预设（BgFilter.*）
  final int filter;

  /// 暗角强度（0 ~ 1）
  final double vignette;

  /// 遮罩颜色（ARGB int）
  final int maskColor;

  /// 遮罩透明度（0 ~ 1）
  final double maskAlpha;

  /// 卡片呈现模式（CardMode.*：solid / glass / transparent）
  final int cardMode;

  /// 玻璃层模糊 sigma（0 ~ 30）
  final double glassBlur;

  /// 玻璃层颜色（ARGB int）
  final int glassColor;

  /// 玻璃层透明度（0 ~ 1）
  final double glassAlpha;

  /// 图片填充方式（BgFit.*）
  final int fitMode;

  /// 文字取色模式（BgTextMode.*）
  final int textMode;

  CustomBackgroundItem copyWith({
    double? opacity,
    double? blur,
    int? filter,
    double? vignette,
    int? maskColor,
    double? maskAlpha,
    int? cardMode,
    double? glassBlur,
    int? glassColor,
    double? glassAlpha,
    int? fitMode,
    int? textMode,
  }) {
    return CustomBackgroundItem(
      id: id,
      path: path,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      filter: filter ?? this.filter,
      vignette: vignette ?? this.vignette,
      maskColor: maskColor ?? this.maskColor,
      maskAlpha: maskAlpha ?? this.maskAlpha,
      cardMode: cardMode ?? this.cardMode,
      glassBlur: glassBlur ?? this.glassBlur,
      glassColor: glassColor ?? this.glassColor,
      glassAlpha: glassAlpha ?? this.glassAlpha,
      fitMode: fitMode ?? this.fitMode,
      textMode: textMode ?? this.textMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'opacity': opacity,
        'blur': blur,
        'filter': filter,
        'vignette': vignette,
        'maskColor': maskColor,
        'maskAlpha': maskAlpha,
        'cardMode': cardMode,
        'glassBlur': glassBlur,
        'glassColor': glassColor,
        'glassAlpha': glassAlpha,
        'fitMode': fitMode,
        'textMode': textMode,
      };

  static CustomBackgroundItem fromJson(Map<String, dynamic> m) {
    return CustomBackgroundItem(
      id: m['id'] as String,
      path: m['path'] as String,
      opacity: (m['opacity'] as num?)?.toDouble() ?? 0.85,
      blur: (m['blur'] as num?)?.toDouble() ?? 0.0,
      filter: (m['filter'] as num?)?.toInt() ?? BgFilter.none,
      vignette: (m['vignette'] as num?)?.toDouble() ?? 0.0,
      maskColor: (m['maskColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      maskAlpha: (m['maskAlpha'] as num?)?.toDouble() ?? 0.0,
      // 兼容旧数据：旧版 glassEnabled=true 映射为 glass 模式
      cardMode: (m['cardMode'] as num?)?.toInt() ??
          ((m['glassEnabled'] as bool?) ?? false
              ? CardMode.glass
              : CardMode.solid),
      glassBlur: (m['glassBlur'] as num?)?.toDouble() ?? 12.0,
      glassColor: (m['glassColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      glassAlpha: (m['glassAlpha'] as num?)?.toDouble() ?? 0.3,
      fitMode: (m['fitMode'] as num?)?.toInt() ?? BgFit.cover,
      textMode: (m['textMode'] as num?)?.toInt() ?? BgTextMode.auto,
    );
  }
}

/// 自定义背景集合状态：多张背景 + 当前激活项
class CustomBackgroundsState {
  const CustomBackgroundsState({required this.items, this.activeId});

  final List<CustomBackgroundItem> items;
  final String? activeId;

  CustomBackgroundItem? get active {
    // activeId 为 null 表示用户已显式停用（例如选择了主题），不得回退到第一张
    if (items.isEmpty || activeId == null) return null;
    for (final it in items) {
      if (it.id == activeId) return it;
    }
    return null;
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

class CustomBackgroundsNotifier extends StateNotifier<CustomBackgroundsState> {
  CustomBackgroundsNotifier() : super(const CustomBackgroundsState(items: [])) {
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
      var activeId = prefs.getString(ThemeConfig.customBgActiveKey);

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
      var migrated = false;
      if (items.isEmpty &&
          legacyPath != null &&
          File(legacyPath).existsSync()) {
        items.add(CustomBackgroundItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: legacyPath,
        ));
        // 迁移的旧版单图：默认激活，并立即持久化
        activeId = items.first.id;
        migrated = true;
        await prefs.remove(ThemeConfig.customBgKey);
      }
      if (items.isEmpty) return;

      // 关键修复：activeId 为 null 表示用户已显式停用（例如选择了背景主题），
      // 重启后不得回退激活第一张，否则会覆盖用户切换主题的意图。
      state = CustomBackgroundsState(
        items: items,
        activeId: resolveActiveId(
          [for (final i in items) i.id],
          activeId,
          // 仅真正执行了旧版迁移时才默认激活
          migratedId: migrated ? items.first.id : null,
        ),
      );
      // 恢复用户上次选择的文字取色模式
      final a = state.active;
      if (a != null) {
        switch (a.textMode) {
          case BgTextMode.forceLight:
            AppTheme.setDark(true);
            break;
          case BgTextMode.forceDark:
            AppTheme.setDark(false);
            break;
        }
      }
      // 持久化本次解析结果（含迁移），保证与磁盘状态一致
      await _persist();
    } catch (_) {}
  }

  /// 解析最终激活项（纯函数，便于单元测试）：
  /// - [activeId] 有效（存在于 [itemIds]）时使用它；
  /// - 否则只有在旧版单图迁移场景（[migratedId]）下才默认激活；
  /// - 其余情况返回 null（保持停用，绝不回退第一张）。
  @visibleForTesting
  static String? resolveActiveId(
    List<String> itemIds,
    String? activeId, {
    String? migratedId,
  }) {
    if (activeId != null && itemIds.contains(activeId)) return activeId;
    if (migratedId != null && itemIds.contains(migratedId)) return migratedId;
    return null;
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
      } else {
        // 无激活项时清理旧 key，避免残留导致下次启动误判
        await prefs.remove(ThemeConfig.customBgActiveKey);
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

  /// 停用自定义背景（保留图片列表，仅不再作为背景显示）。
  /// 用户显式选择主题时调用，保证主题切换立即生效。
  Future<void> deactivate() async {
    if (state.items.isEmpty) return;
    state = CustomBackgroundsState(items: state.items, activeId: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ThemeConfig.customBgActiveKey);
    } catch (_) {}
  }

  /// 调节透明度（0.2 ~ 1.0）
  Future<void> setOpacity(String id, double opacity) async {
    final v = opacity.clamp(0.2, 1.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(opacity: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 图片高斯模糊 sigma（0 ~ 20）
  Future<void> setBlur(String id, double blur) async {
    final v = blur.clamp(0.0, 20.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(blur: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 滤镜预设（BgFilter.*）
  Future<void> setFilter(String id, int filter) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(filter: filter) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 暗角强度（0 ~ 1）
  Future<void> setVignette(String id, double vignette) async {
    final v = vignette.clamp(0.0, 1.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(vignette: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 遮罩颜色（ARGB int）
  Future<void> setMaskColor(String id, int color) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(maskColor: color) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 遮罩透明度（0 ~ 1）
  Future<void> setMaskAlpha(String id, double alpha) async {
    final v = alpha.clamp(0.0, 1.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(maskAlpha: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 卡片呈现模式（CardMode.*）
  Future<void> setCardMode(String id, int mode) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items)
          e.id == id ? e.copyWith(cardMode: mode) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 玻璃层模糊 sigma（0 ~ 30）
  Future<void> setGlassBlur(String id, double blur) async {
    final v = blur.clamp(0.0, 30.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(glassBlur: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 玻璃层颜色（ARGB int）
  Future<void> setGlassColor(String id, int color) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(glassColor: color) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 玻璃层透明度（0 ~ 1）
  Future<void> setGlassAlpha(String id, double alpha) async {
    final v = alpha.clamp(0.0, 1.0);
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(glassAlpha: v) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 图片填充方式（BgFit.*）
  Future<void> setFitMode(String id, int fit) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(fitMode: fit) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 文字取色模式（BgTextMode.*）
  Future<void> setTextMode(String id, int mode) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items) e.id == id ? e.copyWith(textMode: mode) : e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 重置当前背景的所有效果为默认（保留图片与透明度）
  Future<void> resetEffects(String id) async {
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items)
          if (e.id == id)
            CustomBackgroundItem(id: e.id, path: e.path, opacity: e.opacity)
          else
            e,
      ],
      activeId: state.activeId,
    );
    await _persist();
  }

  /// 应用推荐预设：背景清晰 + 文字清晰（遮罩 35% + 卡片玻璃 45%）
  Future<void> applyRecommended(String id) async {
    final dark = AppTheme.isDark;
    final maskColor = dark ? 0xFF000000 : 0xFFFFFFFF;
    final glassColor = dark ? 0xFF141414 : 0xFFFFFFFF;
    state = CustomBackgroundsState(
      items: [
        for (final e in state.items)
          if (e.id == id)
            e.copyWith(
              opacity: 0.7,
              blur: 0.0,
              filter: BgFilter.none,
              vignette: 0.0,
              maskColor: maskColor,
              maskAlpha: 0.35,
              cardMode: CardMode.glass,
              glassBlur: 12.0,
              glassColor: glassColor,
              glassAlpha: 0.45,
              fitMode: BgFit.cover,
              textMode: BgTextMode.auto,
            )
          else
            e,
      ],
      activeId: state.activeId,
    );
    // 同步文字取色
    AppTheme.setDark(dark);
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
    state =
        CustomBackgroundsState(items: state.items, activeId: state.activeId);
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
