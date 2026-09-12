import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/theme_config.dart';
import '../../viewmodels/theme_providers.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/transaction_tile.dart';
import '../add_transaction/add_transaction_sheet.dart';

/// 流水总览：全部流水按月分组，支持关键词搜索与类型/分类筛选
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all'; // all / expense / income
  String? _categoryFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransactionEntry> _filter(
      List<TransactionEntry> all, String query, String type, String? category) {
    final q = query.trim().toLowerCase();
    return all.where((e) {
      if (type == 'expense' && e.isIncome) return false;
      if (type == 'income' && !e.isIncome) return false;
      if (category != null && e.category != category) return false;
      if (q.isNotEmpty) {
        final inNote = e.note.toLowerCase().contains(q);
        final inCategory = e.category.toLowerCase().contains(q);
        if (!inNote && !inCategory) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(transactionListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    // 黑色背景下页面标题/空状态文字反白
    final dark = ref.watch(backgroundThemeProvider).isDark;
    final pageTitleColor = ThemeConfig.onBackground(dark);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        Text('全部流水',
            style: AppTextStyles.pageTitle.copyWith(color: pageTitleColor)),
        const SizedBox(height: 12),
        _searchField(),
        const SizedBox(height: 8),
        _filters(categoriesAsync.value ?? const []),
        const SizedBox(height: 12),
        listAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: Text('流水加载失败：$e',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary))),
          ),
          data: (all) {
            final filtered =
                _filter(all, _searchCtrl.text, _typeFilter, _categoryFilter);
            if (all.isEmpty) {
              return _emptyHint('还没有任何流水，点击右下角 + 记一笔吧', dark: dark);
            }
            if (filtered.isEmpty) {
              return _emptyHint('未找到匹配的流水，试试调整搜索或筛选', dark: dark);
            }
            return _groupedList(filtered);
          },
        ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: '搜索备注或分类…',
        hintStyle: TextStyle(color: AppTheme.onSurface(alpha: 0.40)),
        prefixIcon: Icon(Icons.search_rounded,
            color: AppTheme.onSurface(alpha: 0.60)),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.clear_rounded,
                    color: AppTheme.onSurface(alpha: 0.60)),
                onPressed: () => setState(() => _searchCtrl.clear()),
              ),
        filled: true,
        fillColor: AppTheme.onSurface(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _filters(List<Category> categories) {
    Widget typeChip(String value, String label) {
      final selected = _typeFilter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppTheme.accent,
        backgroundColor: AppTheme.onSurface(alpha: 0.10),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppTheme.textSecondary,
        ),
        side: BorderSide.none,
        showCheckmark: false,
        onSelected: (_) => setState(() => _typeFilter = value),
      );
    }

    return Row(
      children: [
        typeChip('all', '全部'),
        const SizedBox(width: 6),
        typeChip('expense', '支出'),
        const SizedBox(width: 6),
        typeChip('income', '收入'),
        const SizedBox(width: 10),
        Expanded(
          child: _categoryDropdown(categories),
        ),
      ],
    );
  }

  Widget _categoryDropdown(List<Category> categories) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
          value: null, child: Text('全部分类', overflow: TextOverflow.ellipsis)),
      for (final c in categories)
        DropdownMenuItem<String?>(value: c.name, child: Text(c.name)),
    ];

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.onSurface(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _categoryFilter,
          isExpanded: true,
          dropdownColor: AppTheme.cardColor,
          style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          icon: Icon(Icons.expand_more_rounded,
              size: 18, color: AppTheme.onSurface(alpha: 0.70)),
          items: items,
          onChanged: (v) => setState(() => _categoryFilter = v),
        ),
      ),
    );
  }

  Widget _emptyHint(String text, {bool dark = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: ThemeConfig.onBackground(dark, alpha: 0.50))),
      ),
    );
  }

  // ---------- 按月分组列表 ----------

  Widget _groupedList(List<TransactionEntry> filtered) {
    final groups = <String, List<TransactionEntry>>{};
    for (final e in filtered) {
      final key = '${e.date.year}-${e.date.month}';
      groups.putIfAbsent(key, () => []).add(e);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a)); // 月份倒序

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in keys)
          _monthGroup(
              DateTime(
                  int.parse(key.split('-')[0]), int.parse(key.split('-')[1])),
              groups[key]!),
      ],
    );
  }

  Widget _monthGroup(DateTime month, List<TransactionEntry> entries) {
    var expense = 0.0;
    for (final e in entries) {
      if (!e.isIncome) expense += e.amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Row(
            children: [
              Text(FormatUtils.monthTitle(month),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${entries.length} 笔',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurface(alpha: 0.45))),
              const Spacer(),
              if (expense > 0)
                Text('支出 ${FormatUtils.money(expense)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurface(alpha: 0.60))),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1, color: AppTheme.onSurface(alpha: 0.06)),
                TransactionTile(
                  entry: entries[i],
                  onEdit: entries[i].id == null
                      ? null
                      : () => AddTransactionSheet.show(context,
                          initial: entries[i]),
                  onDelete: entries[i].id == null
                      ? null
                      : () => ref
                          .read(transactionListProvider.notifier)
                          .remove(entries[i].id!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
