import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/app_theme.dart';
import '../../viewmodels/theme_providers.dart';
import '../../widgets/crop_screen.dart';
import '../../widgets/glass_card.dart';

/// 自定义背景管理：多张背景列表、添加/删除/切换、
/// 透明度调节、框选区域裁剪
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customBackgroundsProvider);

    return Scaffold(
      backgroundColor: AppTheme.cardColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
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
                    content: const Text('将删除所有已添加的背景图片，恢复主题色背景。'),
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
          GlassCard(
            color: AppTheme.cardColor,
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
                          fontSize: 13,
                          color: AppTheme.onSurface(alpha: 0.55)),
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
                                        : AppTheme.onSurface(alpha: 0.08),
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
                                      color: Colors.black
                                          .withValues(alpha: 0.45),
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
          _actionCard(
            icon: Icons.add_photo_alternate_outlined,
            title: '添加背景图片',
            subtitle: '从相册 / 文件管理器选择图片，可添加多张',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _busy ? null : _pickAdd,
          ),
          const SizedBox(height: 12),
          GlassCard(
            color: AppTheme.cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('透明度', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  state.active == null
                      ? '先添加一张背景'
                      : '调整图片不透明度（越往右越清晰）',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurface(alpha: 0.55)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.opacity_rounded,
                        size: 20,
                        color: AppTheme.onSurface(alpha: 0.50)),
                    Expanded(
                      child: Slider(
                        value: state.active?.opacity ?? 0.85,
                        min: 0.2,
                        max: 1.0,
                        divisions: 16,
                        activeColor: AppTheme.accent,
                        onChanged: state.active == null
                            ? null
                            : (v) => ref
                                .read(customBackgroundsProvider.notifier)
                                .setOpacity(state.active!.id, v),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${((state.active?.opacity ?? 0.85) * 100).round()}%',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _actionCard(
            icon: Icons.crop_free_rounded,
            title: '框选背景区域',
            subtitle: '手动框选图片中想要的区域作为背景（可去掉多余部分）',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: state.active == null ? null : _cropActive,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '提示：开启图片背景后，App 底部页面的文字会自动加遮罩保证可读。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.onSurface(alpha: 0.45)),
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
    required Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GlassCard(
      color: AppTheme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.onSurface(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
