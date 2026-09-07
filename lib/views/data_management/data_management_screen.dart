import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/backup_service.dart';
import '../../services/biometric_service.dart';
import '../../services/csv_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/theme_config.dart';
import '../../viewmodels/theme_providers.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/glass_card.dart';
import '../category_management/category_management_screen.dart';

/// 数据管理：数据库备份恢复 + CSV 导出/导入 + 生物识别锁（Android）
class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _busy = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      BiometricService.instance.isEnabled().then((v) {
        if (mounted) setState(() => _biometricEnabled = v);
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ));
  }

  // ---------- 外观：自定义背景图片 ----------
  Future<void> _pickCustomBackground() async {
    final hasCustom = ref.read(customBackgroundProvider) != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择图片'),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              if (hasCustom)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('清除自定义背景'),
                  onTap: () => Navigator.pop(ctx, 'clear'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'clear') {
      await ref.read(customBackgroundProvider.notifier).clear();
      _toast('已恢复主题背景');
      return;
    }

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final ok =
          await ref.read(customBackgroundProvider.notifier).setFrom(image.path);
      if (!mounted) return;
      _toast(ok ? '背景已更新' : '背景图片保存失败，请重试');
    } catch (e) {
      if (!mounted) return;
      _toast('无法打开相册：$e');
    }
  }

  // ---------- 外观：背景主题选择 ----------
  Future<void> _pickBackgroundTheme() async {
    final current = ref.read(backgroundThemeProvider);
    final picked = await showDialog<BackgroundTheme>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择背景主题'),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (final t in ThemeConfig.backgrounds)
                _themeOption(ctx, t, current.id == t.id),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(backgroundThemeProvider.notifier).setTheme(picked);
      _toast('背景已切换为「${picked.name}」');
    }
  }

  Widget _themeOption(BuildContext ctx, BackgroundTheme t, bool selected) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, t),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.gradientStart, t.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.dividerColor,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            t.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color:
                  selected ? AppTheme.accent : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _setBusy(bool v) {
    if (mounted) setState(() => _busy = v);
  }

  // ==================== 备份 / 恢复 ====================

  Future<void> _backup() async {
    _setBusy(true);
    try {
      final path = await BackupService.backupDatabase();
      if (!mounted) return;
      _toast(path.isEmpty ? '已取消备份' : '备份完成\n$path');
    } catch (e) {
      if (mounted) _toast('备份失败：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _restore() async {
    // 恢复为破坏性操作，先确认
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('将从备份包覆盖当前数据库，现有数据会被替换。\n恢复完成后界面会自动刷新。是否继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _setBusy(true);
    try {
      final size = await BackupService.restoreDatabase();
      if (!mounted) return;
      if (size < 0) {
        _toast('已取消恢复');
        return;
      }
      // 关键：恢复后统一刷新数据源，避免 UI 引用旧连接闪退
      ref.invalidate(dbInfoProvider);
      await ref.read(transactionListProvider.notifier).reload();
      if (!mounted) return;
      _toast('恢复成功，界面已刷新');
    } catch (e) {
      if (mounted) _toast('恢复失败：$e');
    } finally {
      _setBusy(false);
    }
  }

  // ==================== 生物识别锁（Android） ====================

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final can = await BiometricService.instance.canAuthenticate();
      if (!can) {
        _toast('当前设备不支持指纹 / 面容解锁');
        return;
      }
      // 开启前先验证一次，确保机主本人操作
      final passed = await BiometricService.instance.authenticate();
      if (!passed) {
        _toast('验证未通过，未开启生物识别锁');
        return;
      }
    }
    await BiometricService.instance.setEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  // ==================== CSV 导出 / 导入 ====================

  Future<void> _export() async {
    final entries = ref.read(transactionListProvider).value ?? const [];
    if (entries.isEmpty) {
      _toast('暂无可导出的数据');
      return;
    }
    _setBusy(true);
    try {
      final path = await CsvService.exportCsv(entries);
      if (!mounted) return;
      _toast('已导出 ${entries.length} 条流水\n$path');
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _import() async {
    _setBusy(true);
    try {
      final entries = await CsvService.pickAndParseCsv();
      if (entries.isEmpty) {
        if (mounted) _toast('未解析到有效数据（或已取消选择）');
        return;
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认导入'),
          content: Text('解析到 ${entries.length} 条有效流水，将合并写入本地数据库。是否继续？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('导入')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await ref.read(transactionListProvider.notifier).importAll(entries);
      if (!mounted) return;
      _toast('导入成功，已写入 ${entries.length} 条流水');
    } catch (e) {
      if (mounted) _toast('导入失败：$e');
    } finally {
      _setBusy(false);
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final dbInfo = ref.watch(dbInfoProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        const Text('数据管理', style: AppTextStyles.pageTitle),
        const SizedBox(height: 16),

        // ---------- 数据库信息 ----------
        GlassCard(
          child: dbInfo.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text('数据库信息读取失败：$e',
                style: const TextStyle(fontSize: 13, color: AppTheme.expenseColor)),
            data: (info) => Row(
              children: [
                const Icon(Icons.storage_rounded,
                    size: 20, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SQLite 数据库 v${info.version} · 共 ${info.count} 条流水\n'
                    '已随应用启动自动检测并完成版本迁移',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 外观设置 ----------
        GlassCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.palette_outlined, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('外观设置',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      '切换页面背景主题：${ref.watch(backgroundThemeProvider).name}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.60)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: Colors.black.withValues(alpha: 0.60)),
                onPressed: _pickBackgroundTheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 自定义背景 ----------
        GlassCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.image_outlined,
                    color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('自定义背景',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      ref.watch(customBackgroundProvider) != null
                          ? '已启用图片背景，点击可更换/清除'
                          : '用自己喜欢的图片做背景（可清除）',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.60)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: Colors.black.withValues(alpha: 0.60)),
                onPressed: _pickCustomBackground,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 分类管理 ----------
        GlassCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.category_rounded,
                        color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('分类管理',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      '新增 / 删除 / 修改自定义分类，调整图标与颜色',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.60)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: Colors.black.withValues(alpha: 0.60)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CategoryManagementScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 备份 / 恢复 ----------
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('备份与恢复', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Text(
                '备份：将数据库压缩为 .zip 保存到您选择的目录。\n'
                '恢复：从文件管理器选取备份包，解压覆盖当前数据库并自动刷新界面。',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.backup_outlined,
                      label: '备份数据库',
                      onPressed: _busy ? null : _backup,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.restore_outlined,
                      label: '从备份恢复',
                      onPressed: _busy ? null : _restore,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 生物识别锁（仅 Android） ----------
        if (Platform.isAndroid) ...[
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded,
                    size: 28, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('生物识别锁',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '开启后每次进入应用需验证指纹 / 面容，验证前金额数据显示为星号。',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.black.withValues(alpha: 0.60)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _biometricEnabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.accent,
                  onChanged: _busy ? null : _toggleBiometric,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ---------- 导出 ----------
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('导出数据', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Text(
                '将全部流水导出为 CSV 文件（UTF-8 编码）。\n'
                'Windows 端默认保存到系统“下载”文件夹；Android 端保存到应用文档目录。',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              _actionButton(
                icon: Icons.file_download_outlined,
                label: '导出 CSV',
                onPressed: _busy ? null : _export,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 导入 ----------
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('导入数据', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Text(
                '从本机选择之前导出的 CSV 文件，解析有效流水后合并写入本地数据库，用于换机恢复数据。',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              _actionButton(
                icon: Icons.file_upload_outlined,
                label: '选择 CSV 文件导入',
                onPressed: _busy ? null : _import,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- 格式说明 ----------
        GlassCard(
          color: AppTheme.cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CSV 格式说明', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Text(
                CsvService.header.join(', '),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'type 取值：expense（支出）/ income（收入）；category 为分类名称（如“餐饮”“购物”），导入时兼容旧版枚举名（food / shopping / transport / entertainment / other）。',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.black.withValues(alpha: 0.50)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withValues(alpha: 0.40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
