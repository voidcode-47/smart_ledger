import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'services/crash_reporter.dart';
import 'services/database_service.dart';
import 'utils/app_theme.dart';
import 'viewmodels/theme_providers.dart';
import 'views/home_screen.dart';
import 'views/lock/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常捕获：崩溃信息写入日志，下次启动弹窗展示
  await CrashReporter.instance.install();

  // Windows 桌面端：初始化窗口（配合系统托盘常驻，关闭窗口 = 最小化到托盘）
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: '智慧记账',
      size: Size(1180, 780),
      minimumSize: Size(860, 620),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 启动时自动检测本地数据库版本号（打开过程自动执行 onCreate / onUpgrade 迁移）
  try {
    await DatabaseService.instance.ensureSchema();
  } catch (_) {
    // 数据库初始化失败不阻塞启动，界面会以错误态提示
  }

  // 检查上次运行是否有崩溃记录
  final crashLog = await CrashReporter.instance.readLog();

  // 说明：Windows/Linux 桌面端的 SQLite 通过 sqflite_common_ffi (FFI) 实现，
  // 相关初始化已在 DatabaseService 内部按平台自动完成。
  runApp(ProviderScope(
    child: SmartLedgerApp(
      crashLog: crashLog.isEmpty ? null : crashLog,
    ),
  ));
}

class SmartLedgerApp extends ConsumerWidget {
  const SmartLedgerApp({super.key, this.crashLog});

  /// 上次运行遗留的崩溃日志（无记录为 null）
  final String? crashLog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 黑色背景主题 → 全局深色模式（卡片/文字/输入框等整体适配）
    final isDark = ref.watch(backgroundThemeProvider).isDark;
    AppTheme.setDark(isDark);
    return MaterialApp(
      title: '智慧记账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _CrashGate(
        crashLog: crashLog,
        child: Platform.isAndroid
            ? const LockGate(child: HomeScreen()) // Android：生物识别门卫
            : const HomeScreen(),
      ),
    );
  }
}

/// 启动门卫：若检测到上次崩溃日志，弹窗展示并支持复制反馈
class _CrashGate extends StatefulWidget {
  const _CrashGate({required this.crashLog, required this.child});

  final String? crashLog;
  final Widget child;

  @override
  State<_CrashGate> createState() => _CrashGateState();
}

class _CrashGateState extends State<_CrashGate> {
  @override
  void initState() {
    super.initState();
    if (widget.crashLog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCrashDialog());
    }
  }

  Future<void> _showCrashDialog() async {
    if (!mounted) return;
    final log = widget.crashLog!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFB45309), size: 22),
            SizedBox(width: 8),
            Text('上次运行出现异常', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '已记录错误信息。请点击下方「复制日志」后发给我，以便定位问题。',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    log,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('复制日志'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: log));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content: Text('日志已复制，粘贴发给我即可'),
                  duration: Duration(seconds: 3),
                ));
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await CrashReporter.instance.clear();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) {
      // 已查看：无论是否复制都清空，避免每次启动重复弹窗
      await CrashReporter.instance.clear();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
