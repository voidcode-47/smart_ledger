// 应用冒烟测试：验证 App 能正常构建并渲染仪表盘页面
// 注意：测试环境下数据库插件不可用（进入错误态）且存在不确定动画，
// 因此使用固定步进 pump 而非 pumpAndSettle。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/main.dart';

void main() {
  testWidgets('应用能正常构建并显示仪表盘', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartLedgerApp()));
    // 推进帧：让交错动画与数据库错误态完成
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 底部导航与仪表盘核心区块（首屏可见元素；
    // “最近流水”位于列表下方视口外，懒加载下不参与断言）
    expect(find.text('仪表盘'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('结余'), findsOneWidget);
  });
}
