import 'dart:math' as math;

class Vector3D {
  const Vector3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vector3D operator +(Vector3D other) =>
      Vector3D(x + other.x, y + other.y, z + other.z);

  Vector3D operator -(Vector3D other) =>
      Vector3D(x - other.x, y - other.y, z - other.z);

  Vector3D operator *(double factor) =>
      Vector3D(x * factor, y * factor, z * factor);

  double dot(Vector3D other) =>
      x * other.x + y * other.y + z * other.z;

  Vector3D cross(Vector3D other) => Vector3D(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D get normalized {
    final value = length;
    return value < 1e-9 ? this : this * (1 / value);
  }
}

class MeshFace {
  const MeshFace(this.indices, this.colorValue);

  final List<int> indices;
  final int colorValue;
}

class MeshTerminal {
  const MeshTerminal({
    required this.id,
    required this.label,
    required this.position,
  });

  final String id;
  final String label;
  final Vector3D position;
}

/// Original polygon geometry consumed by the local software renderer. No flat
/// screenshots or manufacturer models are used.
class DeviceMesh {
  const DeviceMesh({
    required this.vertices,
    required this.faces,
    required this.terminals,
  });

  final List<Vector3D> vertices;
  final List<MeshFace> faces;
  final List<MeshTerminal> terminals;
}

enum MeshAxis { x, y, z }

class MeshBuilder {
  final List<Vector3D> vertices = <Vector3D>[];
  final List<MeshFace> faces = <MeshFace>[];

  void addBox(
    Vector3D center,
    Vector3D size,
    int color, {
    double angleZ = 0,
  }) {
    final x = size.x / 2;
    final y = size.y / 2;
    final z = size.z / 2;
    final offset = vertices.length;
    final cos = math.cos(angleZ);
    final sin = math.sin(angleZ);
    Vector3D point(double px, double py, double pz) => center +
        Vector3D(px * cos - py * sin, px * sin + py * cos, pz);
    vertices.addAll(<Vector3D>[
      point(-x, -y, -z),
      point(x, -y, -z),
      point(x, y, -z),
      point(-x, y, -z),
      point(-x, -y, z),
      point(x, -y, z),
      point(x, y, z),
      point(-x, y, z),
    ]);
    const indices = <List<int>>[
      <int>[0, 3, 2, 1],
      <int>[4, 5, 6, 7],
      <int>[0, 4, 7, 3],
      <int>[1, 2, 6, 5],
      <int>[0, 1, 5, 4],
      <int>[3, 7, 6, 2],
    ];
    for (final face in indices) {
      _addFace(face, offset, color);
    }
  }

  /// Extruded eight-corner enclosure. Chamfers make DIN-rail equipment read as
  /// manufactured housings instead of plain cubes while staying cheap to draw.
  void addBeveledBox(
    Vector3D center,
    Vector3D size,
    int color, {
    double bevel = 0.08,
  }) {
    final x = size.x / 2;
    final y = size.y / 2;
    final z = size.z / 2;
    final cut = math.min(math.min(x, y) * 0.45, bevel);
    final outline = <Vector3D>[
      Vector3D(-x + cut, -y, 0),
      Vector3D(x - cut, -y, 0),
      Vector3D(x, -y + cut, 0),
      Vector3D(x, y - cut, 0),
      Vector3D(x - cut, y, 0),
      Vector3D(-x + cut, y, 0),
      Vector3D(-x, y - cut, 0),
      Vector3D(-x, -y + cut, 0),
    ];
    final offset = vertices.length;
    for (final depth in <double>[-z, z]) {
      for (final point in outline) {
        vertices.add(center + Vector3D(point.x, point.y, depth));
      }
    }
    for (var index = 0; index < 8; index++) {
      final next = (index + 1) % 8;
      _addFace(<int>[index, next, 8 + next, 8 + index], offset, color);
    }
    _addFace(List<int>.generate(8, (index) => 7 - index), offset, color);
    _addFace(List<int>.generate(8, (index) => 8 + index), offset, color);
  }

  void addCylinder(
    Vector3D center,
    double radius,
    double depth,
    int color, {
    MeshAxis axis = MeshAxis.z,
    int segments = 16,
  }) {
    addFrustum(
      center,
      radius,
      radius,
      depth,
      color,
      axis: axis,
      segments: segments,
    );
  }

  void addFrustum(
    Vector3D center,
    double radiusBottom,
    double radiusTop,
    double depth,
    int color, {
    MeshAxis axis = MeshAxis.z,
    int segments = 16,
  }) {
    final offset = vertices.length;
    Vector3D point(double axial, double radius, double angle) {
      final radialA = radius * math.cos(angle);
      final radialB = radius * math.sin(angle);
      return center +
          switch (axis) {
            MeshAxis.z => Vector3D(radialA, radialB, axial),
            MeshAxis.x => Vector3D(axial, radialA, radialB),
            MeshAxis.y => Vector3D(radialA, axial, radialB),
          };
    }

    final count = math.max(5, segments);
    for (final entry in <List<double>>[
      <double>[-depth / 2, radiusBottom],
      <double>[depth / 2, radiusTop],
    ]) {
      for (var index = 0; index < count; index++) {
        vertices.add(point(entry[0], entry[1], index * 2 * math.pi / count));
      }
    }
    for (var index = 0; index < count; index++) {
      final next = (index + 1) % count;
      _addFace(
        <int>[index, next, count + next, count + index],
        offset,
        color,
      );
    }
    _addFace(
      List<int>.generate(count, (index) => count - 1 - index),
      offset,
      color,
    );
    _addFace(
      List<int>.generate(count, (index) => count + index),
      offset,
      color,
    );
  }

  void addSphere(
    Vector3D center,
    double radius,
    int color, {
    int segments = 16,
    int rings = 8,
    Vector3D scale = const Vector3D(1, 1, 1),
  }) {
    final longitudeCount = math.max(6, segments);
    final ringCount = math.max(3, rings);
    final offset = vertices.length;
    for (var ring = 0; ring <= ringCount; ring++) {
      final latitude = -math.pi / 2 + math.pi * ring / ringCount;
      final ringRadius = math.cos(latitude) * radius;
      final y = math.sin(latitude) * radius;
      for (var segment = 0; segment < longitudeCount; segment++) {
        final angle = 2 * math.pi * segment / longitudeCount;
        vertices.add(
          center +
              Vector3D(
                ringRadius * math.cos(angle) * scale.x,
                y * scale.y,
                ringRadius * math.sin(angle) * scale.z,
              ),
        );
      }
    }
    for (var ring = 0; ring < ringCount; ring++) {
      for (var segment = 0; segment < longitudeCount; segment++) {
        final next = (segment + 1) % longitudeCount;
        final a = ring * longitudeCount + segment;
        final b = ring * longitudeCount + next;
        final c = (ring + 1) * longitudeCount + next;
        final d = (ring + 1) * longitudeCount + segment;
        _addFace(<int>[a, b, c, d], offset, color);
      }
    }
  }

  void _addFace(List<int> indices, int offset, int color) {
    faces.add(
      MeshFace(
        indices.map((index) => index + offset).toList(growable: false),
        color,
      ),
    );
  }

  DeviceMesh build(List<MeshTerminal> terminals) => DeviceMesh(
        vertices: List<Vector3D>.unmodifiable(vertices),
        faces: List<MeshFace>.unmodifiable(faces),
        terminals: List<MeshTerminal>.unmodifiable(terminals),
      );
}
