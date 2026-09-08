import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ledger/services/receipt_ocr_service.dart';

/// 一句话记账解析单元测试
void main() {
  group('一句话记账：金额提取', () {
    test('午饭 32 → 32 元，餐饮', () {
      final r = ReceiptOcrService.parseQuickText('午饭 32');
      expect(r.amount, 32.0);
      expect(r.category, '餐饮');
      expect(r.note, '午饭');
    });

    test('打车 25.5 → 25.5 元，交通', () {
      final r = ReceiptOcrService.parseQuickText('打车 25.5');
      expect(r.amount, 25.5);
      expect(r.category, '交通');
      expect(r.note, '打车');
    });

    test('工资 8000 → 收入，4 位整数被收入提示放行', () {
      final r = ReceiptOcrService.parseQuickText('工资 8000');
      expect(r.amount, 8000.0);
      expect(r.category, '收入');
      expect(r.note, '工资');
    });

    test('奶茶 15 元 → 15 元，备注去掉单位', () {
      final r = ReceiptOcrService.parseQuickText('奶茶 15 元');
      expect(r.amount, 15.0);
      expect(r.category, '餐饮');
      expect(r.note, '奶茶');
    });

    test('纯数字 32 → 32 元', () {
      final r = ReceiptOcrService.parseQuickText('32');
      expect(r.amount, 32.0);
      expect(r.note, '');
    });

    test('红包 200 → 收入 200', () {
      final r = ReceiptOcrService.parseQuickText('红包 200');
      expect(r.amount, 200.0);
      expect(r.category, '收入');
    });

    test('买了 2 个苹果 15 元 → 取句末金额 15', () {
      final r = ReceiptOcrService.parseQuickText('买了 2 个苹果 15 元');
      expect(r.amount, 15.0);
      expect(r.note, '买了 个苹果');
    });

    test('纯年份 2026 不作为金额', () {
      final r = ReceiptOcrService.parseQuickText('2026');
      expect(r.amount, isNull);
    });

    test('长订单号不作为金额', () {
      final r = ReceiptOcrService.parseQuickText('订单 202609071234567');
      expect(r.amount, isNull);
    });

    test('没有数字 → 金额为 null', () {
      final r = ReceiptOcrService.parseQuickText('午饭');
      expect(r.amount, isNull);
    });

    test('空输入 → 金额为 null', () {
      final r = ReceiptOcrService.parseQuickText('  ');
      expect(r.amount, isNull);
      expect(r.note, '');
    });
  });
}
