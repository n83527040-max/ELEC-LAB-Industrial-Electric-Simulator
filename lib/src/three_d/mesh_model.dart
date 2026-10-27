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

/// Real polygon geometry consumed by the software 3D renderer. Meshes are
/// generated locally from original parametric definitions, not flat images.
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
    int color,
  ) {
    final x = size.x / 2;
    final y = size.y / 2;
    final z = size.z / 2;
    final offset = vertices.length;
    vertices.addAll(<Vector3D>[
      center + Vector3D(-x, -y, -z),
      center + Vector3D(x, -y, -z),
      center + Vector3D(x, y, -z),
      center + Vector3D(-x, y, -z),
      center + Vector3D(-x, -y, z),
      center + Vector3D(x, -y, z),
      center + Vector3D(x, y, z),
      center + Vector3D(-x, y, z),
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
      faces.add(
        MeshFace(
          face.map((index) => index + offset).toList(growable: false),
          color,
        ),
      );
    }
  }

  void addCylinder(
    Vector3D center,
    double radius,
    double depth,
    int color, {
    MeshAxis axis = MeshAxis.z,
    int segments = 16,
  }) {
    final offset = vertices.length;
    Vector3D point(double axial, double angle) {
      final radialA = radius * math.cos(angle);
      final radialB = radius * math.sin(angle);
      return center +
          switch (axis) {
            MeshAxis.z => Vector3D(radialA, radialB, axial),
            MeshAxis.x => Vector3D(axial, radialA, radialB),
            MeshAxis.y => Vector3D(radialA, axial, radialB),
          };
    }

    for (final side in <double>[-depth / 2, depth / 2]) {
      for (var index = 0; index < segments; index++) {
        vertices.add(point(side, index * 2 * math.pi / segments));
      }
    }
    for (var index = 0; index < segments; index++) {
      final next = (index + 1) % segments;
      faces.add(
        MeshFace(
          <int>[offset + index, offset + next, offset + segments + next, offset + segments + index],
          color,
        ),
      );
    }
    faces.add(
      MeshFace(
        List<int>.generate(segments, (index) => offset + segments - 1 - index),
        color,
      ),
    );
    faces.add(
      MeshFace(
        List<int>.generate(segments, (index) => offset + segments + index),
        color,
      ),
    );
  }

  DeviceMesh build(List<MeshTerminal> terminals) => DeviceMesh(
        vertices: List<Vector3D>.unmodifiable(vertices),
        faces: List<MeshFace>.unmodifiable(faces),
        terminals: terminals,
      );
}
