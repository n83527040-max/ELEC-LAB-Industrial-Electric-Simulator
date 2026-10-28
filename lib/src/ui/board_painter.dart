import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/board_geometry.dart';
import '../models/din_geometry.dart';
import '../models/geometry.dart';
import '../models/project.dart';
import '../models/supply_bay.dart';
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
    this.industrialSurface = true,
  });

  final ElectricalProject project;
  final bool showGrid;
  final double gridSize;
  final Set<String> visibleLayers;
  final SimulationResult? result;
  final String? selectedWireId;
  final bool industrialSurface;

  @override
  void paint(Canvas canvas, Size size) {
    if (industrialSurface) {
      _paintEnclosure(canvas, size);
      _paintMountingHoles(canvas, size);
      for (final rail in DinGeometry.railCenters) {
        _paintDinRail(canvas, size, rail);
      }
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xffdce3e8),
      );
    }
    if (project.components.any(SupplyBay.isFixed)) {
      _paintSupplyBay(canvas, size);
    }
    if (showGrid) _paintGrid(canvas, size);
    for (final wire in project.wires) {
      if (!visibleLayers.contains(wire.layerId)) continue;
      _paintWire(canvas, wire, wire.id == selectedWireId);
    }
    if (industrialSurface) _paintCorners(canvas, size);
  }

  void _paintEnclosure(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff27343e),
    );
    final plate = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    final gradient = ui.Gradient.linear(
      plate.topLeft,
      plate.bottomRight,
      const <Color>[
        Color(0xffe1e6e9),
        Color(0xffaab5be),
        Color(0xffd5dce0),
      ],
      const <double>[0, 0.52, 1],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(8)),
      Paint()..shader = gradient,
    );
    final brushed = Paint()..color = Colors.white.withValues(alpha: 0.055);
    for (var y = 24.0; y < size.height - 20; y += 13) {
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), brushed);
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xff667682);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(8)),
      edge,
    );
  }

  void _paintMountingHoles(Canvas canvas, Size size) {
    final hole = Paint()..color = const Color(0xff596873);
    final rim = Paint()..color = Colors.white.withValues(alpha: 0.34);
    const step = 44.0;
    for (var y = 246.0; y < size.height - 28; y += step) {
      for (var x = 40.0; x < size.width - 28; x += step) {
        final rect =
            Rect.fromCenter(center: Offset(x, y), width: 3.6, height: 5.2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.shift(const Offset(-0.7, -0.7)), const Radius.circular(0.8)),
          rim,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(0.8)),
          hole,
        );
      }
    }
  }

  void _paintDinRail(Canvas canvas, Size size, double centerY) {
    final left = 48.0;
    final right = size.width - 48;
    if (right <= left || centerY + 20 >= size.height) return;
    final shadow = Rect.fromLTWH(left + 2, centerY - 10, right - left, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadow, const Radius.circular(3)),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    final rail = Rect.fromLTWH(left, centerY - 13, right - left, 26);
    canvas.drawRect(
      rail,
      Paint()
        ..shader = ui.Gradient.linear(
          rail.topCenter,
          rail.bottomCenter,
          const <Color>[
            Color(0xff79868f),
            Color(0xffe6eaec),
            Color(0xff8b979f),
          ],
          const <double>[0, 0.5, 1],
        ),
    );
    final lip = Paint()..color = const Color(0xff59666f);
    canvas.drawRect(Rect.fromLTWH(left, centerY - 13, right - left, 3), lip);
    canvas.drawRect(Rect.fromLTWH(left, centerY + 10, right - left, 3), lip);
    final slot = Paint()..color = const Color(0xff4b5962);
    for (var x = left + 24; x < right - 18; x += 42) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, centerY), width: 20, height: 5),
          const Radius.circular(2.5),
        ),
        slot,
      );
    }
    for (final x in <double>[left - 12, right + 12]) {
      final bracket =
          Rect.fromCenter(center: Offset(x, centerY), width: 15, height: 42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bracket, const Radius.circular(3)),
        Paint()..color = const Color(0xff87949d),
      );
      for (final dy in <double>[-12.0, 12.0]) {
        _paintScrew(canvas, Offset(x, centerY + dy), 3.5);
      }
    }
  }

  void _paintSupplyBay(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(28, 28, size.width - 56, 178);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = const Color(0xd9122736),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xff3a9fc4),
    );
    final painter = TextPainter(
      text: const TextSpan(
        text: 'ALIMENTATION  •  3~  L1 L2 L3 N PE   |   1~   |   DC',
        style: TextStyle(
          color: Color(0xffb9e9fa),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 80);
    painter.paint(canvas, const Offset(44, 36));
  }

  void _paintGrid(Canvas canvas, Size size) {
    final step = gridSize.clamp(10, 100).toDouble();
    if (industrialSurface) {
      final grid = Paint()
        ..strokeWidth = 0.45
        ..color = const Color(0xff17384a).withValues(alpha: 0.08);
      for (var x = step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 220), Offset(x, size.height), grid);
      }
      for (var y = 220 + step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
      return;
    }
    final dot = Paint()
      ..color = const Color(0xff8797a3).withValues(alpha: 0.55);
    for (var y = step; y < size.height; y += step) {
      for (var x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
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
            canvas.drawCircle(
                tangent.position, 1.7, glow..style = PaintingStyle.fill);
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
    for (final offset in <Offset>[
      const Offset(16, 16),
      Offset(size.width - 16, 16),
      Offset(16, size.height - 16),
      Offset(size.width - 16, size.height - 16),
    ]) {
      _paintScrew(canvas, offset, 8);
    }
  }

  void _paintScrew(Canvas canvas, Offset offset, double radius) {
    canvas.drawCircle(offset, radius, Paint()..color = const Color(0xff596673));
    canvas.drawCircle(
      offset - Offset(radius * 0.16, radius * 0.16),
      radius * 0.72,
      Paint()..color = const Color(0xffb9c2c8),
    );
    final slot = Paint()
      ..strokeWidth = math.max(1, radius * 0.22)
      ..color = const Color(0xff29333d);
    canvas.drawLine(
      offset - Offset(radius * 0.45, 0),
      offset + Offset(radius * 0.45, 0),
      slot,
    );
    canvas.drawLine(
      offset - Offset(0, radius * 0.45),
      offset + Offset(0, radius * 0.45),
      slot,
    );
  }

  static double distanceToWire(
    ElectricalProject project,
    CircuitWire wire,
    BoardPoint point,
  ) {
    final points = WireRouter.route(project, wire);
    var minimum = double.infinity;
    for (var index = 0; index < points.length - 1; index++) {
      minimum = math.min(
          minimum, _distanceToSegment(point, points[index], points[index + 1]));
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
    final t =
        (((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy))
            .clamp(0.0, 1.0);
    return point.distanceTo(BoardPoint(a.x + t * dx, a.y + t * dy));
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}
