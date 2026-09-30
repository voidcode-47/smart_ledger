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
            borderRadius: BorderRadius.circular(12),
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

  /// Things 3 风格流水条目：圆形描边图标 + 分类名/备注 + 右对齐金额
  Widget _tileContent(BuildContext context, Color color, Category? cat) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onEdit,
      onLongPress: onDelete == null
          ? null
          : () async {
              final ok = await _confirmDelete(context);
              if (ok) onDelete?.call();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // 左侧：圆形描边图标 36x36（非填充）
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                entry.isIncome
                    ? CategoryUtils.incomeIcon
                    : (cat != null
                        ? CategoryUtils.iconOfCategory(cat)
                        : CategoryUtils.fallbackIcon),
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 中间：分类名 15sp w500 + 备注 13sp 灰
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.category,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (entry.note.isNotEmpty)
                    Text(
                      entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),
            // 右侧：金额 16sp w600 tabular nums 右对齐，支出红/收入绿
            Text(
              FormatUtils.signedMoney(entry.amount, isIncome: entry.isIncome),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: entry.isIncome
                    ? AppTheme.incomeColor
                    : AppTheme.expenseColor,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final ok = await _confirmDelete(context);
                  if (ok) onDelete?.call();
                },
                child: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppTheme.textHint),
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
