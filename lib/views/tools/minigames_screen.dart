import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/minigame_catalog.dart';
import 'game_webview_screen.dart';

/// 小游戏合集：全部为公开免费的开源小游戏。
/// - 离线游戏：源码打包在应用内，无需联网；
/// - 联网游戏：开源作者官方在线 Demo，需网络可达。
class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小游戏合集'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sectionHeader('离线游戏 · 无需联网', '全部来自公开免费的开源项目，已打包进应用'),
          ...MiniGame.offline.map((g) => _gameCard(context, g)),
          const SizedBox(height: 20),
          _sectionHeader('联网游戏 · 需要网络', '开源作者官方在线 Demo 页面'),
          ...MiniGame.online.map((g) => _gameCard(context, g)),
        ],
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
                fontSize: 12.5, color: Colors.grey.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(BuildContext context, MiniGame game) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
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
                      Text(game.title,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        game.subtitle,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.withValues(alpha: 0.9)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        game.license,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.withValues(alpha: 0.7)),
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
