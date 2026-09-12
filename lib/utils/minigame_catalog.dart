/// 小游戏合集目录。
///
/// 所有离线游戏均为公开免费的开源 HTML5 项目（MIT 等宽松许可），
/// 完整源码打包在 assets/minigames/<id>/ 下，无需联网即可游玩；
/// 联网游戏为开源作者官方在线 Demo 页面，需要网络可达。
library;

/// 虚拟按键（供键盘类游戏在触屏上操作）
class MiniGameKey {
  final String label;
  final String key;
  final String code;
  final int keyCode;
  const MiniGameKey(this.label, this.key, this.code, this.keyCode);

  static const up = MiniGameKey('上', 'ArrowUp', 'ArrowUp', 38);
  static const down = MiniGameKey('下', 'ArrowDown', 'ArrowDown', 40);
  static const left = MiniGameKey('左', 'ArrowLeft', 'ArrowLeft', 37);
  static const right = MiniGameKey('右', 'ArrowRight', 'ArrowRight', 39);
  static const rotate = MiniGameKey('转', 'ArrowUp', 'ArrowUp', 38);
  static const start = MiniGameKey('开始', ' ', 'Space', 32);
  static const pause = MiniGameKey('暂停', ' ', 'Space', 32);
  static const pauseP = MiniGameKey('暂停', 'p', 'KeyP', 80);
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
      };

  /// 离线游戏（打包在 assets，无需联网）
  static const List<MiniGame> offline = [
    MiniGame(
      id: '2048',
      title: '2048',
      subtitle: '数字合并 · 滑动屏幕或方向键',
      icon: '🔢',
      license: 'MIT · gabrielecirulli/2048',
      source: 'https://github.com/gabrielecirulli/2048',
      input: MiniGameInput.none,
      assetIndex: 'assets/minigames/2048/index.html',
    ),
    MiniGame(
      id: 'tetris',
      title: '俄罗斯方块',
      subtitle: '经典消除 · 左/右移动、上旋转、下加速',
      icon: '🧩',
      license: 'MIT · jakesgordon/javascript-tetris',
      source: 'https://github.com/jakesgordon/javascript-tetris',
      input: MiniGameInput.dPadRotate,
      assetIndex: 'assets/minigames/tetris/index.html',
    ),
    MiniGame(
      id: 'snake',
      title: '贪吃蛇',
      subtitle: '经典街机 · 方向键控制，吃到越长',
      icon: '🐍',
      license: 'MIT · patorjk/JavaScript-Snake',
      source: 'https://github.com/patorjk/JavaScript-Snake',
      input: MiniGameInput.dPad,
      assetIndex: 'assets/minigames/snake/src/index.html',
    ),
    MiniGame(
      id: 'minesweeper',
      title: '扫雷',
      subtitle: '逻辑推理 · 点开格子，避开地雷',
      icon: '💣',
      license: 'MIT · Joeynoh/HTML5-Minesweeper',
      source: 'https://github.com/Joeynoh/HTML5-Minesweeper',
      input: MiniGameInput.none,
      assetIndex: 'assets/minigames/minesweeper/index.html',
    ),
    MiniGame(
      id: 'memory',
      title: '记忆翻牌',
      subtitle: '翻牌配对 · 考验记忆力',
      icon: '🃏',
      license: 'MIT · mmenavas/memory-game',
      source: 'https://github.com/mmenavas/memory-game',
      input: MiniGameInput.none,
      assetIndex: 'assets/minigames/memory/index.html',
    ),
    MiniGame(
      id: 'breakout',
      title: '打砖块',
      subtitle: '弹球破砖 · 左右移动挡板',
      icon: '🏓',
      license: 'MIT · DhanushNehru/breakout-game',
      source: 'https://github.com/DhanushNehru/breakout-game',
      input: MiniGameInput.leftRight,
      assetIndex: 'assets/minigames/breakout/index.html',
    ),
    MiniGame(
      id: 'sudoku',
      title: '数独',
      subtitle: '数字逻辑 · 每一行每一列不重复',
      icon: '🧮',
      license: 'MIT · vincenzo-afk/sudokuflow',
      source: 'https://github.com/vincenzo-afk/sudokuflow',
      input: MiniGameInput.none,
      assetIndex: 'assets/minigames/sudoku/index.html',
    ),
  ];

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
