import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/app_theme.dart';
import '../../viewmodels/theme_providers.dart';
import '../../widgets/crop_screen.dart';
import '../../widgets/glass_card.dart';

/// 自定义背景管理：多张背景列表 + 丰富效果调节
/// （模糊 / 滤镜 / 暗角 / 遮罩 / 玻璃拟态 / 填充 / 文字取色）
class BackgroundManagerScreen extends ConsumerStatefulWidget {
  const BackgroundManagerScreen({super.key});

  @override
  ConsumerState<BackgroundManagerScreen> createState() =>
      _BackgroundManagerScreenState();
}

class _BackgroundManagerScreenState
    extends ConsumerState<BackgroundManagerScreen> {
  bool _busy = false;

  Future<void> _pickAdd() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await ref.read(customBackgroundsProvider.notifier).addFrom(path);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(ok ? '背景已添加并启用' : '添加失败，请重试');
  }

  Future<void> _cropActive() async {
    final active = ref.read(customBackgroundsProvider).active;
    if (active == null) return;
    final cropped = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CropScreen(imagePath: active.path),
      ),
    );
    if (cropped == null || !mounted) return;
    await ref
        .read(customBackgroundsProvider.notifier)
        .replaceWithCropped(active.id, cropped);
    _toast('已应用框选区域');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 同步文字取色模式到全局 AppTheme
  void _applyTextMode(int mode) {
    final theme = ref.read(backgroundThemeProvider);
    switch (mode) {
      case BgTextMode.forceLight:
        AppTheme.setDark(true);
        break;
      case BgTextMode.forceDark:
        AppTheme.setDark(false);
        break;
      default:
        AppTheme.setDark(theme.isDark);
    }
  }

  // ---------- 通用控件 ----------

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _sliderRow({
    required IconData icon,
    required String label,
    required String value,
    required double min,
    required double max,
    required double current,
    int divisions = 20,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: current,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.accent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  /// 预设色块选择器
  Widget _colorPicker({
    required int current,
    required ValueChanged<int> onSelect,
  }) {
    const swatches = [
      0xFFFFFFFF, 0xFF000000, 0xFF0F766E, 0xFFDC2626,
      0xFF2563EB, 0xFF737373, 0x80FFFFFF, 0x80000000,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in swatches)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: current == c
                      ? AppTheme.accent
                      : AppTheme.dividerColor,
                  width: current == c ? 2.5 : 1,
                ),
              ),
              child: current == c
                  ? Icon(Icons.check_rounded,
                      size: 16,
                      color: c == 0xFF0F766E ? Colors.white : AppTheme.accent)
                  : null,
            ),
          ),
      ],
    );
  }

  // ---------- 实时预览 ----------

  static const List<double> _kMonoMatrix = [
    0.299, 0.587, 0.114, 0, 0, 0.299, 0.587, 0.114, 0, 0, //
    0.299, 0.587, 0.114, 0, 0, 0, 0, 0, 1, 0,
  ];
  static const List<double> _kSepiaMatrix = [
    0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0,
  ];
  static const List<double> _kCoolMatrix = [
    1.0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, //
    0, 0, 1.25, 0, 0, 0, 0, 0, 1, 0,
  ];
  static const List<double> _kWarmMatrix = [
    1.25, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, //
    0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0,
  ];

  List<double>? _filterMatrix(int f) {
    switch (f) {
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

  BoxFit _fit(int mode) {
    switch (mode) {
      case BgFit.contain:
        return BoxFit.contain;
      case BgFit.fill:
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  /// 实时预览卡片：背景图 + 所有效果 + 示例玻璃卡片
  Widget _previewCard(CustomBackgroundItem item) {
    final filter = _filterMatrix(item.filter);
    final exists = File(item.path).existsSync();

    return Container(
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor, width: 1),
      ),
      child: Stack(
        children: [
          // 背景层
          Positioned.fill(
            child: ColoredBox(
              color: AppTheme.background,
              child: exists
                  ? _buildPreviewImage(item, filter)
                  : Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AppTheme.textHint)),
            ),
          ),
          if (exists && item.vignette > 0)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: item.vignette),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
          if (exists && item.maskAlpha > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Color(item.maskColor).withValues(alpha: item.maskAlpha),
              ),
            ),
          // 标签
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('实时预览',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ),
          ),
          // 示例玻璃卡片
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 14,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_rounded,
                        size: 18, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('示例卡片',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('调节参数即时生效',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Text('-¥38.50',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage(CustomBackgroundItem item, List<double>? filter) {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customBackgroundsProvider);
    final active = state.active;
    final no = active == null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('自定义背景'),
        actions: [
          if (state.items.isNotEmpty)
            IconButton(
              tooltip: '清空全部背景',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardColor,
                    title: const Text('清空全部背景？'),
                    content:
                        const Text('将删除所有已添加的背景图片，恢复主题色背景。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.expenseColor,
                            foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
                if (yes == true) {
                  await ref
                      .read(customBackgroundsProvider.notifier)
                      .clearAll();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 背景列表
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('背景列表（${state.items.length}）',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                if (state.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '还没有自定义背景，点下方按钮添加一张图片',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textHint),
                    ),
                  )
                else
                  SizedBox(
                    height: 128,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final it = state.items[i];
                        final isActive = it.id == state.activeId;
                        return GestureDetector(
                          onTap: () => ref
                              .read(customBackgroundsProvider.notifier)
                              .setActive(it.id),
                          child: Stack(
                            children: [
                              Container(
                                width: 96,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? AppTheme.accent
                                        : AppTheme.dividerColor,
                                    width: isActive ? 2.5 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Opacity(
                                  opacity: it.opacity,
                                  child: Image.file(
                                    File(it.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: GestureDetector(
                                  onTap: () => ref
                                      .read(customBackgroundsProvider.notifier)
                                      .remove(it.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!no) _previewCard(active),
          if (!no) const SizedBox(height: 14),
          if (!no)
            _actionCard(
              icon: Icons.auto_awesome_rounded,
              title: '应用推荐设置',
              subtitle: '背景清晰 + 文字清晰（遮罩 35% · 玻璃 45%）',
              onTap: () => ref
                  .read(customBackgroundsProvider.notifier)
                  .applyRecommended(active.id),
            ),
          if (!no) const SizedBox(height: 14),
          _actionCard(
            icon: Icons.add_photo_alternate_outlined,
            title: '添加背景图片',
            subtitle: '从相册 / 文件管理器选择图片，可添加多张',
            onTap: _busy ? null : _pickAdd,
          ),
          const SizedBox(height: 14),

          // 以下控件仅在有激活背景时可用
          if (no)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text('选择一张背景后即可调节效果',
                  style: TextStyle(color: AppTheme.textHint)),
            )
          else ...[
            // 基础：透明度 + 填充方式
            _sectionCard(
              title: '基础',
              children: [
                _sliderRow(
                  icon: Icons.opacity_rounded,
                  label: '不透明度',
                  value: '${(active.opacity * 100).round()}%',
                  min: 0.2,
                  max: 1.0,
                  current: active.opacity,
                  divisions: 16,
                  onChanged: (v) => ref
                      .read(customBackgroundsProvider.notifier)
                      .setOpacity(active.id, v),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.fit_screen_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    const Text('填充方式', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: BgFit.cover, label: Text('铺满')),
                        ButtonSegment(value: BgFit.contain, label: Text('完整')),
                        ButtonSegment(value: BgFit.fill, label: Text('拉伸')),
                      ],
                      selected: {active.fitMode},
                      onSelectionChanged: (s) => ref
                          .read(customBackgroundsProvider.notifier)
                          .setFitMode(active.id, s.first),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 图片处理：模糊 + 滤镜 + 暗角
            _sectionCard(
              title: '图片处理',
              children: [
                _sliderRow(
                  icon: Icons.blur_on_rounded,
                  label: '模糊',
                  value: active.blur.toStringAsFixed(1),
                  min: 0,
                  max: 20,
                  current: active.blur,
                  onChanged: (v) => ref
                      .read(customBackgroundsProvider.notifier)
                      .setBlur(active.id, v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.palette_outlined,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    const Text('滤镜', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final f in const [
                          MapEntry('原图', BgFilter.none),
                          MapEntry('黑白', BgFilter.mono),
                          MapEntry('怀旧', BgFilter.sepia),
                          MapEntry('冷调', BgFilter.cool),
                          MapEntry('暖调', BgFilter.warm),
                        ])
                          ChoiceChip(
                            label: Text(f.key,
                                style: const TextStyle(fontSize: 11)),
                            selected: active.filter == f.value,
                            selectedColor: AppTheme.accent,
                            backgroundColor: AppTheme.surface,
                            labelStyle: TextStyle(
                              color: active.filter == f.value
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                            side: BorderSide(
                                color: AppTheme.dividerColor, width: 1),
                            showCheckmark: false,
                            onSelected: (_) => ref
                                .read(customBackgroundsProvider.notifier)
                                .setFilter(active.id, f.value),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _sliderRow(
                  icon: Icons.vignette_rounded,
                  label: '暗角',
                  value: (active.vignette * 100).round().toString(),
                  min: 0,
                  max: 1,
                  current: active.vignette,
                  onChanged: (v) => ref
                      .read(customBackgroundsProvider.notifier)
                      .setVignette(active.id, v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 遮罩层
            _sectionCard(
              title: '遮罩层',
              children: [
                Row(
                  children: [
                    Icon(Icons.layers_outlined,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    const Text('颜色', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                _colorPicker(
                  current: active.maskColor,
                  onSelect: (c) => ref
                      .read(customBackgroundsProvider.notifier)
                      .setMaskColor(active.id, c),
                ),
                const SizedBox(height: 12),
                _sliderRow(
                  icon: Icons.invert_colors_on_outlined,
                  label: '遮罩强度',
                  value: '${(active.maskAlpha * 100).round()}%',
                  min: 0,
                  max: 1,
                  current: active.maskAlpha,
                  onChanged: (v) => ref
                      .read(customBackgroundsProvider.notifier)
                      .setMaskAlpha(active.id, v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 卡片样式
            _sectionCard(
              title: '卡片样式',
              children: [
                Row(
                  children: [
                    Icon(Icons.style_outlined,
                        size: 18, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    const Text('呈现模式', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: CardMode.solid,
                            label: Text('纯色', style: TextStyle(fontSize: 11))),
                        ButtonSegment(
                            value: CardMode.glass,
                            label: Text('毛玻璃', style: TextStyle(fontSize: 11))),
                        ButtonSegment(
                            value: CardMode.transparent,
                            label: Text('半透明', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {active.cardMode},
                      onSelectionChanged: (s) => ref
                          .read(customBackgroundsProvider.notifier)
                          .setCardMode(active.id, s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  active.cardMode == CardMode.solid
                      ? '纯色卡片，背景不显示'
                      : active.cardMode == CardMode.glass
                          ? '毛玻璃：背景模糊后透出，文字最清晰'
                          : '半透明：背景清晰透出，无任何模糊',
                  style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                ),
                if (active.cardMode != CardMode.solid) ...[
                  const SizedBox(height: 10),
                  if (active.cardMode == CardMode.glass)
                    _sliderRow(
                      icon: Icons.blur_circular_rounded,
                      label: '玻璃模糊',
                      value: active.glassBlur.toStringAsFixed(1),
                      min: 0,
                      max: 30,
                      current: active.glassBlur,
                      onChanged: (v) => ref
                          .read(customBackgroundsProvider.notifier)
                          .setGlassBlur(active.id, v),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.color_lens_outlined,
                          size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      const Text('卡片颜色', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _colorPicker(
                    current: active.glassColor,
                    onSelect: (c) => ref
                        .read(customBackgroundsProvider.notifier)
                        .setGlassColor(active.id, c),
                  ),
                  const SizedBox(height: 12),
                  _sliderRow(
                    icon: Icons.invert_colors_outlined,
                    label: '卡片透明度',
                    value: '${(active.glassAlpha * 100).round()}%',
                    min: 0,
                    max: 1,
                    current: active.glassAlpha,
                    onChanged: (v) => ref
                        .read(customBackgroundsProvider.notifier)
                        .setGlassAlpha(active.id, v),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // 文字取色
            _sectionCard(
              title: '文字取色',
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    const Text('文字颜色', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: BgTextMode.auto, label: Text('自动')),
                        ButtonSegment(
                            value: BgTextMode.forceLight, label: Text('浅色')),
                        ButtonSegment(
                            value: BgTextMode.forceDark, label: Text('深色')),
                      ],
                      selected: {active.textMode},
                      onSelectionChanged: (s) {
                        ref
                            .read(customBackgroundsProvider.notifier)
                            .setTextMode(active.id, s.first);
                        _applyTextMode(s.first);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 裁剪 + 重置
            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    icon: Icons.crop_free_rounded,
                    title: '框选背景区域',
                    subtitle: '手动框选想要的区域',
                    onTap: _cropActive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    icon: Icons.restart_alt_rounded,
                    title: '重置效果',
                    subtitle: '恢复默认（仅保留图片与透明度）',
                    onTap: () => ref
                        .read(customBackgroundsProvider.notifier)
                        .resetEffects(active.id),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: Text(
              '所有效果默认关闭；毛玻璃模式卡片会模糊背景，长列表滚动可能掉帧，半透明模式无模糊。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, height: 1.5, color: AppTheme.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
