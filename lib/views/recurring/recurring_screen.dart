import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/recurring_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/glass_card.dart';

/// 周期记账：房租 / 生活费 / 工资等每月固定收支，
/// 到期后应用启动时自动记入账本
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  List<RecurringRule> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rules = await RecurringService.load();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _persist(List<RecurringRule> rules) async {
    await RecurringService.save(rules);
    if (!mounted) return;
    setState(() => _rules = rules);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openEditor([RecurringRule? rule]) async {
    final saved = await showModalBottomSheet<RecurringRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RuleEditorSheet(rule: rule),
    );
    if (saved == null || !mounted) return;

    if (rule == null) {
      await _persist([..._rules, saved]);
      _toast('已添加周期规则：${saved.name}');
    } else {
      final idx = _rules.indexWhere((e) => e.id == rule.id);
      if (idx < 0) return;
      final next = [..._rules];
      next[idx] = saved;
      await _persist(next);
      _toast('已更新');
    }
  }

  Future<void> _remove(RecurringRule rule) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('删除周期规则？'),
        content: Text('「${rule.name}」将不再自动入账，已记入的流水不受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.expenseColor,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _persist(_rules.where((e) => e.id != rule.id).toList());
    _toast('已删除');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cardColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('周期记账'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recurring_fab',
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加规则'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                Text(
                  '房租、生活费、工资、订阅等每月固定收支，到期后打开 App 自动记入账本（无需联网）。',
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 12),
                if (_rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        '还没有周期规则\n点右下角「添加规则」开始',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Colors.black.withValues(alpha: 0.45)),
                      ),
                    ),
                  )
                else
                  for (final r in _rules) _ruleCard(r),
              ],
            ),
    );
  }

  Widget _ruleCard(RecurringRule r) {
    final color = r.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    final typeLabel = r.isIncome ? '收入' : '支出';
    return GlassCard(
      color: AppTheme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openEditor(r),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  r.isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '每月${r.dayOfMonth}日 · $typeLabel',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.black.withValues(alpha: 0.55)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${r.isIncome ? '+' : '-'}${FormatUtils.money(r.amount)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: color),
                        ),
                        const Spacer(),
                        Text(
                          '下次 ${FormatUtils.monthDay(r.nextDue)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                    if (r.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.45)),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppTheme.expenseColor),
                onPressed: () => _remove(r),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 添加 / 编辑规则表单
class _RuleEditorSheet extends ConsumerStatefulWidget {
  const _RuleEditorSheet({this.rule});

  final RecurringRule? rule;

  @override
  ConsumerState<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends ConsumerState<_RuleEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late bool _isIncome;
  String? _category;
  late int _dayOfMonth;

  bool get _isEdit => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _amountCtrl = TextEditingController(
        text: r != null ? r.amount.toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController(text: r?.note ?? '');
    _isIncome = r?.isIncome ?? false;
    _category = r?.category;
    _dayOfMonth = r?.dayOfMonth ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty) {
      _toast('请输入名称');
      return;
    }
    if (amount == null || amount <= 0) {
      _toast('请输入有效金额');
      return;
    }
    final categories = _isIncome
        ? await ref.read(incomeCategoriesProvider.future)
        : await ref.read(expenseCategoriesProvider.future);
    final category = _category ?? (categories.isNotEmpty ? categories.first.name : null);
    if (category == null) {
      _toast('请先添加分类');
      return;
    }

    final base = widget.rule;
    // 编辑时保留原下次生成日期；新增时从下月同日开始
    final firstDue = base?.nextDue ??
        _nextMonthDay(DateTime.now(), _dayOfMonth);

    final rule = RecurringRule(
      id: base?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      isIncome: _isIncome,
      category: category,
      dayOfMonth: _dayOfMonth,
      nextDue: base != null
          ? _adjustDay(base.nextDue, _dayOfMonth)
          : firstDue,
      note: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(rule);
  }

  DateTime _nextMonthDay(DateTime now, int day) {
    final y = now.month == 12 ? now.year + 1 : now.year;
    final m = now.month == 12 ? 1 : now.month + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > lastDay ? lastDay : day);
  }

  /// 编辑时保持"下次日期"在正确的月份，仅调整日
  DateTime _adjustDay(DateTime d, int day) {
    final lastDay = DateTime(d.year, d.month + 1, 0).day;
    return DateTime(d.year, d.month, day > lastDay ? lastDay : day);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = _isIncome
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_isEdit ? '编辑周期规则' : '添加周期规则',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: '名称', hintText: '如：房租 / 生活费 / 工资'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '金额（元）', prefixText: '¥ '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false, label: Text('支出'), icon: Icon(Icons.north_east_rounded, size: 16)),
                      ButtonSegment(
                          value: true, label: Text('收入'), icon: Icon(Icons.south_west_rounded, size: 16)),
                    ],
                    selected: {_isIncome},
                    onSelectionChanged: (s) => setState(() {
                      _isIncome = s.first;
                      _category = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 每月第几天
            Row(
              children: [
                const Text('每月第', style: TextStyle(fontSize: 14)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: _dayOfMonth > 1
                      ? () => setState(() => _dayOfMonth--)
                      : null,
                ),
                Text('$_dayOfMonth 日',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: _dayOfMonth < 28
                      ? () => setState(() => _dayOfMonth++)
                      : null,
                ),
                const Text('（1~28，短月自动顺延）',
                    style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text('分类',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.60))),
            const SizedBox(height: 6),
            categoriesAsync.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))),
              error: (e, _) => Text('分类加载失败：$e',
                  style: const TextStyle(fontSize: 12)),
              data: (categories) {
                if (categories.isEmpty) {
                  return Text('暂无${_isIncome ? '收入' : '支出'}分类，请先到「数据 → 分类管理」添加',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.55)));
                }
                final selected = _category ?? categories.first.name;
                _category ??= categories.first.name;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: selected == c.name,
                        onSelected: (_) => setState(() => _category = c.name),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '会写入自动生成的流水'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _save,
                child: Text(_isEdit ? '保存修改' : '添加规则'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
