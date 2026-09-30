// 回归测试：新增记账时分类「选中态」必须与「实际保存值」一致。
//
// 历史缺陷：新增支出时 _category 为 null，分类网格用硬编码的 '其他' 作为
// 高亮兜底，而保存时却写入排序第一的 '餐饮'，导致界面选中「其他」、
// 实际记成「餐饮」。修复后两处统一默认取分类列表第一项。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/models/category_model.dart';
import 'package:smart_ledger/models/transaction_model.dart';
import 'package:smart_ledger/viewmodels/transaction_providers.dart';
import 'package:smart_ledger/views/add_transaction/add_transaction_sheet.dart';

Category _cat(
  int id,
  String name,
  String icon,
  int color,
  bool income,
  int order,
) =>
    Category(
      id: id,
      name: name,
      icon: icon,
      color: color,
      isIncome: income,
      isSystem: true,
      sortOrder: order,
    );

/// 与数据库种子数据一致的排序：餐饮在支出中排第一，其他排最后
final _categories = [
  _cat(1, '餐饮', 'restaurant', 0xFFF6AD55, false, 0),
  _cat(2, '购物', 'shopping', 0xFF63B3ED, false, 1),
  _cat(9, '其他', 'other', 0xFFA0AEC0, false, 9),
  _cat(10, '工资', 'income', 0xFF68D391, true, 0),
  _cat(11, '红包', 'gift', 0xFFF687B3, true, 1),
];

/// 截获 add 调用，避免触碰真实数据库
class _FakeListNotifier extends TransactionListNotifier {
  final List<TransactionEntry> added = [];

  @override
  Future<void> reload() async {}

  @override
  Future<void> add(TransactionEntry entry) async => added.add(entry);
}

Widget _host(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => AddTransactionSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 读取某分类网格项的边框
/// 新设计：选中 = width 1.5 + teal(accent) 描边；未选中 = width 1.5 + 分隔线色
Border? _borderOf(WidgetTester tester, String name) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.text(name), matching: find.byType(Container))
        .first,
  );
  return (box.decoration as BoxDecoration).border as Border?;
}

bool _isSelected(WidgetTester tester, String name) {
  final border = _borderOf(tester, name);
  // 选中态边框色为 teal 主色（AppTheme.accent = 0xFF0F766E）
  return border != null && border.top.color == const Color(0xFF0F766E);
}

void main() {
  late ProviderContainer container;
  late _FakeListNotifier notifier;

  Future<void> setup(WidgetTester tester) async {
    container = ProviderContainer(overrides: [
      categoriesProvider.overrideWith((ref) async => _categories),
      transactionListProvider.overrideWith((ref) => _FakeListNotifier()),
    ]);
    addTearDown(container.dispose);
    notifier =
        container.read(transactionListProvider.notifier) as _FakeListNotifier;
    await tester.pumpWidget(_host(container));
  }

  testWidgets('新增支出默认高亮「餐饮」且保存的分类也是「餐饮」',
      (tester) async {
    await setup(tester);
    await _openSheet(tester);

    // 选中态：餐饮高亮、其他不能高亮
    expect(_isSelected(tester, '餐饮'), isTrue,
        reason: '新增支出时应默认高亮排序第一的分类');
    expect(_isSelected(tester, '其他'), isFalse,
        reason: '不应再硬编码高亮「其他」');
    // 新设计：选中态边框色统一为 teal 主色（非分类色）
    expect(_borderOf(tester, '餐饮')!.top.color, const Color(0xFF0F766E));

    // 输入金额 8 并保存
    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.added, hasLength(1));
    expect(notifier.added.single.category, '餐饮',
        reason: '实际保存的分类必须与高亮项一致');
    expect(notifier.added.single.amount, 8);
    expect(notifier.added.single.type, TransactionType.expense);
  });

  testWidgets('切换到收入后默认高亮第一个收入分类「工资」', (tester) async {
    await setup(tester);
    await _openSheet(tester);

    await tester.tap(find.text('收入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_isSelected(tester, '工资'), isTrue);
    expect(_isSelected(tester, '红包'), isFalse);
  });

  testWidgets('手动选择「其他」后保存的分类为「其他」', (tester) async {
    await setup(tester);
    await _openSheet(tester);

    await tester.ensureVisible(find.text('其他'));
    await tester.pump();
    await tester.tap(find.text('其他'));
    await tester.pump();
    expect(_isSelected(tester, '其他'), isTrue);
    expect(_isSelected(tester, '餐饮'), isFalse);

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.added, hasLength(1));
    expect(notifier.added.single.category, '其他');
    expect(notifier.added.single.amount, 5);
  });
}
