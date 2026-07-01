import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A lightweight animated bar chart drawn with CustomPainter (no deps).
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final int labelEvery;

  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.height = 170,
    this.labelEvery = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
          painter: _BarPainter(
            values: values,
            labels: labels,
            color: color,
            gridColor: cs.outlineVariant.withOpacity(0.5),
            labelColor: cs.onSurface.withOpacity(0.6),
            progress: t,
            labelEvery: labelEvery,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final double progress;
  final int labelEvery;

  _BarPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    required this.progress,
    required this.labelEvery,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final maxV = values.reduce(math.max);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    // Horizontal gridlines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = chartH - (chartH * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final n = values.length;
    final slot = size.width / n;
    final barW = math.min(slot * 0.6, 26.0);

    for (int i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final ratio = values[i] / safeMax;
      final barH = chartH * ratio * progress;
      final isLast = i == n - 1;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, chartH - barH, barW, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLast
              ? [color, color.withOpacity(0.7)]
              : [color.withOpacity(0.75), color.withOpacity(0.35)],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      if (i % labelEvery == 0 && i < labels.length) {
        _text(canvas, labels[i], cx, chartH + 4, size.width);
      }
    }
  }

  void _text(Canvas canvas, String s, double cx, double y, double maxW) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: labelColor, fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (cx - tp.width / 2).clamp(0.0, maxW - tp.width);
    tp.paint(canvas, Offset(dx, y));
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.progress != progress || old.values != values;
}

/// Donut chart with an animated sweep. Overlay a child for the center label.
class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;
  final double thickness;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 150,
    this.thickness = 26,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
          painter: _DonutPainter(
            values: values,
            colors: colors,
            thickness: thickness,
            progress: t,
            emptyColor: cs.outlineVariant.withOpacity(0.4),
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double thickness;
  final double progress;
  final Color emptyColor;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.thickness,
    required this.progress,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final total = values.fold<double>(0, (a, b) => a + b);

    final basePaint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawCircle(center, radius, basePaint);

    if (total <= 0) return;
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.values != values;
}
