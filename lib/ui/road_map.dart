// The road as the designs draw it (boards e05, e09, o08, o10, d05): the corridor by chainage, its circles, the sections as pins,
// the van between its stops – drawn from FALCON's own data (the km of each section), the same as the web's src/ui/RoadMap.tsx.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'look.dart';

class MapSection {
  const MapSection(this.id, this.code, this.km, {this.circle});
  final String id, code;
  final double? km;
  final String? circle;
}

class MapCircle {
  const MapCircle(this.code, this.kmFrom, this.kmTo);
  final String code;
  final double? kmFrom, kmTo;
}

const _colors = [Color(0xFF2F7A45), Color(0xFF1E63D6), Color(0xFFC2560E), Color(0xFF7B3FD0), Color(0xFFB07A1E)];

class RoadMap extends StatelessWidget {
  const RoadMap({super.key, required this.sections, this.circles = const [], this.mine, this.van, this.done = const [], this.height = 240, this.dark = false, required this.label});
  final List<MapSection> sections;
  final List<MapCircle> circles;
  final String? mine;
  final double? van;
  final List<String> done;
  final double height;
  final bool dark;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        image: true,
        child: SizedBox(height: height, width: double.infinity, child: ClipRect(child: CustomPaint(painter: _Road(this)))),
      );
}

class _Road extends CustomPainter {
  _Road(this.m);
  final RoadMap m;

  @override
  void paint(Canvas canvas, Size size) {
    final kms = <double>[...m.sections.map((s) => s.km ?? 0), for (final c in m.circles) ...[c.kmFrom ?? 0, c.kmTo ?? 0]];
    final lo = math.min(0.0, kms.isEmpty ? 0.0 : kms.reduce(math.min)), hi = math.max(1.0, kms.isEmpty ? 1.0 : kms.reduce(math.max));
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    // the web draws on 400 × 240 and covers the box ("slice"); the same here
    const w0 = 400.0, h0 = 240.0;
    final scale = math.max(size.width / w0, size.height / h0);
    final dx = (size.width - w0 * scale) / 2, dy = (size.height - h0 * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    double x(double km) => 24 + ((km - lo) / span) * (w0 - 48);
    double y(double km) => h0 / 2 + 46 * math.sin((km - lo) / (span / 3.2));
    Path path(double a, double b) {
      final p = Path();
      for (var i = 0; i <= 40; i++) {
        final k = a + (b - a) * i / 40;
        if (i == 0) { p.moveTo(x(k), y(k)); } else { p.lineTo(x(k), y(k)); }
      }
      return p;
    }

    final bg = m.dark ? C.navy : const Color(0xFFEEF0E6), road = m.dark ? const Color(0xFF33496F) : Colors.white;
    final edge = m.dark ? C.navy3 : const Color(0xFFD9DCCD), ink = m.dark ? Colors.white : C.ink, grid = m.dark ? C.navy2 : const Color(0xFFE3E6D8);
    canvas.drawRect(const Rect.fromLTWH(0, 0, w0, h0), Paint()..color = bg);
    final g = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0.0; i <= w0; i += 20) { canvas.drawLine(Offset(i, 0), Offset(i, h0), g); }
    for (var j = 0.0; j <= h0; j += 20) { canvas.drawLine(Offset(0, j), Offset(w0, j), g); }
    Paint stroke(Color c, double w) => Paint()..color = c..strokeWidth = w..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawPath(path(lo, hi), stroke(edge, 18));
    canvas.drawPath(path(lo, hi), stroke(road, 12));
    for (var i = 0; i < m.circles.length; i++) {
      final c = m.circles[i];
      if (c.kmFrom == null || c.kmTo == null) continue;
      final col = _colors[i % _colors.length];
      canvas.drawPath(path(c.kmFrom!, c.kmTo!), stroke(col.withValues(alpha: 0.55), 4)..strokeCap = StrokeCap.butt);
      final mid = (c.kmFrom! + c.kmTo!) / 2;
      _text(canvas, 'Circle ${c.code}', Offset(x(mid), y(mid) + 34), col, 10, FontWeight.w600);
    }
    for (final s in m.sections) {
      if (s.km == null) continue;
      final on = s.id == m.mine, d = m.done.contains(s.id);
      final o = Offset(x(s.km!), y(s.km!));
      canvas.drawLine(o, o.translate(0, -16), Paint()..color = on ? C.saffron : ink..strokeWidth = 2);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 18, o.dy - 34, 36, 18), const Radius.circular(6)),
          Paint()..color = on ? C.saffron : d ? C.leaf : C.navy);
      _text(canvas, s.code, o.translate(0, -25), Colors.white, 10, FontWeight.w700);
      canvas.drawCircle(o, 4, Paint()..color = on ? C.saffron : ink);
    }
    if (m.van != null) {
      final o = Offset(x(m.van!), y(m.van!));
      canvas.drawCircle(o, 16, Paint()..color = C.saffron.withValues(alpha: 0.25));
      canvas.drawCircle(o, 11, Paint()..color = C.saffron);
      final p = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(o.dx - 6, o.dy - 2, 7, 6), p);
      canvas.drawPath(Path()..moveTo(o.dx + 1, o.dy)..lineTo(o.dx + 4, o.dy)..lineTo(o.dx + 6, o.dy + 2)..lineTo(o.dx + 6, o.dy + 4)..lineTo(o.dx + 1, o.dy + 4)..close(), p);
    }
    canvas.restore();
  }

  void _text(Canvas c, String t, Offset center, Color color, double size, FontWeight w) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: font, fontSize: size, fontWeight: w, color: color)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Road old) => true;
}
