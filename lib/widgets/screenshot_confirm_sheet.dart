import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../services/receipt_ocr_service.dart';
import '../utils/app_theme.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';

/// 截屏识别结果确认面板：识别到账单后弹出，一键记入或忽略
Future<void> showScreenshotConfirmSheet(
  BuildContext context,
  ReceiptOcrResult result,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ScreenshotConfirmSheet(result: result),
  );
}

class _ScreenshotConfirmSheet extends ConsumerStatefulWidget {
  const _ScreenshotConfirmSheet({required this.result});

  final ReceiptOcrResult result;

  @override
  ConsumerState<_ScreenshotConfirmSheet> createState() =>
      _ScreenshotConfirmSheetState();
}

class _ScreenshotConfirmSheetState
    extends ConsumerState<_ScreenshotConfirmSheet> {
  bool _saving = false;

  Future<void> _save({required bool asIncome}) async {
    if (_saving) return;
    final r = widget.result;
    if (r.amount == null) return;

    setState(() => _saving = true);
    final category = r.category;
    final type = asIncome
        ? TransactionType.income
        : (category == '收入' ? TransactionType.income : TransactionType.expense);

    final entry = TransactionEntry(
      amount: r.amount!,
      type: type,
      category: category ?? (asIncome ? '收入' : '其他'),
      date: r.date ?? DateTime.now(),
      note: r.note,
    );
    try {
      await ref.read(transactionListProvider.notifier).add(entry);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('已记入账本：${FormatUtils.signedMoney(r.amount!, isIncome: type == TransactionType.income)}'),
          duration: const Duration(seconds: 2),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('保存失败：$e'),
          duration: const Duration(seconds: 3),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final isIncomeCategory = r.category == '收入';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.gradient,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.screenshot_monitor_rounded,
                      color: AppTheme.accent, size: 22),
                  const SizedBox(width: 8),
                  const Text('检测到账单截图',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.black.withValues(alpha: 0.55)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.signedMoney(r.amount ?? 0,
                        isIncome: isIncomeCategory),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isIncomeCategory
                          ? AppTheme.incomeColor
                          : AppTheme.expenseColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '元',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (r.category != null)
                    _chip(Icons.label_outline_rounded, r.category!),
                  if (r.date != null)
                    _chip(Icons.event_outlined, FormatUtils.fullDate(r.date!)),
                  _chip(Icons.crop_original_rounded, '截屏识别'),
                ],
              ),
              if (r.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '识别原文：${r.note}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('忽略'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          _saving ? null : () => _save(asIncome: isIncomeCategory),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('记入账本'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
        ],
      ),
    );
  }
}
