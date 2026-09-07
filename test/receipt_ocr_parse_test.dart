import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ledger/services/receipt_ocr_service.dart';

/// 解析规则单元测试：覆盖微信/支付宝账单、超市小票、餐厅小票等常见样式
void main() {
  group('金额解析', () {
    test('微信支付样式：¥ 前缀', () {
      final r = ReceiptOcrService.parse(
          '微信支付\n向商户付款\n¥25.00\n交易时间 2026-09-07');
      expect(r.amount, 25.0);
    });

    test('支付宝样式：￥ 前缀带空格', () {
      final r = ReceiptOcrService.parse('支付宝\n￥ 12.50\n餐饮消费');
      expect(r.amount, 12.5);
    });

    test('千分位金额', () {
      final r = ReceiptOcrService.parse('合计金额：¥1,234.50');
      expect(r.amount, 1234.5);
    });

    test('小票合计关键词', () {
      final r = ReceiptOcrService.parse('商品小计 88.00\n合计金额：128.50元\n实收 128.5');
      expect(r.amount, 128.5);
    });

    test('实付优先于其他金额', () {
      final r = ReceiptOcrService.parse('商品总额 500.00\n优惠 -20.00\n实付 480.00');
      expect(r.amount, 480.0);
    });

    test('o/O 误识别为 0', () {
      final r = ReceiptOcrService.parse('¥25.oo');
      expect(r.amount, 25.0);
    });

    test('订单号/长数字不干扰关键词金额', () {
      final r = ReceiptOcrService.parse('订单号 202609071234567890\n合计 35.00');
      expect(r.amount, 35.0);
    });

    test('纯年份不作为金额', () {
      final r = ReceiptOcrService.parse('2026\n12.30');
      expect(r.amount, 12.3);
    });

    test('无金额返回 null', () {
      final r = ReceiptOcrService.parse('谢谢惠顾\n欢迎再次光临');
      expect(r.amount, isNull);
    });
  });

  group('分类识别', () {
    test('餐饮词', () {
      expect(ReceiptOcrService.parse('海底捞 火锅 账单').category, '餐饮');
    });

    test('外卖', () {
      expect(ReceiptOcrService.parse('美团外卖订单').category, '餐饮');
    });

    test('超市购物', () {
      expect(ReceiptOcrService.parse('沃尔玛超市').category, '购物');
    });

    test('交通', () {
      expect(ReceiptOcrService.parse('地铁乘车码').category, '交通');
    });

    test('收入', () {
      expect(ReceiptOcrService.parse('工资入账通知').category, '收入');
    });

    test('无关键词返回 null', () {
      expect(ReceiptOcrService.parse('一些没有分类词的文字').category, isNull);
    });
  });

  group('日期识别', () {
    test('中文日期', () {
      final r = ReceiptOcrService.parse('2026年9月7日 消费');
      expect(r.date, DateTime(2026, 9, 7));
    });

    test('横线日期', () {
      final r = ReceiptOcrService.parse('2026-09-07');
      expect(r.date, DateTime(2026, 9, 7));
    });

    test('斜线日期', () {
      final r = ReceiptOcrService.parse('2026/9/7');
      expect(r.date, DateTime(2026, 9, 7));
    });

    test('月日格式默认当年', () {
      final now = DateTime.now();
      final r = ReceiptOcrService.parse('9月7日');
      expect(r.date, DateTime(now.year, 9, 7));
    });

    test('无日期返回 null', () {
      expect(ReceiptOcrService.parse('谢谢惠顾').date, isNull);
    });
  });
}
