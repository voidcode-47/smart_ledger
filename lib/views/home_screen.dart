import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../models/transaction_model.dart';
import '../services/receipt_ocr_service.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../viewmodels/theme_providers.dart';
import '../widgets/gradient_background.dart';
import 'add_transaction/add_transaction_sheet.dart';
import 'add_transaction/quick_add_dialog.dart';
import 'dashboard/dashboard_screen.dart';
import 'data_management/data_management_screen.dart';
import 'ledger/ledger_screen.dart';
import 'statistics/statistics_screen.dart';

/// 应用主框架（数字优先设计语言）：
/// - 手机（宽 < 800）：极简纯色底部导航 + 居中 FAB
/// - 桌面（宽 >= 800）：NavigationRail 侧边栏 + 右下角 FAB
/// - Windows：关闭窗口最小化到系统托盘；托盘右键菜单
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WindowListener, TrayListener {
  int _index = 0;

  static const List<Widget> _pages = [
    DashboardScreen(),
    StatisticsScreen(),
    LedgerScreen(),
    DataManagementScreen(),
  ];

  bool get _isWindowsDesktop => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_isWindowsDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _setupDesktopIntegration();
    }
  }

  @override
  void dispose() {
    if (_isWindowsDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _setupDesktopIntegration() async {
    try {
      await windowManager.setPreventClose(true);
      await trayManager.setIcon('assets/tray_icon.ico');
      await trayManager.setToolTip('智慧记账');
      await trayManager.setContextMenu(
        Menu(items: [
          MenuItem(key: 'show', label: '显示主窗口'),
          MenuItem(key: 'quick_add', label: '快速记账'),
          MenuItem(key: 'exit', label: '退出'),
        ]),
      );
    } catch (_) {}
  }

  @override
  void onWindowClose() async => await windowManager.hide();

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'quick_add':
        windowManager.show();
        windowManager.focus();
        QuickAddDialog.show(context);
        break;
      case 'exit':
        _exitApp();
        break;
    }
  }

  Future<void> _exitApp() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  void _openAddSheet() => AddTransactionSheet.show(context);

  Future<void> _openTextAdd() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('一句话记账'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '例如：午饭 32 / 打车 25.5 / 工资 8000',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('识别'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || !mounted) return;

    final r = ReceiptOcrService.parseQuickText(text);
    if (r.amount == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('未识别到金额，请检查输入（如：午饭 32）'),
          duration: const Duration(seconds: 2),
        ));
      return;
    }
    final isIncome = r.category == '收入';
    final entry = TransactionEntry(
      amount: r.amount!,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      category: r.category ?? (isIncome ? '收入' : '其他'),
      date: r.date ?? DateTime.now(),
      note: r.note,
    );
    await AddTransactionSheet.show(context, initial: entry);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktop(context);
    ref.watch(backgroundThemeProvider);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: desktop ? _buildDesktopBody() : _buildMobileBody(),
        floatingActionButton: desktop
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _textAddFab('fab_text_desktop'),
                  const SizedBox(height: 12),
                  _addButton(onTap: _openAddSheet, extended: true),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textAddFab('fab_text_mobile'),
                  const SizedBox(height: 10),
                  _addButton(onTap: _openAddSheet),
                ],
              ),
        floatingActionButtonLocation: desktop
            ? FloatingActionButtonLocation.endFloat
            : FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: desktop ? null : _buildBottomBar(),
      ),
    );
  }

  /// 一句话记账小按钮：纯色 + 描边
  Widget _textAddFab(String heroTag) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      backgroundColor: AppTheme.cardColor,
      elevation: 0,
      foregroundColor: AppTheme.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.dividerColor, width: 1),
      ),
      tooltip: '一句话记账（如：午饭 32）',
      onPressed: _openTextAdd,
      child: const Icon(Icons.edit_outlined, size: 20),
    );
  }

  /// 主按钮：纯 teal 圆形 / 桌面胶囊（无渐变、无发光阴影）
  Widget _addButton({required VoidCallback onTap, bool extended = false}) {
    final radius = BorderRadius.circular(extended ? 14 : 18);
    return Tooltip(
      message: '记一笔',
      child: Container(
        height: extended ? 48 : 56,
        width: extended ? null : 56,
        padding:
            extended ? const EdgeInsets.symmetric(horizontal: 20) : null,
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                if (extended) ...[
                  const SizedBox(width: 8),
                  const Text('记一笔',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 桌面布局 ----------
  Widget _buildDesktopBody() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelType: NavigationRailLabelType.all,
          groupAlignment: -0.85,
          backgroundColor: AppTheme.cardColor,
          selectedIconTheme: const IconThemeData(color: AppTheme.accent),
          selectedLabelTextStyle: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w600,
          ),
          unselectedIconTheme:
              IconThemeData(color: AppTheme.textSecondary),
          unselectedLabelTextStyle:
              TextStyle(color: AppTheme.textSecondary),
          indicatorColor: AppTheme.accentBg,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: Text('仪表盘'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: Text('统计'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: Text('流水'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: Text('数据'),
            ),
          ],
        ),
        VerticalDivider(
            width: 1, thickness: 1, color: AppTheme.dividerColor),
        Expanded(
          child: IndexedStack(index: _index, children: _pages),
        ),
      ],
    );
  }

  // ---------- 手机布局 ----------
  Widget _buildMobileBody() {
    return IndexedStack(index: _index, children: _pages);
  }

  /// 手机端底部导航：纯色 + 1px 顶部分隔线，选中态文字色变化
  Widget _buildBottomBar() {
    Widget item(int i, IconData icon, String label) {
      final selected = _index == i;
      final color = selected ? AppTheme.accent : AppTheme.textSecondary;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _index = i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(
            top: BorderSide(color: AppTheme.dividerColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            item(0, Icons.dashboard_outlined, '仪表盘'),
            item(1, Icons.insights_outlined, '统计'),
            const SizedBox(width: 60),
            item(2, Icons.receipt_long_outlined, '流水'),
            item(3, Icons.folder_outlined, '数据'),
          ],
        ),
      ),
    );
  }
}
