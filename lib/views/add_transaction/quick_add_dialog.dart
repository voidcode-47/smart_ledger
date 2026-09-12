import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/transaction_providers.dart';

/// 托盘“快速记账”简易输入框（桌面键盘直接输入金额）
class QuickAddDialog extends ConsumerStatefulWidget {
  const QuickAddDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const QuickAddDialog(),
    );
  }

  @override
  ConsumerState<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<QuickAddDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    await ref.read(transactionListProvider.notifier).add(
          TransactionEntry(
            amount: amount,
            type: _type,
            // 快速记账不选分类，记入兜底分类“其他”（该分类固定存在）
            category: DatabaseService.fallbackCategoryName,
            note: _noteCtrl.text.trim(),
            date: DateTime.now(),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已快速记账')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速记账'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _typeButton('支出', TransactionType.expense),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _typeButton('收入', TransactionType.income),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额',
              prefixText: '¥ ',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: '备注（可选）'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _typeButton(String label, TransactionType type) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.onSurface(alpha: 0.06),
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
    );
  }
}
