import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Custom painter for the n-gon "growth shape".
///
/// Renders concentric reference rings, axis spokes, axis labels and the
/// filled current-state polygon. Strict black-and-white: the polygon is
/// drawn with a [Color] passed in by the caller (resolves to fg/bg of the
/// active theme — no gradients).
class PentagonPainter extends CustomPainter {
  PentagonPainter({
    required this.scores,
    required this.fg,
    required this.muted,
    required this.line,
    required this.bg,
  });

  final List<AxisScore> scores;
  final Color fg;
  final Color muted;
  final Color line;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final n = scores.length;
    if (n < 3) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 36;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 1;
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 1;
    final shapeStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = fg
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final shapeFill = Paint()
      ..style = PaintingStyle.fill
      ..color = fg.withOpacity(0.18);
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fg;

    // concentric reference rings
    for (var k = 1; k <= 4; k++) {
      final r = radius * k / 4;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = _vertex(center, r, i, n);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    // spokes
    for (var i = 0; i < n; i++) {
      final p = _vertex(center, radius, i, n);
      canvas.drawLine(center, p, spokePaint);
    }

    // current state polygon
    final shape = Path();
    for (var i = 0; i < n; i++) {
      final s = scores[i].value.clamp(0.0, 100.0) / 100.0;
      final r = radius * s;
      final p = _vertex(center, r, i, n);
      if (i == 0) {
        shape.moveTo(p.dx, p.dy);
      } else {
        shape.lineTo(p.dx, p.dy);
      }
    }
    shape.close();
    canvas.drawPath(shape, shapeFill);
    canvas.drawPath(shape, shapeStroke);

    // dots at the polygon vertices
    for (var i = 0; i < n; i++) {
      final s = scores[i].value.clamp(0.0, 100.0) / 100.0;
      final r = radius * s;
      final p = _vertex(center, r, i, n);
      canvas.drawCircle(p, 3.5, dotPaint);
    }

    // axis labels
    for (var i = 0; i < n; i++) {
      final p = _vertex(center, radius + 18, i, n);
      final tp = TextPainter(
        text: TextSpan(
          text: scores[i].axis.symbol,
          style: TextStyle(
            color: fg,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Vertex coordinate; vertex 0 sits at the top of the shape.
  Offset _vertex(Offset center, double r, int i, int n) {
    final angle = -math.pi / 2 + 2 * math.pi * i / n;
    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  }

  @override
  bool shouldRepaint(covariant PentagonPainter oldDelegate) =>
      oldDelegate.scores != scores ||
      oldDelegate.fg != fg ||
      oldDelegate.muted != muted ||
      oldDelegate.line != line ||
      oldDelegate.bg != bg;
}
