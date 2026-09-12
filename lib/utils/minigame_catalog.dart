/// 小游戏合集目录。
///
/// 离线游戏为「mini-browser-games」开源合集（MIT），115 款零依赖单文件
/// HTML5 游戏，完整源码打包在 assets/minigames/ 下，无需联网即可游玩；
/// 联网游戏为开源作者官方在线 Demo 页面，需要网络可达。
library;

import 'minigame_library_data.dart';

/// 虚拟按键（供键盘类游戏在触屏上操作）
class MiniGameKey {
  final String label;
  final String key;
  final String code;
  final int keyCode;

  /// 是否为方向/动作键（布局时与开始/暂停等功能键分行）
  final bool direction;
  const MiniGameKey(this.label, this.key, this.code, this.keyCode,
      {this.direction = true});

  static const up = MiniGameKey('上', 'ArrowUp', 'ArrowUp', 38);
  static const down = MiniGameKey('下', 'ArrowDown', 'ArrowDown', 40);
  static const left = MiniGameKey('左', 'ArrowLeft', 'ArrowLeft', 37);
  static const right = MiniGameKey('右', 'ArrowRight', 'ArrowRight', 39);
  static const rotate = MiniGameKey('转', 'ArrowUp', 'ArrowUp', 38);
  static const start =
      MiniGameKey('开始', ' ', 'Space', 32, direction: false);
  static const pause = MiniGameKey('暂停', ' ', 'Space', 32, direction: false);
  static const pauseP = MiniGameKey('暂停', 'p', 'KeyP', 80, direction: false);

  // Pong：Q/A 控制左挡板上下，1/2 选择模式
  static const upQ = MiniGameKey('上', 'q', 'KeyQ', 81);
  static const downA = MiniGameKey('下', 'a', 'KeyA', 65);
  static const solo = MiniGameKey('单人', '1', 'Digit1', 49, direction: false);
  static const duo = MiniGameKey('双人', '2', 'Digit2', 50, direction: false);
}

/// 游戏需要的输入方式
enum MiniGameInput {
  /// 触屏/点击即可，无需虚拟按键
  none,

  /// 十字方向键（贪吃蛇等）
  dPad,

  /// 方向键 + 旋转 + 开始（俄罗斯方块等）
  dPadRotate,

  /// 左右键（打砖块等）
  leftRight,

  /// 上下键 + 单人/双人模式（Pong 等）
  upDown,
}

class MiniGame {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String license;
  final String source;
  final String? assetIndex;
  final String? onlineUrl;
  final MiniGameInput input;

  /// 质量分级（SSS/SS/S/A/D，来自合集维护方的 GAME_TIERS）
  final String? tier;

  /// 分类（策略养成/动作射击/竞速体育/益智棋牌/休闲经营）
  final String? category;

  const MiniGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.license,
    required this.source,
    required this.input,
    this.assetIndex,
    this.onlineUrl,
    this.tier,
    this.category,
  });

  /// 是否需要联网
  bool get needsNetwork => onlineUrl != null;

  /// 根据输入方式提供虚拟按键布局
  List<MiniGameKey> get virtualKeys => switch (input) {
        MiniGameInput.none => const [],
        MiniGameInput.dPad => const [
            MiniGameKey.up,
            MiniGameKey.left,
            MiniGameKey.down,
            MiniGameKey.right,
            MiniGameKey.pause,
          ],
        MiniGameInput.dPadRotate => const [
            MiniGameKey.left,
            MiniGameKey.rotate,
            MiniGameKey.down,
            MiniGameKey.right,
            MiniGameKey.start,
          ],
        MiniGameInput.leftRight => const [
            MiniGameKey.left,
            MiniGameKey.right,
            MiniGameKey.pauseP,
          ],
        MiniGameInput.upDown => const [
            MiniGameKey.upQ,
            MiniGameKey.downA,
            MiniGameKey.solo,
            MiniGameKey.duo,
          ],
      };

  /// 离线游戏（115 款零依赖单文件，打包在 assets/minigames/，无需联网）
  /// 数据源：minigame_library_data.dart（由 mini-browser-games README 生成）
  static const List<MiniGame> offline = miniGameLibrary;

  /// 联网游戏（开源作者官方在线 Demo，需要网络）
  static const List<MiniGame> online = [
    MiniGame(
      id: 'tetris-online',
      title: '俄罗斯方块 · 在线',
      subtitle: '需要联网 · 开源作者官方页面',
      icon: '🌐',
      license: 'MIT · jakesgordon/javascript-tetris',
      source: 'https://github.com/jakesgordon/javascript-tetris',
      input: MiniGameInput.dPadRotate,
      onlineUrl: 'https://codeincomplete.com/games/tetris/',
    ),
    MiniGame(
      id: 'snake-online',
      title: '贪吃蛇 · 在线',
      subtitle: '需要联网 · 开源作者官方页面',
      icon: '🌐',
      license: 'MIT · patorjk/JavaScript-Snake',
      source: 'https://github.com/patorjk/JavaScript-Snake',
      input: MiniGameInput.dPad,
      onlineUrl: 'http://patorjk.com/games/snake/',
    ),
  ];

  /// 全部游戏
  static const List<MiniGame> all = [...offline, ...online];

  /// 按 id 查找
  static MiniGame? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }
}
