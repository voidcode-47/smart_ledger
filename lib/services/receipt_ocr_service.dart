import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// 票据/账单图片识别结果
class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  /// 识别出的金额（元），未识别到为 null
  final double? amount;

  /// 根据关键词推断的分类名（须与分类表中的名称一致），未匹配为 null
  final String? category;

  /// 识别出的日期，未识别到为 null
  final DateTime? date;

  /// 识别文本（去空白拼接），供用户参考/填入备注
  final String note;
}

/// OCR 识别失败（含可读提示），由调用方捕获后展示
class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 图片识别服务：Android 使用本地 ML Kit OCR（免费、离线）
class ReceiptOcrService {
  ReceiptOcrService._();

  /// 是否支持（当前 OCR 引擎仅 Android）
  static bool get supported => Platform.isAndroid;  /// 识别图片：本地 OCR + 规则解析。
  /// 任何异常（模型加载失败、图片过大等）都会被转换为带提示的 [OcrException]，
  /// 由调用方捕获展示，避免未捕获异常导致应用闪退。
  static Future<ReceiptOcrResult> recognize(XFile image) async {
    TextRecognizer? recognizer;
    try {
      recognizer =
          TextRecognizer(script: TextRecognitionScript.chinese);
      final input = InputImage.fromFilePath(image.path);
      final text = await recognizer.processImage(input);
      final raw = text.blocks
          .map((b) => b.lines.map((l) => l.text).join(' '))
          .join('\n');
      return parse(raw);
    } on OcrException {
      rethrow;
    } catch (e) {
      throw OcrException('识别引擎出错：$e');
    } finally {
      try {
        recognizer?.close();
      } catch (_) {}
    }
  }

  // ---------------- 规则解析（纯函数，便于测试） ----------------

  /// 分类关键词映射：关键词 -> 分类名
  static const Map<String, List<String>> _categoryKeywords = {
    '餐饮': [
      '餐', '吃饭', '外卖', '食堂', '奶茶', '咖啡', '面馆', '烧烤', '火锅', '小吃', '快餐',
      '餐厅', '饭店', '肯德基', '麦当劳', '汉堡', '面条', '饺子', '米线', '炒菜', '夜宵',
      '星巴克', '甜品', '蛋糕', '零食', '水果',
    ],
    '购物': [
      '超市', '购物', '淘宝', '京东', '拼多多', '便利店', '商场', '服装', '鞋', '商城',
      '药店', '文具', '天猫', '唯品会', '沃尔玛', '永辉', '家乐福', '百货',
    ],
    '交通': [
      '地铁', '公交', '滴滴', '打车', '出租', '加油', '停车', '高铁', '火车', '车票',
      '骑行', '顺风车', '公交卡', '高速', '燃油',
    ],
    '娱乐': [
      '电影', '游戏', 'KTV', '网吧', '景点', '门票', '视频', '会员', '影院', '唱吧',
    ],
    '其他': [
      '缴费', '水电', '物业', '话费', '快递', '房租', '燃气', '宽带', '医院', '药房',
      '学费', '罚款',
    ],
    '收入': [
      '工资', '转账', '收款', '红包', '奖金', '退款', '报销', '入账', '支付宝到账',
      '微信到账', '薪水',
    ],
  };

  static ReceiptOcrResult parse(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final text = lines.join(' ');

    return ReceiptOcrResult(
      amount: _parseAmount(lines),
      category: _parseCategory(text),
      date: _parseDate(text),
      note: text.length > 60 ? text.substring(0, 60) : text,
    );
  }

  /// OCR 文本清洗：千分位逗号、小写 o/O 被误识别的 0、全角字符
  static String _cleanNumber(String s) => s
      .replaceAll(',', '')
      .replaceAll('，', '')
      .replaceAll('o', '0')
      .replaceAll('O', '0')
      .replaceAll('｡', '.');

  /// 金额解析：
  /// 1) ¥/￥ 前缀（微信/支付宝账单样式，最可靠）
  /// 2) 关键词引导（实付/合计/总计/金额/付款/支付/消费/小计/应收/总价）
  /// 3) 独立数字行（形如 25.00 或 25，排除日期/年份/电话/长订单号干扰）
  /// 每级内取最大值（账单总额通常是最大金额）
  static double? _parseAmount(List<String> lines) {
    double? best;
    void consider(double? v) {
      final value = v;
      if (value == null || value <= 0 || value > 9999999) return;
      final current = best;
      if (current == null || value > current) best = value;
    }

    // 1) 货币符号前缀：¥25.00 / ￥ 12.5 / ¥1,234.50
    final reSymbol = RegExp(r'[¥￥]\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)');
    for (final line in lines) {
      for (final m in reSymbol.allMatches(line)) {
        consider(double.tryParse(_cleanNumber(m.group(1)!)));
      }
    }
    if (best != null) return best;

    // 2) 关键词引导：实付（微信/支付宝账单最常出现）> 合计/总计/金额等
    final reKw =
        RegExp(r'(?:实付|合计|总计|金额|付款|支付|消费|小计|应收|总价)\D{0,8}(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)(?:元)?');
    for (final line in lines) {
      for (final m in reKw.allMatches(line)) {
        consider(double.tryParse(_cleanNumber(m.group(1)!)));
      }
    }
    if (best != null) return best;

    // 3) 独立数字行：2~7 位数字（可带 1~2 位小数），排除 4 位纯整数（年份）、
    //    8 位以上（订单号/流水号/手机号）、以及形如 12.30 的时间误判（结合上下文难以
    //    完全排除，故仅接受 <= 9999999 的合理值）
    final rePlain = RegExp(r'^(\d{2,7}(?:\.\d{1,2})?)$');
    for (final line in lines) {
      // 排除纯 4 位整数（极可能是年份如 2026）
      if (RegExp(r'^\d{4}$').hasMatch(line)) continue;
      final m = rePlain.firstMatch(line);
      if (m != null) consider(double.tryParse(_cleanNumber(m.group(1)!)));
    }
    return best;
  }

  static String? _parseCategory(String text) {
    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return null;
  }

  static DateTime? _parseDate(String text) {
    final now = DateTime.now();
    // 2026年9月7日 / 2026-09-07 / 2026/09/07
    final reFull = RegExp(r'(\d{4})[年\-/.](\d{1,2})[月\-/.](\d{1,2})');
    final mFull = reFull.firstMatch(text);
    if (mFull != null) {
      return DateTime(int.parse(mFull.group(1)!), int.parse(mFull.group(2)!),
          int.parse(mFull.group(3)!));
    }
    // 9月7日 / 09-07（默认当年）
    final reShort = RegExp(r'(?:^|\D)(\d{1,2})[月\-/.](\d{1,2})(?:日)?(?:$|\D)');
    final mShort = reShort.firstMatch(text);
    if (mShort != null) {
      return DateTime(now.year, int.parse(mShort.group(1)!),
          int.parse(mShort.group(2)!));
    }
    return null;
  }
}
