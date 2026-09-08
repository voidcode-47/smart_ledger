import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../models/transaction_model.dart';
import '../services/receipt_ocr_service.dart';
import '../services/recurring_service.dart';
import '../viewmodels/transaction_providers.dart';
import '../services/screenshot_watcher.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/gradient_background.dart';
import '../widgets/screenshot_confirm_sheet.dart';
import 'add_transaction/add_transaction_sheet.dart';
import 'add_transaction/quick_add_dialog.dart';
import 'dashboard/dashboard_screen.dart';
import 'data_management/data_management_screen.dart';
import 'ledger/ledger_screen.dart';
import 'statistics/statistics_screen.dart';

/// 应用主框架：
/// - 手机（宽 < 800）：BottomAppBar + 居中缺口 FAB
/// - 桌面（宽 >= 800）：NavigationRail 侧边栏 + 右下角扩展 FAB
/// - Windows：关闭窗口最小化到系统托盘；托盘右键菜单（显示主窗口/快速记账/退出）
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
    if (Platform.isAndroid) {
      _initScreenshotWatch();
    }
    _processRecurring();
  }

  /// 截屏记账：注册截图回调；若用户在设置中开启则自动启动监听
  Future<void> _initScreenshotWatch() async {
    ScreenshotWatcher.onScreenshot = _handleScreenshot;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool('screenshot_ledger_enabled') ?? false;
      if (enabled) {
        await ScreenshotWatcher.start();
      }
    } catch (_) {}
  }

  /// 截图回调：OCR 识别，识别到金额才弹确认面板（非账单静默忽略）
  Future<void> _handleScreenshot(String path) async {
    try {
      final result = await ReceiptOcrService.recognize(XFile(path));
      if (!mounted || result.amount == null) return;
      await showScreenshotConfirmSheet(context, result);
    } catch (_) {
      // 识别失败不打扰
    }
  }

  /// 周期记账：启动时检查到期规则并自动入账（一次性，不打扰）
  Future<void> _processRecurring() async {
    try {
      final result = await RecurringService.processDue();
      if (result.due.isEmpty || !mounted) return;
      final notifier = ref.read(transactionListProvider.notifier);
      for (final e in result.due) {
        await notifier.add(e);
      }
      // 全部入账成功后才推进下次日期，避免入账失败导致漏记
      await RecurringService.commitRules(result.rules);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('周期记账：${result.due.length} 笔已自动入账'),
          duration: const Duration(seconds: 2),
        ));
    } catch (_) {
      // 失败静默，下次启动重试
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

  /// Windows：拦截关闭事件 + 设置托盘图标与右键菜单
  Future<void> _setupDesktopIntegration() async {
    try {
      // 点击窗口关闭按钮时不退出，改为隐藏到托盘
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
    } catch (_) {
      // 插件尚未就绪（如测试环境）时忽略
    }
  }

  // ---------- 窗口事件 ----------
  @override
  void onWindowClose() async {
    // 拦截关闭：隐藏窗口，程序驻留托盘
    await windowManager.hide();
  }

  // ---------- 托盘事件 ----------
  @override
  void onTrayIconMouseDown() {
    // 左键点击托盘图标：显示主窗口
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

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

  /// 一句话记账：输入如“午饭 32”“打车 25.5”“工资 8000”，
  /// 复用 OCR 解析引擎识别金额/分类后进入确认表单
  Future<void> _openTextAdd() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('一句话记账'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '例如：午饭 32 / 打车 25.5 / 工资 8000',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('识别'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || !mounted) return;

    final r = ReceiptOcrService.parse(text);
    if (r.amount == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('未识别到金额，请检查输入（如：午饭 32）'),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    final isIncome = r.category == '收入';
    final entry = TransactionEntry(
      amount: r.amount!,
      type: isIncome
          ? TransactionType.income
          : TransactionType.expense,
      category: r.category ?? (isIncome ? '收入' : '其他'),
      date: r.date ?? DateTime.now(),
      note: r.note,
    );
    await AddTransactionSheet.show(context, initial: entry);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktop(context);

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
                  FloatingActionButton.extended(
                    heroTag: 'fab_desktop',
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    onPressed: _openAddSheet,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('记一笔'),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textAddFab('fab_text_mobile'),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'fab_mobile',
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    onPressed: _openAddSheet,
                    child: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
        floatingActionButtonLocation: desktop
            ? FloatingActionButtonLocation.endFloat
            : FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar:
            desktop ? null : _buildMobileBottomBar(),
      ),
    );
  }

  /// 一句话记账小按钮（主 FAB 上方）
  Widget _textAddFab(String heroTag) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.accent,
      tooltip: '一句话记账（如：午饭 32）',
      onPressed: _openTextAdd,
      child: const Icon(Icons.edit_note_rounded, size: 22),
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
          backgroundColor: Colors.white.withValues(alpha: 0.55),
          selectedIconTheme: const IconThemeData(color: AppTheme.accent),
          selectedLabelTextStyle: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme:
              IconThemeData(color: Colors.black.withValues(alpha: 0.55)),
          unselectedLabelTextStyle:
              TextStyle(color: Colors.black.withValues(alpha: 0.55)),
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
        const VerticalDivider(width: 1, thickness: 1, color: AppTheme.dividerColor),
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

  Widget _buildMobileBottomBar() {
    Widget item(int i, IconData icon, String label) {
      final selected = _index == i;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _index = i),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 22,
                    color: selected
                        ? AppTheme.accent
                        : Colors.black.withValues(alpha: 0.55)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppTheme.accent
                        : Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BottomAppBar(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 4,
      child: Row(
        children: [
          item(0, Icons.dashboard_rounded, '仪表盘'),
          item(1, Icons.insights_rounded, '统计'),
          const SizedBox(width: 56), // 中间缺口留给 FAB
          item(2, Icons.receipt_long_rounded, '流水'),
          item(3, Icons.folder_rounded, '数据'),
        ],
      ),
    );
  }
}
