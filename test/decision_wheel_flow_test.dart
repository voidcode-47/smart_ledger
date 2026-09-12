import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_ledger/views/tools/decision_wheel_screen.dart';

/// 转盘回归测试：修复“只能转一次、第二次需重新进入”的 bug
/// （根因：_spinAnim 为 late final，第二次赋值抛 LateInitializationError）。
void main() {
  testWidgets('转盘可以连续转动多次且不抛异常', (tester) async {
    // 手机尺寸视口，保证转盘与按钮都在 ListView 首屏内可点
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DecisionWheelScreen()));
    await tester.pumpAndSettle();
    expect(find.text('开始转！'), findsOneWidget);

    // 第一次转动
    await tester.tap(find.text('开始转！'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // 走完 2.6s 动画
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '第一次转动不应抛异常');

    // 第二次转动（此前会因 LateInitializationError 崩溃）
    await tester.tap(find.text('开始转！'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '第二次转动不应抛异常');

    // 第三次同样正常
    await tester.tap(find.text('开始转！'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '第三次转动不应抛异常');
  });
}
