import 'dart:math';
import 'package:flutter/material.dart';

/// Barra de progreso en forma de onda (tocar o arrastrar para saltar).
class WaveSeekBar extends StatefulWidget {
  final double progress; // 0..1
  final String seed;
  final ValueChanged<double> onSeek;
  const WaveSeekBar(
      {super.key,
      required this.progress,
      required this.seed,
      required this.onSeek});
  @override
  State<WaveSeekBar> createState() => _WaveSeekBarState();
}

class _WaveSeekBarState extends State<WaveSeekBar> {
  double? _drag;
  late List<double> _bars = _makeBars(widget.seed);

  @override
  void didUpdateWidget(covariant WaveSeekBar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed) _bars = _makeBars(widget.seed);
  }

  static List<double> _makeBars(String seed) {
    var h = 17;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final r = Random(h);
    var prev = .5;
    final out = <double>[];
    for (var i = 0; i < 64; i++) {
      prev = (prev * 0.55 + r.nextDouble() * 0.45).clamp(0.15, 1.0).toDouble();
      out.add(prev);
    }
    return out;
  }

  double _frac(double dx, double w) => (dx / w).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => widget.onSeek(_frac(d.localPosition.dx, w)),
        onHorizontalDragStart: (d) =>
            setState(() => _drag = _frac(d.localPosition.dx, w)),
        onHorizontalDragUpdate: (d) =>
            setState(() => _drag = _frac(d.localPosition.dx, w)),
        onHorizontalDragEnd: (_) {
          final f = _drag;
          setState(() => _drag = null);
          if (f != null) widget.onSeek(f);
        },
        onHorizontalDragCancel: () => setState(() => _drag = null),
        child: SizedBox(
          height: 56,
          width: w,
          child: CustomPaint(
            painter: _WavePainter(_bars, _drag ?? widget.progress, cs.primary,
                cs.onSurfaceVariant.withAlpha(90)),
          ),
        ),
      );
    });
  }
}

class _WavePainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color on, off;
  _WavePainter(this.bars, this.progress, this.on, this.off);

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    final slot = size.width / n;
    final bw = slot * 0.6;
    for (var i = 0; i < n; i++) {
      final x = i * slot + (slot - bw) / 2;
      final h = size.height * bars[i];
      final top = (size.height - h) / 2;
      final played = (i + 0.5) / n <= progress;
      final paint = Paint()..color = played ? on : off;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top, bw, h), Radius.circular(bw / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter o) =>
      o.progress != progress || o.bars != bars || o.on != on || o.off != off;
}
