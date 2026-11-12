// Канва маршрута: линия трека по GPS-точкам без тайловой карты.
// Используется на экране трекинга, в результате заплыва и в карточке
// маршрута — там, где важна форма трека, а не подложка.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/api_models.dart';

class RouteCanvas extends StatelessWidget {
  const RouteCanvas({
    super.key,
    required this.points,
    this.current,
    this.dark = false,
    this.strokeWidth = 5,
  });

  final List<GpsPoint> points;
  final GpsPoint? current;
  final bool dark;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: RoutePainter(
          points: points,
          current: current,
          dark: dark,
          strokeWidth: strokeWidth,
        ),
        size: Size.infinite,
      );
}

class RoutePainter extends CustomPainter {
  const RoutePainter({
    required this.points,
    this.current,
    this.dark = false,
    this.strokeWidth = 5,
  });

  final List<GpsPoint> points;
  final GpsPoint? current;
  final bool dark;
  final double strokeWidth;

  static const double _padding = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: .06)
          : const Color(0xFFEAF3F1);
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF9FB8B2))
          .withValues(alpha: .12)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    if (points.length < 2) {
      final hint = TextPainter(
        text: TextSpan(
          text: points.isEmpty
              ? 'Ожидаем сигнал GPS'
              : 'Первая точка получена',
          style: TextStyle(
            color: dark ? Colors.white54 : const Color(0xFF7C918C),
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hint.paint(
        canvas,
        Offset((size.width - hint.width) / 2, size.height / 2 - 8),
      );
      return;
    }

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final latSpan = math.max(maxLat - minLat, 1e-6);
    final lngSpan = math.max(maxLng - minLng, 1e-6);

    final usableWidth = size.width - _padding * 2;
    final usableHeight = size.height - _padding * 2;
    final scale = math.min(usableWidth / lngSpan, usableHeight / latSpan);
    final drawnWidth = lngSpan * scale;
    final drawnHeight = latSpan * scale;
    final offsetX = _padding + (usableWidth - drawnWidth) / 2;
    final offsetY = _padding + (usableHeight - drawnHeight) / 2;

    Offset project(GpsPoint p) => Offset(
          offsetX + (p.lng - minLng) * scale,
          // Широта растёт вверх, а координаты Canvas — вниз.
          offsetY + (maxLat - p.lat) * scale,
        );

    final start = project(points.first);
    final path = Path()..moveTo(start.dx, start.dy);
    for (final p in points.skip(1)) {
      final next = project(p);
      path.lineTo(next.dx, next.dy);
    }

    if (points.length > 1) {
      final glow = Paint()
        ..color = const Color(0xFF00A6A6).withValues(alpha: .28)
        ..strokeWidth = strokeWidth + 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glow);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = dark ? const Color(0xFF4FD1D1) : const Color(0xFF007F86)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      project(points.first),
      7,
      Paint()..color = const Color(0xFF4CAF50),
    );
    final last = current ?? points.last;
    canvas
      ..drawCircle(project(last), 11,
          Paint()..color = const Color(0xFFFF7A45).withValues(alpha: .35))
      ..drawCircle(project(last), 6.5, Paint()..color = const Color(0xFFFF7A45));
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.points.length != points.length || old.current != current;
}
