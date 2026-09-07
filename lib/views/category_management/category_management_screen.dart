import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/category_utils.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/glass_card.dart';

/// 分类管理：增 / 删 / 改名 / 换图标颜色
/// - 分类存于数据库，流水按分类名称关联
/// - “其他”为兜底分类：不可删除、不可改名；删除其他分类时其流水迁移到“其他”
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('分类管理'),
        actions: [
          IconButton(
            tooltip: '添加分类',
            onPressed: () => _showEditDialog(context, ref, null),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text('分类加载失败：$e',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.70))),
        ),
        data: (categories) {
          final expenses =
              categories.where((c) => !c.isIncome).toList();
          final incomes = categories.where((c) => c.isIncome).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _sectionTitle('支出分类'),
              _categoryList(context, ref, expenses),
              const SizedBox(height: 20),
              _sectionTitle('收入分类'),
              _categoryList(context, ref, incomes),
              const SizedBox(height: 16),
              Text(
                '说明：点击名称/图标可修改；左滑或点击删除按钮可删除自定义分类，其流水将迁移到“其他”；“其他”不可删除、不可改名。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Colors.black.withValues(alpha: 0.50),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _categoryList(
      BuildContext context, WidgetRef ref, List<Category> categories) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('暂无分类',
            style: TextStyle(
                fontSize: 13, color: Colors.black.withValues(alpha: 0.50))),
      );
    }
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            _categoryRow(context, ref, categories[i]),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(BuildContext context, WidgetRef ref, Category c) {
    final color = CategoryUtils.colorOfCategory(c);
    final isFallback = c.name == DatabaseService.fallbackCategoryName;

    return InkWell(
      onTap: () => _showEditDialog(context, ref, c),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(CategoryUtils.iconOfCategory(c), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (c.isSystem) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('内置',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black.withValues(alpha: 0.60))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFallback ? '兜底分类 · 不可删除' : '点击编辑',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '编辑',
              icon: Icon(Icons.edit_outlined,
                  size: 20, color: Colors.black.withValues(alpha: 0.80)),
              onPressed: () => _showEditDialog(context, ref, c),
            ),
            IconButton(
              tooltip: '删除',
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.black.withValues(alpha: 0.70)),
              onPressed: c.isSystem || isFallback
                  ? null
                  : () => _confirmDelete(context, ref, c),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 添加 / 编辑对话框 ----------

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Category? existing) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var iconKey = existing?.icon ?? 'star';
    var colorValue = existing?.color ?? CategoryUtils.palette.first;
    var isIncome = existing?.isIncome ?? false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(isEdit ? '编辑分类' : '添加分类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: !isEdit,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: '分类名称',
                      hintText: '如：房租、宠物、学习',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isEdit) ...[
                    const Text('类型', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _typeChip('支出', false, isIncome,
                            (v) => setState(() => isIncome = v)),
                        const SizedBox(width: 8),
                        _typeChip('收入', true, isIncome,
                            (v) => setState(() => isIncome = v)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('图标', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in CategoryUtils.iconMap.entries)
                        GestureDetector(
                          onTap: () => setState(() => iconKey = entry.key),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: iconKey == entry.key
                                  ? CategoryUtils.colorOfValue(colorValue)
                                      .withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: iconKey == entry.key
                                    ? CategoryUtils.colorOfValue(colorValue)
                                    : Colors.black.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Icon(entry.value,
                                size: 22,
                                color: iconKey == entry.key
                                    ? CategoryUtils.colorOfValue(colorValue)
                                    : AppTheme.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('颜色', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in CategoryUtils.palette)
                        GestureDetector(
                          onTap: () => setState(() => colorValue = v),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: CategoryUtils.colorOfValue(v),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorValue == v
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: colorValue == v
                                ? const Icon(Icons.check_rounded,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, true);
                  _save(context, ref, existing, name, iconKey, colorValue, isIncome);
                },
                child: Text(isEdit ? '保存' : '添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _typeChip(
      String label, bool value, bool currentIncome, ValueChanged<bool> onChanged) {
    final selected = currentIncome == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                selected ? AppTheme.accent : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // 类型选择（简化：点击切换由外层管理）
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Category? existing,
    String name,
    String iconKey,
    int colorValue,
    bool isIncome,
  ) async {
    try {
      if (existing != null) {
        await DatabaseService.instance
            .updateCategory(existing.copyWith(name: name, icon: iconKey, color: colorValue));
      } else {
        final maxOrder = await _nextSortOrder(isIncome);
        await DatabaseService.instance.insertCategory(Category(
          id: 0,
          name: name,
          icon: iconKey,
          color: colorValue,
          isIncome: isIncome,
          isSystem: false,
          sortOrder: maxOrder,
        ));
      }
      ref.read(categoryVersionProvider.notifier).state++;
      await ref.read(transactionListProvider.notifier).reload();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(existing != null ? '已保存' : '已添加“$name”'),
            duration: const Duration(seconds: 2)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('保存失败：$e'), duration: const Duration(seconds: 3)));
    }
  }

  Future<int> _nextSortOrder(bool isIncome) async {
    final all = await DatabaseService.instance.listCategories();
    final same = all.where((c) => c.isIncome == isIncome).toList();
    if (same.isEmpty) return 0;
    same.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return same.last.sortOrder + 1;
  }

  // ---------- 删除确认 ----------

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('删除分类'),
        content: Text('确定删除“${c.name}”吗？\n该分类下的流水将自动归入“${DatabaseService.fallbackCategoryName}”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await DatabaseService.instance.deleteCategory(c.id);
    ref.read(categoryVersionProvider.notifier).state++;
    await ref.read(transactionListProvider.notifier).reload();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(success ? '已删除“${c.name}”' : '该分类不可删除'),
          duration: const Duration(seconds: 2)));
  }
}
