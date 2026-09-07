import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/transaction_model.dart';
import '../utils/format_utils.dart';

/// CSV 导出 / 导入服务
/// 格式：date,type,category,amount,note（UTF-8，type ∈ {expense, income}）
/// category 为分类名称；导入时自动兼容旧版枚举名（food 等）
class CsvService {
  CsvService._();

  static const List<String> header = ['date', 'type', 'category', 'amount', 'note'];

  /// 导出全部流水为 CSV。
  /// 桌面端优先写入系统“下载”文件夹，移动端回退到应用文档目录，返回文件完整路径。
  static Future<String> exportCsv(List<TransactionEntry> entries) async {
    final buffer = StringBuffer()..writeln(header.join(','));
    for (final e in entries) {
      buffer.writeln([
        e.date.toIso8601String(),
        e.isIncome ? 'income' : 'expense',
        e.category,
        e.amount.toStringAsFixed(2),
        _escapeField(e.note),
      ].join(','));
    }

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(p.join(
      dir.path,
      'smart_ledger_${FormatUtils.fileStamp(DateTime.now())}.csv',
    ));
    await file.writeAsString(buffer.toString(), encoding: utf8, flush: true);
    return file.path;
  }

  /// 通过系统文件选择器选取 CSV 并解析为流水列表（用户取消返回空列表）
  static Future<List<TransactionEntry>> pickAndParseCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return const [];

    final String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else {
      content = await File(file.path!).readAsString();
    }
    return parseCsv(content);
  }

  /// 简易 CSV 解析（支持引号转义、跨字段逗号）
  static List<TransactionEntry> parseCsv(String raw) {
    final content =
        raw.startsWith('\uFEFF') ? raw.substring(1) : raw; // 去除 BOM
    final rows = _parseRows(content);
    if (rows.isEmpty) return const [];

    // 跳过表头
    final first = rows.first.first.trim().toLowerCase();
    final dataRows = first == 'date' ? rows.sublist(1) : rows;

    final entries = <TransactionEntry>[];
    for (final r in dataRows) {
      if (r.length < 4) continue;
      final date = DateTime.tryParse(r[0].trim());
      final amount = double.tryParse(r[3].trim());
      if (date == null || amount == null || amount <= 0) continue;
      final isIncome = r[1].trim().toLowerCase() == 'income';
      // 兼容旧版 CSV 的枚举分类名（food 等）与收入记录旧值
      final rawCat = legacyCategoryName(r[2].trim());
      final category =
          isIncome && (rawCat == '其他' || rawCat == 'other') ? '收入' : rawCat;
      entries.add(TransactionEntry(
        amount: amount,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        category: category,
        date: date,
        note: r.length > 4 ? r[4] : '',
      ));
    }
    return entries;
  }

  static String _escapeField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static List<List<String>> _parseRows(String content) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void flushField() {
      row.add(field.toString());
      field.clear();
    }

    void flushRow() {
      flushField();
      if (row.length > 1 || row.first.trim().isNotEmpty) {
        rows.add(List<String>.from(row));
      }
      row.clear();
    }

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        flushField();
      } else if (ch == '\r') {
        // 忽略
      } else if (ch == '\n') {
        flushRow();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) flushRow();
    return rows;
  }
}
