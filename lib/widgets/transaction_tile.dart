import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/category_utils.dart';
import '../utils/format_utils.dart';
import '../viewmodels/transaction_providers.dart';

/// 单条流水展示块（分类图标 + 标签/备注 + 金额/日期）
/// 交互：
/// - 点击：编辑（onEdit 非空时）
/// - 长按 / 左滑：删除（onDelete 非空时）
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.entry,
    this.onDelete,
    this.onEdit,
  });

  final TransactionEntry entry;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoryMapProvider).value ?? const <String, Category>{};
    final cat = categories[entry.category];
    final color = entry.isIncome
        ? CategoryUtils.incomeColor
        : (cat != null ? CategoryUtils.colorOfCategory(cat) : CategoryUtils.fallbackColor);

    final tile = _tileContent(context, color, cat);

    // 支持左滑删除
    if (onDelete != null) {
      return Dismissible(
        key: ValueKey('dismiss_${entry.id ?? entry.hashCode}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppTheme.expenseColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
              SizedBox(height: 2),
              Text('删除', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => onDelete!(),
        child: tile,
      );
    }
    return tile;
  }

  Widget _tileContent(BuildContext context, Color color, Category? cat) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEdit,
      onLongPress: onDelete == null ? null : () => _confirmDelete(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                entry.isIncome
                    ? CategoryUtils.incomeIcon
                    : (cat != null
                        ? CategoryUtils.iconOfCategory(cat)
                        : CategoryUtils.fallbackIcon),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.category,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (entry.note.isNotEmpty)
                    Text(
                      entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormatUtils.signedMoney(entry.amount,
                      isIncome: entry.isIncome),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: entry.isIncome
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor,
                  ),
                ),
                Text(
                  FormatUtils.fullDate(entry.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              // 显式删除图标：手机端最可靠的删除入口
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _confirmDelete(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.expenseColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: AppTheme.expenseColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除流水'),
        content: const Text('确定删除这条流水吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
