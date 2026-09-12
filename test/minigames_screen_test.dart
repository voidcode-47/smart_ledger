import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ledger/views/tools/minigames_screen.dart';

/// 回归测试：小游戏页在无搜索/无分类筛选时（对 const 游戏列表直接排序）
/// 曾抛出 "Cannot modify an unmodifiable list"，修复为先复制再排序。
void main() {
  testWidgets('游戏页默认打开不崩溃且按质量分级排序展示', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MiniGamesScreen()));
    await tester.pump();

    // 无搜索无筛选时不应抛异常，且 SSS 级游戏排在最前
    expect(tester.takeException(), isNull);
    expect(find.text('星团大作战'), findsOneWidget);
  });

  testWidgets('游戏页搜索过滤正常', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MiniGamesScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '2048');
    await tester.pump();

    expect(find.textContaining('2048'), findsWidgets);
    expect(find.text('星团大作战'), findsNothing);
  });
}
