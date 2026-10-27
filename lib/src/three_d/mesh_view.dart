import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mesh_model.dart';

class MeshPainter extends CustomPainter {
  const MeshPainter({
    required this.mesh,
    this.rotationX = -0.25,
    this.rotationY = 0.45,
    this.zoom = 1,
    this.showTerminals = false,
    this.terminalColor = const Color(0xff00b7ff),
  });

  final DeviceMesh mesh;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final bool showTerminals;
  final Color terminalColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || mesh.vertices.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final transformed = mesh.vertices.map(_rotate).toList(growable: false);
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final vertex in transformed) {
      minX = math.min(minX, vertex.x);
      maxX = math.max(maxX, vertex.x);
      minY = math.min(minY, vertex.y);
      maxY = math.max(maxY, vertex.y);
    }
    final rangeX = math.max(0.5, maxX - minX);
    final rangeY = math.max(0.5, maxY - minY);
    final fit = math.min(size.width / rangeX, size.height / rangeY) * 0.72 * zoom;
    final center = Offset(size.width / 2, size.height / 2);
    Offset project(Vector3D vertex) {
      final perspective = (7 / (7 - vertex.z)).clamp(0.55, 2.0);
      return center +
          Offset(vertex.x * fit * perspective, -vertex.y * fit * perspective);
    }

    final projected = transformed.map(project).toList(growable: false);
    final faces = <_FaceProjection>[];
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
      const light = Vector3D(-0.35, 0.55, 1);
      final brightness = (0.48 + normal.dot(light.normalized).abs() * 0.52)
          .clamp(0.35, 1.0);
      faces.add(
        _FaceProjection(
          points,
          z,
          _shade(Color(face.colorValue), brightness),
        ),
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
          ..strokeWidth = 0.35
          ..color = Colors.black.withValues(alpha: 0.18),
      );
    }

    if (showTerminals) {
      for (final terminal in mesh.terminals) {
        final rotated = _rotate(terminal.position);
        final point = project(rotated);
        canvas.drawCircle(
          point,
          5,
          Paint()..color = terminalColor.withValues(alpha: 0.25),
        );
        canvas.drawCircle(point, 2.6, Paint()..color = terminalColor);
        final text = TextPainter(
          text: TextSpan(
            text: terminal.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              backgroundColor: Color(0xaa07111f),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, point + const Offset(5, -16));
      }
    }
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
      oldDelegate.showTerminals != showTerminals;
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
  });

  final DeviceMesh mesh;
  final bool showTerminals;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: MeshPainter(mesh: mesh, showTerminals: showTerminals),
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
  double _rotationX = -0.25;
  double _rotationY = 0.45;
  double _zoom = 1;

  void _reset() => setState(() {
        _rotationX = -0.25;
        _rotationY = 0.45;
        _zoom = 1;
      });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'مجسم ثلاثي الأبعاد؛ اسحب للتدوير وقرّب بإصبعين',
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleUpdate: (details) {
                setState(() {
                  if ((details.scale - 1).abs() > 0.005) {
                    _zoom = (_zoom * details.scale).clamp(0.55, 3.5).toDouble();
                  }
                  _rotationY += details.focalPointDelta.dx * 0.012;
                  _rotationX = (_rotationX + details.focalPointDelta.dy * 0.012)
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
    );
  }
}
