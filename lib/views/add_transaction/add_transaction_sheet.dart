
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/receipt_ocr_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/category_utils.dart';
import '../../utils/format_utils.dart';
import '../../viewmodels/transaction_providers.dart';
import '../../widgets/amount_keypad.dart';

/// 全屏记账 BottomSheet：
/// 金额数字键盘 + 支出/收入切换 + 动态分类网格 + 日期选择 + 备注
/// 支持「新增」与「编辑」两种模式（传入 initial 即为编辑）
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.initial});

  /// 待编辑的流水（编辑模式）；null 表示新增
  final TransactionEntry? initial;

  /// 以全屏 BottomSheet 形式弹出
  static Future<void> show(BuildContext context,
      {TransactionEntry? initial}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => AddTransactionSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late final bool _isEdit = widget.initial != null;
  String _amount = '';
  late TransactionType _type;
  String? _category; // 分类名称
  late DateTime _date;
  late final TextEditingController _noteCtrl;

  // AA 拼单（仅新增支出时显示）
  bool _aaEnabled = false;
  int _aaPeople = 2;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _type = initial.type;
      _category = initial.category;
      _date = initial.date;
      _amount = initial.amount == initial.amount.roundToDouble()
          ? initial.amount.toInt().toString()
          : initial.amount.toString();
      _noteCtrl = TextEditingController(text: initial.note);
    } else {
      _type = TransactionType.expense;
      _date = DateTime.now();
      _noteCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ---------- 键盘输入 ----------
  void _onKey(String key) {
    setState(() {
      if (key == 'del') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (key == '.') {
        if (_amount.isEmpty) {
          _amount = '0.';
        } else if (!_amount.contains('.')) {
          _amount += '.';
        }
      } else if (key == '0') {
        if (_amount == '0.') {
          _amount += '0';
        } else if (_amount.isNotEmpty && _amount != '0') {
          _amount += '0';
        }
      } else {
        // 1-9
        if (_amount == '0') {
          _amount = key;
        } else if (_amount.contains('.') &&
            _amount.split('.').last.length >= 2) {
          // 最多两位小数，忽略
        } else if (_amount.replaceAll('.', '').length < 9) {
          _amount += key;
        }
      }
    });
  }

  // ---------- 日期选择 ----------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ---------- 图片识别 ----------

  Future<void> _pickImageAndRecognize() async {
    // 选择来源：拍照 / 相册
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照识别'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: source,
        // 识别精度优先：OCR 对小票小字敏感，保留较高分辨率与画质
        // （此前为防原生崩溃降到 1440/82，崩溃根因【中文模型缺失】已修复，恢复高精度）
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 92,
      );
    } catch (e) {
      _toast('无法打开${source == ImageSource.camera ? '相机' : '相册'}：$e');
      return;
    }
    if (image == null || !mounted) return;

    _toast('正在识别图片…');
    try {
      final result = await ReceiptOcrService.recognize(image);
      if (!mounted) return;

      var filled = 0;
      setState(() {
        if (result.amount != null) {
          _amount = _formatAmount(result.amount!);
          filled++;
        }
        if (result.date != null) {
          _date = result.date!;
          filled++;
        }
        if (result.note.isNotEmpty) {
          _noteCtrl.text = result.note;
          filled++;
        }
        if (result.category != null) {
          _category = result.category;
        }
      });

      if (filled == 0) {
        _toast('未识别到有效内容，请手动输入');
      } else {
        _toast('识别完成，请核对金额与分类');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('识别失败：$e');
    }
  }

  /// 金额字符串规范化：25 -> 25，25.5 -> 25.5，25.00 -> 25（保持原输入风格）
  String _formatAmount(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    var s = v.toString();
    if (s.contains('.') && s.split('.').last.length > 2) {
      s = v.toStringAsFixed(2);
    }
    return s;
  }

  // ---------- 保存 ----------
  Future<void> _save() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      _toast('请输入有效金额');
      return;
    }
    final categories = _type == TransactionType.income
        ? await ref.read(incomeCategoriesProvider.future)
        : await ref.read(expenseCategoriesProvider.future);
    final category = _category ?? (categories.isNotEmpty ? categories.first.name : null);
    if (category == null) {
      _toast('请先添加分类');
      return;
    }

    // AA 拼单信息：备注为空时自动记录分摊，便于流水追溯
    final share = (!_isEdit && _aaEnabled && _type == TransactionType.expense)
        ? amount / _aaPeople
        : null;
    final shareText = share == null
        ? ''
        : (share == share.roundToDouble()
            ? share.toInt().toString()
            : share.toStringAsFixed(2));
    final baseNote = _noteCtrl.text.trim();
    final note = (share != null && baseNote.isEmpty)
        ? 'AA拼单 · 共$_aaPeople人 · 每人¥$shareText'
        : baseNote;

    final entry = TransactionEntry(
      amount: amount,
      type: _type,
      category: category,
      date: _date,
      note: note,
    );

    final notifier = ref.read(transactionListProvider.notifier);
    if (_isEdit) {
      await notifier.update(widget.initial!.id!, entry);
    } else {
      await notifier.add(entry);
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    // AA 拼单：复制分享文案并提示每人金额
    if (share != null) {
      await Clipboard.setData(ClipboardData(
        text: '【智慧记账】「$category」${_formatAmount(amount)} 元，AA 拼单共 $_aaPeople 人，每人 $shareText 元',
      ));
      _toast('已记入，每人 ¥$shareText（已复制）');
    } else {
      _toast(_isEdit ? '已更新' : '已保存');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.gradient,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 8),
              _typeToggle(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _amountDisplay(),
                      const SizedBox(height: 12),
                      _dateRow(),
                      const SizedBox(height: 12),
                      _noteField(),
                      _aaField(),
                      const SizedBox(height: 12),
                      _categoryGrid(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AmountKeypad(onKey: _onKey),
              const SizedBox(height: 10),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 各区块 ----------

  Widget _header() {
    return Row(
      children: [
        Text(_isEdit ? '编辑流水' : '记一笔',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (!_isEdit && ReceiptOcrService.supported)
          IconButton(
            tooltip: '图片识别记账',
            onPressed: _pickImageAndRecognize,
            icon: Icon(Icons.document_scanner_outlined,
                color: AppTheme.onSurface(alpha: 0.85)),
          ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded,
              color: AppTheme.onSurface(alpha: 0.80)),
        ),
      ],
    );
  }

  Widget _typeToggle() {
    return Row(
      children: [
        _typeButton('支出', TransactionType.expense),
        const SizedBox(width: 10),
        _typeButton('收入', TransactionType.income),
      ],
    );
  }

  Widget _typeButton(String label, TransactionType type) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          // 切换类型时重置未保存的分类选择与 AA 设置
          _category = null;
          _aaEnabled = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent : AppTheme.onSurface(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
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

  Widget _amountDisplay() {
    final empty = _amount.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.onSurface(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.onSurface(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('¥',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface(alpha: 0.60))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              empty ? '0.00' : _amount,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: empty
                    ? AppTheme.onSurface(alpha: 0.35)
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickDate,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.onSurface(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18),
            const SizedBox(width: 8),
            Text(FormatUtils.fullDate(_date)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.onSurface(alpha: 0.50)),
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return TextField(
      controller: _noteCtrl,
      maxLines: 1,
      decoration: const InputDecoration(
        hintText: '备注（可选）',
        prefixIcon: Icon(Icons.edit_note_rounded),
      ),
    );
  }

  /// AA 拼单：聚餐 / 宿舍拼单等场景，保存后自动计算每人金额并复制分享文案
  Widget _aaField() {
    if (_isEdit || _type == TransactionType.income) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.onSurface(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.group_rounded,
              size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          const Text('AA 拼单',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_aaEnabled)
            Row(
              children: [
                _peopleButton(Icons.remove_circle_outline_rounded, () {
                  if (_aaPeople > 2) setState(() => _aaPeople--);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('$_aaPeople 人',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                _peopleButton(Icons.add_circle_outline_rounded, () {
                  if (_aaPeople < 20) setState(() => _aaPeople++);
                }),
                const SizedBox(width: 6),
              ],
            ),
          Switch(
            value: _aaEnabled,
            activeThumbColor: AppTheme.accent,
            onChanged: (v) => setState(() => _aaEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _peopleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 22, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _categoryGrid() {
    final categoriesAsync = _type == TransactionType.income
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    final fallbackName = _type == TransactionType.income ? '收入' : '其他';

    return categoriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('分类加载失败：$e',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('暂无$_type分类，请到「数据 → 分类管理」添加',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          );
        }
        // 编辑模式下若无当前分类名，则默认选中第一个
        final selected = _category ?? fallbackName;
        if (CategoryUtils.byName(categories, selected) == null) {
          // 名称不存在（可能已被删除），回退第一个
          _category ??= categories.first.name;
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in categories) _categoryItem(c, selected),
          ],
        );
      },
    );
  }

  Widget _categoryItem(Category c, String selected) {
    final isSelected = selected == c.name;
    final color = CategoryUtils.colorOfCategory(c);

    return GestureDetector(
      onTap: () => setState(() {
        _type = c.isIncome ? TransactionType.income : TransactionType.expense;
        _category = c.name;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.30)
              : AppTheme.onSurface(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.onSurface(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(CategoryUtils.iconOfCategory(c), color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              c.name.length > 4 ? '${c.name.substring(0, 4)}…' : c.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return Column(
      children: [
        if (_isEdit) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.expenseColor,
                backgroundColor: AppTheme.expenseColor.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _deleteCurrent,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('删除此条',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _save,
            child: Text(_isEdit ? '保存修改' : '保存',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  /// 编辑模式下删除当前流水
  Future<void> _deleteCurrent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除流水'),
        content: const Text('确定删除这条流水吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.expenseColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final notifier = ref.read(transactionListProvider.notifier);
    await notifier.remove(widget.initial!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast('已删除');
  }
}
