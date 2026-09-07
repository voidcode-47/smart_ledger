import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// 简易数字键盘：0-9 / 小数点 / 退格（3 列 x 4 行）
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey});

  /// 返回按键内容：'0'-'9'、'.'、'del'
  final ValueChanged<String> onKey;

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: _KeyButton(label: key, onTap: () => onKey(key)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDelete = label == 'del';
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Center(
            child: isDelete
                ? const Icon(Icons.backspace_outlined,
                    color: AppTheme.textPrimary, size: 22)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
