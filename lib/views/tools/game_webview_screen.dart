import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/minigame_catalog.dart';

/// 小游戏 WebView 页：离线游戏加载本地打包的开源 HTML5 游戏，
/// 联网游戏加载开源作者官方在线 Demo；键盘类游戏提供底部虚拟按键。
class GameWebViewScreen extends StatefulWidget {
  final MiniGame game;
  const GameWebViewScreen({super.key, required this.game});

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  late final WebViewController _controller;
  bool _loadFailed = false;

  /// 注入按键转发器：同时派发到 document 与贪吃蛇的 #game-area 容器，
  /// 兼容不同游戏的事件监听位置。手动赋值 key/code/keyCode/which。
  static const String _injectScript = r'''
window.__sendKey = function (key, code, keyCode, isDown) {
  var ev = new Event(isDown ? 'keydown' : 'keyup', { bubbles: true, cancelable: true });
  ev.key = key; ev.code = code; ev.keyCode = keyCode; ev.which = keyCode;
  document.dispatchEvent(ev);
  var ga = document.getElementById('game-area');
  if (ga) ga.dispatchEvent(ev);
  return true;
};
true;
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          _controller.runJavaScript(_injectScript);
        },
        onWebResourceError: (err) {
          if (mounted && widget.game.needsNetwork && !_loadFailed) {
            setState(() => _loadFailed = true);
          }
        },
        onHttpError: (resp) {
          if (mounted && widget.game.needsNetwork && !_loadFailed) {
            setState(() => _loadFailed = true);
          }
        },
      ));
    final game = widget.game;
    if (game.assetIndex != null) {
      _controller.loadFlutterAsset(game.assetIndex!);
    } else if (game.onlineUrl != null) {
      _controller.loadRequest(Uri.parse(game.onlineUrl!));
    }
  }

  Future<void> _sendKey(MiniGameKey key, bool down) async {
    if (_loadFailed) return;
    try {
      await _controller.runJavaScript(
        "window.__sendKey('${key.key}','${key.code}',${key.keyCode},${down ? 'true' : 'false'});",
      );
    } catch (_) {}
  }

  Future<void> _reload() async {
    setState(() => _loadFailed = false);
    final game = widget.game;
    if (game.assetIndex != null) {
      await _controller.loadFlutterAsset(game.assetIndex!);
    } else if (game.onlineUrl != null) {
      await _controller.loadRequest(Uri.parse(game.onlineUrl!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final keys = game.virtualKeys;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${game.icon} ${game.title}',
            style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadFailed)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off,
                              color: Colors.white70, size: 40),
                          const SizedBox(height: 12),
                          const Text('联网游戏加载失败',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            '请检查网络后点右上角刷新；\n离线游戏不受影响。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (keys.isNotEmpty) _buildKeypad(keys),
          SafeArea(top: false, child: Container(height: 0)),
        ],
      ),
    );
  }

  Widget _buildKeypad(List<MiniGameKey> keys) {
    // 按游戏布局分两行：方向类（左/右 + 上/下/旋转）与功能键（开始/暂停）
    final dirKeys = keys
        .where((k) =>
            k.keyCode >= 37 && k.keyCode <= 40 && k.label != '转')
        .toList();
    final funcKeys = keys
        .where((k) => k.keyCode < 37 || k.keyCode > 40 || k.label == '转')
        .toList();

    Widget row(List<MiniGameKey> items) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in items) ...[
                _VirtualKeyButton(miniKey: k, onKey: _sendKey),
                const SizedBox(width: 14),
              ],
            ],
          ),
        );

    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (funcKeys.isNotEmpty) row(funcKeys),
          if (dirKeys.isNotEmpty) row(dirKeys),
        ],
      ),
    );
  }
}

/// 虚拟按键：按下派发 keydown 并每 160ms 自动重复（满足俄罗斯方块长按连续移动），
/// 松开派发 keyup（打砖块等需要复位）。
class _VirtualKeyButton extends StatefulWidget {
  final MiniGameKey miniKey;
  final Future<void> Function(MiniGameKey key, bool down) onKey;
  const _VirtualKeyButton({required this.miniKey, required this.onKey});

  @override
  State<_VirtualKeyButton> createState() => _VirtualKeyButtonState();
}

class _VirtualKeyButtonState extends State<_VirtualKeyButton> {
  Timer? _timer;

  void _down() {
    widget.onKey(widget.miniKey, true);
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 160),
      (_) => widget.onKey(widget.miniKey, true),
    );
  }

  void _up() {
    _timer?.cancel();
    _timer = null;
    widget.onKey(widget.miniKey, false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _down(),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: Container(
        width: 62,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.miniKey.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
