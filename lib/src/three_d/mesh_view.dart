import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mesh_model.dart';

class MeshPainter extends CustomPainter {
  const MeshPainter({
    required this.mesh,
    this.rotationX = -0.22,
    this.rotationY = 0.38,
    this.zoom = 1,
    this.showTerminals = false,
    this.terminalColor = const Color(0xff00b7ff),
    this.fixedScale,
    this.fitPadding = 0.8,
    this.showShadow = false,
  });

  final DeviceMesh mesh;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final bool showTerminals;
  final Color terminalColor;

  /// Used by the board. With zero rotation, one model unit is exactly 48 board
  /// logical pixels, so mesh terminals and catalog hit targets coincide.
  final double? fixedScale;
  final double fitPadding;
  final bool showShadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || mesh.vertices.isEmpty) return;
    if (fixedScale == null) canvas.clipRect(Offset.zero & size);
    final transformed = mesh.vertices.map(_rotate).toList(growable: false);
    final transformedTerminals = mesh.terminals
        .map((terminal) => _rotate(terminal.position))
        .toList(growable: false);
    final isFixed = fixedScale != null;
    final units = transformed
        .map((vertex) => _perspectiveUnit(vertex, isFixed))
        .toList(growable: false);
    final terminalUnits = transformedTerminals
        .map((vertex) => _perspectiveUnit(vertex, isFixed))
        .toList(growable: false);

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    void include(Vector3D vertex) {
      minX = math.min(minX, vertex.x);
      maxX = math.max(maxX, vertex.x);
      minY = math.min(minY, vertex.y);
      maxY = math.max(maxY, vertex.y);
    }

    for (final vertex in units) {
      include(vertex);
    }
    if (showTerminals) {
      for (final vertex in terminalUnits) {
        include(vertex);
      }
    }
    final rangeX = math.max(0.001, maxX - minX);
    final rangeY = math.max(0.001, maxY - minY);
    final fit = isFixed
        ? fixedScale! * zoom
        : math.min(size.width / rangeX, size.height / rangeY) *
            fitPadding *
            zoom;
    final modelCenterX = isFixed ? 0.0 : (minX + maxX) / 2;
    final modelCenterY = isFixed ? 0.0 : (minY + maxY) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    Offset project(Vector3D vertex) =>
        center +
        Offset(
          (vertex.x - modelCenterX) * fit,
          -(vertex.y - modelCenterY) * fit,
        );

    if (showShadow) {
      final shadowRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.86),
        width: size.width * 0.58,
        height: math.max(8, size.height * 0.07),
      );
      canvas.drawOval(
        shadowRect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    final projected = units.map(project).toList(growable: false);
    final faces = <_FaceProjection>[];
    const light = Vector3D(-0.42, 0.62, 1);
    const rim = Vector3D(0.65, -0.2, 0.5);
    for (final face in mesh.faces) {
      if (face.indices.length < 3) continue;
      final points = face.indices.map((index) => projected[index]).toList();
      final z = face.indices
              .map((index) => transformed[index].z)
              .fold<double>(0, (sum, value) => sum + value) /
          face.indices.length;
      final a = transformed[face.indices[0]];
      final b = transformed[face.indices[1]];
      final c = transformed[face.indices[2]];
      final normal = (b - a).cross(c - a).normalized;
      final diffuse = normal.dot(light.normalized).abs();
      final edgeLight = math.max(0, normal.dot(rim.normalized));
      final brightness =
          (0.36 + diffuse * 0.58 + edgeLight * 0.1).clamp(0.32, 1.0);
      faces.add(
        _FaceProjection(points, z, _shade(Color(face.colorValue), brightness)),
      );
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      final path = Path()..moveTo(face.points.first.dx, face.points.first.dy);
      for (final point in face.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = face.color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.22
          ..color = Colors.black.withValues(alpha: 0.055),
      );
    }

    if (showTerminals) {
      for (var index = 0; index < mesh.terminals.length; index++) {
        final terminal = mesh.terminals[index];
        final point = project(terminalUnits[index]);
        canvas.drawCircle(
          point,
          6,
          Paint()..color = terminalColor.withValues(alpha: 0.25),
        );
        canvas.drawCircle(point, 3, Paint()..color = terminalColor);
        canvas.drawCircle(
          point,
          1.2,
          Paint()..color = Colors.white,
        );
        final text = TextPainter(
          text: TextSpan(
            text: terminal.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              backgroundColor: Color(0xdd07111f),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = (point.dx + 7)
            .clamp(2.0, math.max(2.0, size.width - text.width - 2));
        final dy = (point.dy - 17)
            .clamp(2.0, math.max(2.0, size.height - text.height - 2));
        text.paint(canvas, Offset(dx.toDouble(), dy.toDouble()));
      }
    }
  }

  Vector3D _perspectiveUnit(Vector3D vertex, bool orthographic) {
    if (orthographic) return vertex;
    final perspective = (7 / (7 - vertex.z)).clamp(0.55, 2.0);
    return Vector3D(vertex.x * perspective, vertex.y * perspective, vertex.z);
  }

  Vector3D _rotate(Vector3D point) {
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final y1 = point.y * cosX - point.z * sinX;
    final z1 = point.y * sinX + point.z * cosX;
    final x2 = point.x * cosY + z1 * sinY;
    final z2 = -point.x * sinY + z1 * cosY;
    return Vector3D(x2, y1, z2);
  }

  Color _shade(Color color, double brightness) {
    return Color.fromARGB(
      (color.a * 255).round().clamp(0, 255).toInt(),
      (color.r * brightness * 255).round().clamp(0, 255).toInt(),
      (color.g * brightness * 255).round().clamp(0, 255).toInt(),
      (color.b * brightness * 255).round().clamp(0, 255).toInt(),
    );
  }

  @override
  bool shouldRepaint(MeshPainter oldDelegate) =>
      oldDelegate.mesh != mesh ||
      oldDelegate.rotationX != rotationX ||
      oldDelegate.rotationY != rotationY ||
      oldDelegate.zoom != zoom ||
      oldDelegate.showTerminals != showTerminals ||
      oldDelegate.terminalColor != terminalColor ||
      oldDelegate.fixedScale != fixedScale ||
      oldDelegate.fitPadding != fitPadding ||
      oldDelegate.showShadow != showShadow;
}

class _FaceProjection {
  const _FaceProjection(this.points, this.depth, this.color);

  final List<Offset> points;
  final double depth;
  final Color color;
}

class DeviceMeshView extends StatelessWidget {
  const DeviceMeshView({
    required this.mesh,
    super.key,
    this.showTerminals = false,
    this.fixedScale,
    this.fitPadding = 0.8,
    this.showShadow = false,
  });

  final DeviceMesh mesh;
  final bool showTerminals;
  final double? fixedScale;
  final double fitPadding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: MeshPainter(
          mesh: mesh,
          rotationX: fixedScale == null ? -0.22 : 0,
          rotationY: fixedScale == null ? 0.38 : 0,
          showTerminals: showTerminals,
          fixedScale: fixedScale,
          fitPadding: fitPadding,
          showShadow: showShadow,
        ),
        size: Size.infinite,
      );
}

class InteractiveMeshViewer extends StatefulWidget {
  const InteractiveMeshViewer({required this.mesh, super.key});

  final DeviceMesh mesh;

  @override
  State<InteractiveMeshViewer> createState() => _InteractiveMeshViewerState();
}

class _InteractiveMeshViewerState extends State<InteractiveMeshViewer> {
  double _rotationX = -0.22;
  double _rotationY = 0.38;
  double _zoom = 1;

  void _reset() => setState(() {
        _rotationX = -0.22;
        _rotationY = 0.38;
        _zoom = 1;
      });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'مجسم ثلاثي الأبعاد؛ اسحب للتدوير وقرّب بإصبعين',
      child: ColoredBox(
        color: const Color(0xff111c26),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleUpdate: (details) {
                  setState(() {
                    if ((details.scale - 1).abs() > 0.005) {
                      _zoom =
                          (_zoom * details.scale).clamp(0.55, 3.5).toDouble();
                    }
                    _rotationY += details.focalPointDelta.dx * 0.012;
                    _rotationX =
                        (_rotationX + details.focalPointDelta.dy * 0.012)
                            .clamp(-1.4, 1.4)
                            .toDouble();
                  });
                },
                onDoubleTap: _reset,
                child: CustomPaint(
                  painter: MeshPainter(
                    mesh: widget.mesh,
                    rotationX: _rotationX,
                    rotationY: _rotationY,
                    zoom: _zoom,
                    showTerminals: true,
                    fitPadding: 0.68,
                    showShadow: true,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filledTonal(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
                tooltip: 'إعادة وضع المجسم',
              ),
            ),
            const Positioned(
              bottom: 8,
              right: 12,
              child: Text(
                'اسحب للتدوير • إصبعان للتكبير',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
