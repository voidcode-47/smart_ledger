import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'services/database_service.dart';
import 'utils/app_theme.dart';
import 'views/home_screen.dart';
import 'views/lock/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 说明：Windows/Linux 桌面端的 SQLite 通过 sqflite_common_ffi (FFI) 实现，
  // 相关初始化已在 DatabaseService 内部按平台自动完成。
  runApp(const ProviderScope(child: SmartLedgerApp()));
}

class SmartLedgerApp extends StatelessWidget {
  const SmartLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智慧记账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      home: Platform.isAndroid
          ? const LockGate(child: HomeScreen()) // Android：生物识别门卫
          : const HomeScreen(),
    );
  }
}
