import 'package:flutter_test/flutter_test.dart';

import 'package:smart_ledger/utils/quote_utils.dart';

void main() {
  group('QuoteUtils.random', () {
    test('返回的格言文本与来源均非空', () {
      for (var i = 0; i < 50; i++) {
        final q = QuoteUtils.random();
        expect(q.text.trim(), isNotEmpty);
        expect(q.source.trim(), isNotEmpty);
      }
    });

    test('连续多次抽取不与上一次重复（避免刷屏同一条）', () {
      QuoteItem? prev;
      for (var i = 0; i < 200; i++) {
        final q = QuoteUtils.random();
        if (prev != null) {
          expect(q.text, isNot(equals(prev.text)),
              reason: '第 $i 次不应与上一次相同');
        }
        prev = q;
      }
    });
  });
}
