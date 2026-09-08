import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 全屏框选裁剪器：显示图片，拖动矩形框选区域，
/// 确认后裁出该区域并替换原背景（保持原图比例，最长边不超过 2000px）。
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  /// 矩形（相对显示区坐标，即 imageViewport 内）
  Rect? _rect;
  Size? _imageSize;
  String? _error;

  // 拖拽状态
  bool _draggingMove = false;
  String _corner = ''; // tl / tr / bl / br
  Offset _dragStart = Offset.zero;
  Rect _rectAtStart = Rect.zero;

  static const double _handle = 26;
  static const double _minSide = 60;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      codec.dispose();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = '图片解码失败');
    }
  }

  /// 计算图片 contain 显示区域（在可用区域内）
  Rect _viewport(Size area) {
    final img = _imageSize!;
    final scale =
        (area.width / img.width) < (area.height / img.height)
            ? area.width / img.width
            : area.height / img.height;
    final w = img.width * scale;
    final h = img.height * scale;
    return Rect.fromLTWH(
      (area.width - w) / 2,
      (area.height - h) / 2,
      w,
      h,
    );
  }

  void _ensureRect(Rect viewport) {
    if (_rect != null) return;
    final w = viewport.width * 0.72;
    final h = viewport.height * 0.72;
    _rect = Rect.fromLTWH(
      viewport.left + (viewport.width - w) / 2,
      viewport.top + (viewport.height - h) / 2,
      w,
      h,
    );
  }

  String _hitCorner(Offset p, Rect r) {
    const tol = 24.0;
    final onTl = (p - r.topLeft).distance <= tol;
    final onTr = (p - r.topRight).distance <= tol;
    final onBl = (p - r.bottomLeft).distance <= tol;
    final onBr = (p - r.bottomRight).distance <= tol;
    if (onTl) return 'tl';
    if (onTr) return 'tr';
    if (onBl) return 'bl';
    if (onBr) return 'br';
    return '';
  }

  void _onPanStart(Offset p, Rect viewport) {
    if (_rect == null) return;
    final r = _rect!;
    final corner = _hitCorner(p, r);
    if (corner.isNotEmpty) {
      _corner = corner;
      _draggingMove = false;
    } else if (r.contains(p)) {
      _draggingMove = true;
      _corner = '';
    } else {
      return;
    }
    _dragStart = p;
    _rectAtStart = r;
  }

  void _onPanUpdate(Offset p, Rect viewport) {
    if (_rect == null) return;
    if (_draggingMove) {
      var dx = p.dx - _dragStart.dx;
      var dy = p.dy - _dragStart.dy;
      var left = (_rectAtStart.left + dx)
          .clamp(viewport.left, viewport.right - _rectAtStart.width)
          .toDouble();
      var top = (_rectAtStart.top + dy)
          .clamp(viewport.top, viewport.bottom - _rectAtStart.height)
          .toDouble();
      setState(() {
        _rect = Rect.fromLTWH(
            left, top, _rectAtStart.width, _rectAtStart.height);
      });
      return;
    }
    if (_corner.isEmpty) return;
    final r = _rect!;
    final dx = p.dx - _dragStart.dx;
    final dy = p.dy - _dragStart.dy;
    var l = r.left, t = r.top, rr = r.right, b = r.bottom;
    if (_corner.contains('l')) {
      l = (_rectAtStart.left + dx)
          .clamp(viewport.left, _rectAtStart.right - _minSide)
          .toDouble();
    }
    if (_corner.contains('r')) {
      rr = (_rectAtStart.right + dx)
          .clamp(_rectAtStart.left + _minSide, viewport.right)
          .toDouble();
    }
    if (_corner.contains('t')) {
      t = (_rectAtStart.top + dy)
          .clamp(viewport.top, _rectAtStart.bottom - _minSide)
          .toDouble();
    }
    if (_corner.contains('b')) {
      b = (_rectAtStart.bottom + dy)
          .clamp(_rectAtStart.top + _minSide, viewport.bottom)
          .toDouble();
    }
    setState(() => _rect = Rect.fromLTRB(l, t, rr, b));
  }

  Future<void> _save(Rect viewport) async {
    final imgSize = _imageSize;
    final rect = _rect;
    if (imgSize == null || rect == null) return;

    // 归一化到图片像素
    final norm = Rect.fromLTRB(
      (rect.left - viewport.left) / viewport.width,
      (rect.top - viewport.top) / viewport.height,
      (rect.right - viewport.left) / viewport.width,
      (rect.bottom - viewport.top) / viewport.height,
    );
    final src = Rect.fromLTRB(
      norm.left * imgSize.width,
      norm.top * imgSize.height,
      norm.right * imgSize.width,
      norm.bottom * imgSize.height,
    );

    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      // 输出尺寸：最长边不超过 2000px
      final outW = src.width.round();
      final outH = src.height.round();
      final maxSide = outW > outH ? outW : outH;
      var scale = 1.0;
      if (maxSide > 2000) scale = 2000.0 / maxSide;
      final w = (outW * scale).round().clamp(16, 2000);
      final h = (outH * scale).round().clamp(16, 2000);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        img,
        src,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(w, h);
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      cropped.dispose();
      img.dispose();
      codec.dispose();

      if (data == null) {
        if (mounted) setState(() => _error = '裁剪失败');
        return;
      }
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}${Platform.pathSeparator}crop_${DateTime.now().millisecondsSinceEpoch}.png');
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(out.path);
    } catch (_) {
      if (mounted) setState(() => _error = '裁剪失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('框选背景区域'),
        actions: [
          TextButton(
            onPressed: () {
              final vp = _viewport(MediaQuery.of(context).size);
              _save(vp);
            },
            child: const Text('完成',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(_error!,
                  style: const TextStyle(color: Colors.white70)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final area = Size(
                    constraints.maxWidth, constraints.maxHeight);
                final vp = _viewport(area);
                _ensureRect(vp);
                return GestureDetector(
                  onPanStart: (d) => _onPanStart(d.localPosition, vp),
                  onPanUpdate: (d) => _onPanUpdate(d.localPosition, vp),
                  onPanEnd: (_) {
                    _draggingMove = false;
                    _corner = '';
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      // 半透明遮罩（框外压暗）
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CropMaskPainter(_rect ?? vp),
                        ),
                      ),
                      // 顶部操作提示
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Text(
                            '拖动四角调整区域，拖动内部移动位置',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // 框线 + 四角把手
                      if (_rect != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CropRectPainter(
                              _rect!,
                              viewport: vp,
                              handle: _handle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// 框外压暗遮罩
class _CropMaskPainter extends CustomPainter {
  _CropMaskPainter(this.rect);
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(_CropMaskPainter old) => old.rect != rect;
}

/// 框线与四角把手
class _CropRectPainter extends CustomPainter {
  _CropRectPainter(this.rect, {required this.viewport, required this.handle});
  final Rect rect;
  final Rect viewport;
  final double handle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, paint);

    final fill = Paint()..color = Colors.white;
    final corners = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];
    for (final c in corners) {
      canvas.drawCircle(c, 6, fill);
      canvas.drawCircle(c, 9, Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_CropRectPainter old) =>
      old.rect != rect || old.viewport != viewport;
}
