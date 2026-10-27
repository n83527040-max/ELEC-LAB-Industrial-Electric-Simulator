import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/board_geometry.dart';
import '../models/geometry.dart';
import '../models/project.dart';
import '../models/wire.dart';
import '../simulation/simulation_result.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({
    required this.project,
    required this.showGrid,
    required this.gridSize,
    required this.visibleLayers,
    this.result,
    this.selectedWireId,
  });

  final ElectricalProject project;
  final bool showGrid;
  final double gridSize;
  final Set<String> visibleLayers;
  final SimulationResult? result;
  final String? selectedWireId;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xffbcc4cc);
    canvas.drawRect(Offset.zero & size, background);
    _paintMetal(canvas, size);
    if (showGrid) _paintGrid(canvas, size);
    for (final wire in project.wires) {
      if (!visibleLayers.contains(wire.layerId)) continue;
      _paintWire(canvas, wire, wire.id == selectedWireId);
    }
    _paintCorners(canvas, size);
  }

  void _paintMetal(Canvas canvas, Size size) {
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      const <Color>[Color(0xffe2e6e9), Color(0xffaeb8c2), Color(0xffd8dde1)],
      const <double>[0, 0.55, 1],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = gradient);
    final noise = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var y = 7.0; y < size.height; y += 19) {
      for (var x = 11.0; x < size.width; x += 23) {
        canvas.drawCircle(Offset(x, y), 0.65, noise);
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final hole = Paint()..color = const Color(0xff68737d);
    final rim = Paint()..color = Colors.white.withValues(alpha: 0.42);
    final step = gridSize.clamp(10, 100).toDouble();
    for (var y = step; y < size.height; y += step) {
      for (var x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x - 0.6, y - 0.6), 1.65, rim);
        canvas.drawCircle(Offset(x, y), 1.35, hole);
      }
    }
  }

  void _paintWire(Canvas canvas, CircuitWire wire, bool selected) {
    final points = WireRouter.route(project, wire);
    if (points.length < 2) return;
    final path = _path(points, wire.routeStyle == WireRouteStyle.curved);
    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.32),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Color(wire.colorValue),
    );
    final current = result?.wireCurrents[wire.id] ?? 0;
    if (current > 0.00001) {
      final time = result?.time ?? 0;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff8be9ff);
      for (final metric in path.computeMetrics()) {
        var distance = (time * 85) % 28;
        while (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            canvas.drawCircle(tangent.position, 1.7, glow..style = PaintingStyle.fill);
          }
          distance += 28;
        }
      }
    }
    if (selected) {
      final middle = points[points.length ~/ 2];
      _paintLabel(
        canvas,
        middle,
        '${wire.crossSectionMm2.toStringAsFixed(1)} mm²',
      );
    }
  }

  Path _path(List<BoardPoint> points, bool curved) {
    final path = Path()..moveTo(points.first.x, points.first.y);
    if (!curved || points.length == 2) {
      for (final point in points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      return path;
    }
    for (var index = 1; index < points.length - 1; index++) {
      final control = points[index];
      final end = points[index + 1];
      path.quadraticBezierTo(control.x, control.y, end.x, end.y);
    }
    return path;
  }

  void _paintLabel(Canvas canvas, BoardPoint point, String value) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Color(0xdd101b29),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(point.x + 5, point.y - 18));
  }

  void _paintCorners(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff596673);
    for (final offset in <Offset>[
      const Offset(16, 16),
      Offset(size.width - 16, 16),
      Offset(16, size.height - 16),
      Offset(size.width - 16, size.height - 16),
    ]) {
      canvas.drawCircle(offset, 8, paint);
      canvas.drawCircle(offset, 3, Paint()..color = const Color(0xff29333d));
    }
  }

  static double distanceToWire(
    ElectricalProject project,
    CircuitWire wire,
    BoardPoint point,
  ) {
    final points = WireRouter.route(project, wire);
    var minimum = double.infinity;
    for (var index = 0; index < points.length - 1; index++) {
      minimum = math.min(minimum, _distanceToSegment(point, points[index], points[index + 1]));
    }
    return minimum;
  }

  static double _distanceToSegment(
    BoardPoint point,
    BoardPoint a,
    BoardPoint b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    if (dx == 0 && dy == 0) return point.distanceTo(a);
    final t = (((point.x - a.x) * dx + (point.y - a.y) * dy) /
            (dx * dx + dy * dy))
        .clamp(0.0, 1.0);
    return point.distanceTo(BoardPoint(a.x + t * dx, a.y + t * dy));
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}
