import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/quote_fetcher.dart';
import '../utils/app_theme.dart';
import '../utils/quote_utils.dart';
import 'glass_card.dart';

/// 仪表盘顶部名言卡：进入时随机显示（联网优先，失败回退本地），
/// 点击复制，可换一条
class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  /// 会话级远程格言缓存：同一会话内联网获取一次后不再重复刷新，
  /// 避免切页/滚动重建时格言频繁变化
  static QuoteItem? _remoteCache;

  late QuoteItem _quote;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_remoteCache != null) {
      _quote = _remoteCache!;
    } else {
      _quote = QuoteUtils.random();
      // 首次进入：本地格言立即显示，联网获取在后台静默完成（不转圈）
      _tryRemote(silent: true);
    }
  }

  /// 联网获取：成功则更新缓存与当前显示；失败时根据 [swapOnFail] 决定是否换本地。
  /// [silent] 为 true 时后台静默获取（不显示转圈）；无论哪种方式，
  /// 刷新期间都保持当前格言不变，完成后一次性更新，避免"闪两条"。
  Future<void> _tryRemote(
      {bool swapOnFail = false, bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent && mounted) setState(() {});
    final remote = await QuoteFetcher.fetchRemote();
    if (!mounted) return;
    setState(() {
      if (remote != null) {
        _quote = remote;
        _remoteCache = remote;
      } else if (swapOnFail) {
        // 手动刷新且联网失败：换一条本地格言
        _quote = QuoteUtils.random();
      }
      _loading = false;
    });
  }

  void _refresh() => _tryRemote(swapOnFail: true);

  Future<void> _copy() async {
    final full = '${_quote.text} —— ${_quote.source}';
    await Clipboard.setData(ClipboardData(text: full));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('已复制：$full'),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _copy,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 30, color: AppTheme.accent.withValues(alpha: 0.85)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quote.text,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '—— ${_quote.source}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurface(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '换一条（联网获取）',
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _refresh,
                icon: _loading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.onSurface(alpha: 0.45)),
                      )
                    : Icon(Icons.refresh_rounded,
                        size: 18, color: AppTheme.onSurface(alpha: 0.55)),
              ),
              Icon(Icons.copy_rounded,
                  size: 15, color: AppTheme.onSurface(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}
