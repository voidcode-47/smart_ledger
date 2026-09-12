import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/minigame_catalog.dart';
import 'game_webview_screen.dart';

/// 小游戏合集：115 款零依赖离线游戏 + 2 款联网官方 Demo。
/// - 离线游戏：单文件源码打包在应用内，无需联网；
/// - 联网游戏：开源作者官方在线 Demo，需网络可达。
class MiniGamesScreen extends StatefulWidget {
  const MiniGamesScreen({super.key});

  @override
  State<MiniGamesScreen> createState() => _MiniGamesScreenState();
}

class _MiniGamesScreenState extends State<MiniGamesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _category;

  static const _categories = ['策略养成', '动作射击', '竞速体育', '益智棋牌', '休闲经营'];

  static const _tierWeight = {'SSS': 4, 'SS': 3, 'S': 2, 'A': 1};

  List<MiniGame> _filtered(List<MiniGame> games) {
    final q = _query.trim();
    // 复制为可变列表（MiniGame.offline 等是 const 列表，不可直接 sort）
    var list = games.toList();
    if (_category != null) {
      list = list.where((g) => g.category == _category).toList();
    }
    if (q.isNotEmpty) {
      list = list
          .where((g) => g.title.contains(q) || g.subtitle.contains(q))
          .toList();
    }
    list.sort((a, b) {
      final tw = (_tierWeight[b.tier] ?? 0) - (_tierWeight[a.tier] ?? 0);
      if (tw != 0) return tw;
      return a.title.compareTo(b.title);
    });
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = _filtered(MiniGame.offline);
    final online = _filtered(MiniGame.online);

    return Scaffold(
      appBar: AppBar(
        title: const Text('小游戏合集'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '搜索游戏名称或玩法…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: AppTheme.onSurface(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _filterChip(null, '全部'),
                for (final c in _categories) _filterChip(c, c),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_query.isEmpty && _category == null)
                  _sectionHeader(
                    '离线游戏 · ${MiniGame.offline.length} 款',
                    '零依赖单文件，已打包进应用，无需联网',
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      '找到 ${offline.length + online.length} 款',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                ...offline.map((g) => _gameCard(context, g)),
                if (online.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionHeader('联网游戏 · ${online.length} 款',
                      '开源作者官方在线 Demo 页面'),
                  ...online.map((g) => _gameCard(context, g)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? value, String label) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value),
        labelStyle: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : AppTheme.textPrimary,
        ),
        selectedColor: AppTheme.accent,
        backgroundColor: AppTheme.onSurface(alpha: 0.06),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Color _tierColor(String? tier) => switch (tier) {
        'SSS' => const Color(0xFFB8860B),
        'SS' => const Color(0xFF6B7280),
        'S' => const Color(0xFF2563EB),
        _ => AppTheme.onSurface(alpha: 0.5),
      };

  Widget _gameCard(BuildContext context, MiniGame game) {
    final tier = game.tier;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => GameWebViewScreen(game: game)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.onSurface(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(game.icon, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(game.title,
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (tier != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _tierColor(tier).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tier,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _tierColor(tier),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        game.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${game.category ?? ''} · 离线可玩',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
