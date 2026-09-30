import 'dart:io';
import 'dart:ui';

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
        backgroundColor: AppTheme.cardColor,
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

    final r = ReceiptOcrService.parseQuickText(text);
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
    // 监听背景主题：切换主题时重建本页，底部导航/浮动按钮等动态色立即刷新
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
                  _gradientAddButton(onTap: _openAddSheet, extended: true),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textAddFab('fab_text_mobile'),
                  const SizedBox(height: 10),
                  _gradientAddButton(onTap: _openAddSheet),
                ],
              ),
        floatingActionButtonLocation: desktop
            ? FloatingActionButtonLocation.endFloat
            : FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: desktop ? null : _buildGlassBottomBar(),
      ),
    );
  }

  /// 一句话记账小按钮（主按钮上方）：磨砂玻璃圆钮
  Widget _textAddFab(String heroTag) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      backgroundColor: AppTheme.glassFillStrong,
      elevation: 2,
      foregroundColor: AppTheme.isDark ? AppTheme.accentLight : AppTheme.accent,
      tooltip: '一句话记账（如：午饭 32）',
      onPressed: _openTextAdd,
      child: const Icon(Icons.edit_note_rounded, size: 22),
    );
  }

  /// 渐变主按钮：手机为 58 圆角方块，桌面为横向胶囊
  Widget _gradientAddButton(
      {required VoidCallback onTap, bool extended = false}) {
    final radius = BorderRadius.circular(extended ? 26 : 20);
    return Tooltip(
      message: '记一笔',
      child: Container(
        height: extended ? 52 : 58,
        padding:
            extended ? const EdgeInsets.symmetric(horizontal: 22) : null,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.accentGradient,
          ),
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
                color: AppTheme.accentGlow,
                blurRadius: 18,
                offset: Offset(0, 8)),
          ],
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
                const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                if (extended) ...[
                  const SizedBox(width: 8),
                  const Text('记一笔',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
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
          backgroundColor: AppTheme.cardColor.withValues(alpha: 0.55),
          selectedIconTheme: const IconThemeData(color: AppTheme.accent),
          selectedLabelTextStyle: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme:
              IconThemeData(color: AppTheme.onSurface(alpha: 0.55)),
          unselectedLabelTextStyle:
              TextStyle(color: AppTheme.onSurface(alpha: 0.55)),
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

  /// 手机端：悬浮玻璃导航栏（模糊 + 高光描边 + 渐变选中胶囊）
  Widget _buildGlassBottomBar() {
    Widget item(int i, IconData icon, String label) {
      final selected = _index == i;
      final dim = AppTheme.onSurface(alpha: 0.55);
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _index = i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppTheme.accentGradient,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                              color: AppTheme.accentGlow,
                              blurRadius: 10,
                              offset: Offset(0, 4)),
                        ]
                      : null,
                ),
                child: Icon(icon,
                    size: 20, color: selected ? Colors.white : dim),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.accent : dim,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.glassShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.glassFillStrong, AppTheme.glassFill],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: Row(
                  children: [
                    item(0, Icons.dashboard_rounded, '仪表盘'),
                    item(1, Icons.insights_rounded, '统计'),
                    const SizedBox(width: 60), // 居中悬浮主按钮留位
                    item(2, Icons.receipt_long_rounded, '流水'),
                    item(3, Icons.folder_rounded, '数据'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
