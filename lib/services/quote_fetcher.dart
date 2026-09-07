import 'dart:convert';
import 'dart:io';

import '../utils/quote_utils.dart';

/// 联网格言获取：优先一言 API（文学/诗词/哲学/网络分类），
/// 结果经过安全过滤，失败或内容不合规时回退本地库。
class QuoteFetcher {
  QuoteFetcher._();

  /// 不合规内容关键词（命中即丢弃，避免展示不适内容）
  static const List<String> _blocked = [
    // 政治敏感
    '习明泽', '刘晓波', '郝海东', '六四', '天安门事件', '白纸运动', '四通桥',
    // 违法/低俗
    '赌博', '色情', '嫖娼', '毒品', '自杀',
  ];

  /// 从一言 API 拉取一条格言；失败或内容不合规返回 null
  static Future<QuoteItem?> fetchRemote() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      try {
        final req = await client.getUrl(Uri.parse(
            'https://v1.hitokoto.cn/?encode=json&c=d&c=i&c=e&c=f&c=k'));
        req.headers.set(HttpHeaders.userAgentHeader, 'smart_ledger/1.0');
        final resp = await req.close();
        if (resp.statusCode != 200) return null;
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final text = (data['hitokoto'] as String?)?.trim();
        if (text == null || text.isEmpty) return null;
        if (_blocked.any(text.toLowerCase().contains)) return null;

        final from = (data['from'] as String?)?.trim() ?? '';
        final who = (data['from_who'] as String?)?.trim() ?? '';
        final source =
            [who, from].where((s) => s.isNotEmpty).join('·').trim();
        return QuoteItem(text, source.isEmpty ? '一言' : source);
      } finally {
        client.close();
      }
    } catch (_) {
      return null; // 网络异常/超时：回退本地
    }
  }
}
