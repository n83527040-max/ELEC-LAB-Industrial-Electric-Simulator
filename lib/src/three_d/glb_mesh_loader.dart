import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/component.dart';
import '../models/terminal.dart';
import 'mesh_model.dart';
import 'procedural_meshes.dart';

/// Lazy asset repository. A GLB is decoded only when a board device, a visible
/// library card, the detailed viewer, or an export actually requests it.
abstract final class DeviceMeshRepository {
  static final Map<String, Future<DeviceMesh>> _cache =
      <String, Future<DeviceMesh>>{};

  static String assetPath(ComponentKind kind, MeshDetail detail) =>
      'assets/models/${detail.name}/${kind.name}.glb';

  static Future<DeviceMesh> forComponent(
    CircuitComponent component, {
    MeshDetail detail = MeshDetail.preview,
  }) {
    return _cached(
      component.kind,
      detail,
      component.text('color'),
    );
  }

  static Future<DeviceMesh> forKind(
    ComponentKind kind, {
    MeshDetail detail = MeshDetail.preview,
    String color = '',
  }) {
    return _cached(kind, detail, color);
  }

  static Future<DeviceMesh> _cached(
    ComponentKind kind,
    MeshDetail detail,
    String color,
  ) {
    final path = assetPath(kind, detail);
    final key = '$path:$color';
    return _cache.putIfAbsent(
      key,
      () async {
        final data = await rootBundle.load(path);
        return GlbMeshDecoder.decode(
          data,
          kind: kind,
          colorName: color,
        );
      },
    );
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();
}

/// Small, strict glTF 2.0 binary decoder for the application's software mesh
/// renderer. It supports embedded GLB buffers, float VEC3 positions, unsigned
/// triangle indices and PBR base colors. External buffers, images, skins and
/// animations are deliberately rejected instead of being silently ignored.
abstract final class GlbMeshDecoder {
  static DeviceMesh decode(
    ByteData source, {
    required ComponentKind kind,
    String colorName = '',
  }) {
    final bytes = source.buffer.asUint8List(
      source.offsetInBytes,
      source.lengthInBytes,
    );
    if (bytes.length < 28) {
      throw const FormatException('GLB is too small.');
    }
    final header = ByteData.sublistView(bytes, 0, 12);
    if (header.getUint32(0, Endian.little) != 0x46546c67 ||
        header.getUint32(4, Endian.little) != 2 ||
        header.getUint32(8, Endian.little) != bytes.length) {
      throw const FormatException('Invalid GLB 2.0 header.');
    }

    Map<String, dynamic>? document;
    var binaryOffset = -1;
    var binaryLength = 0;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkHeader = ByteData.sublistView(bytes, offset, 8);
      final length = chunkHeader.getUint32(0, Endian.little);
      final type = chunkHeader.getUint32(4, Endian.little);
      final start = offset + 8;
      if (length < 0 || start + length > bytes.length) {
        throw const FormatException('Invalid GLB chunk length.');
      }
      if (type == 0x4e4f534a) {
        final decoded = jsonDecode(utf8.decode(bytes.sublist(start, start + length)));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid glTF JSON document.');
        }
        document = decoded;
      } else if (type == 0x004e4942) {
        binaryOffset = start;
        binaryLength = length;
      }
      offset = start + length;
    }
    final json = document;
    if (json == null || binaryOffset < 0) {
      throw const FormatException('GLB requires JSON and BIN chunks.');
    }
    final buffers = json['buffers'];
    if (buffers is! List ||
        buffers.length != 1 ||
        buffers.single is! Map ||
        (buffers.single as Map)['uri'] != null ||
        (buffers.single as Map)['byteLength'] != binaryLength) {
      throw const FormatException('Only one embedded GLB buffer is supported.');
    }

    final vertices = <Vector3D>[];
    final faces = <MeshFace>[];
    final accessorOffsets = <int, int>{};
    final meshes = json['meshes'];
    final materials = json['materials'];
    if (meshes is! List || meshes.isEmpty) {
      throw const FormatException('GLB contains no mesh.');
    }

    for (final rawMesh in meshes) {
      if (rawMesh is! Map || rawMesh['primitives'] is! List) {
        throw const FormatException('Invalid GLB mesh.');
      }
      for (final rawPrimitive in rawMesh['primitives'] as List) {
        if (rawPrimitive is! Map ||
            rawPrimitive['mode'] != 4 ||
            rawPrimitive['attributes'] is! Map) {
          throw const FormatException('Only indexed triangle primitives are supported.');
        }
        final attributes = rawPrimitive['attributes'] as Map;
        final positionIndex = attributes['POSITION'];
        final indexIndex = rawPrimitive['indices'];
        if (positionIndex is! int || indexIndex is! int) {
          throw const FormatException('Primitive requires positions and indices.');
        }
        final vertexOffset = accessorOffsets.putIfAbsent(
          positionIndex,
          () {
            final accessor = _AccessorReader(
              json,
              bytes,
              binaryOffset,
              positionIndex,
              expectedType: 'VEC3',
              expectedComponent: 5126,
            );
            final start = vertices.length;
            for (var index = 0; index < accessor.count; index++) {
              final point = accessor.vec3(index);
              if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) {
                throw const FormatException('Non-finite vertex.');
              }
              vertices.add(point);
            }
            return start;
          },
        );
        final indices = _AccessorReader(
          json,
          bytes,
          binaryOffset,
          indexIndex,
          expectedType: 'SCALAR',
        );
        if (indices.count == 0 || indices.count % 3 != 0) {
          throw const FormatException('Triangle index count must be a multiple of three.');
        }
        final color = _materialColor(
          materials,
          rawPrimitive['material'],
          colorName,
        );
        for (var index = 0; index < indices.count; index += 3) {
          final triangle = <int>[
            vertexOffset + indices.scalar(index),
            vertexOffset + indices.scalar(index + 1),
            vertexOffset + indices.scalar(index + 2),
          ];
          if (triangle.any((value) => value < 0 || value >= vertices.length)) {
            throw const FormatException('Triangle index outside vertex buffer.');
          }
          faces.add(MeshFace(triangle, color));
        }
      }
    }
    if (vertices.isEmpty || faces.isEmpty) {
      throw const FormatException('GLB contains no drawable triangles.');
    }
    return DeviceMesh(
      vertices: List<Vector3D>.unmodifiable(vertices),
      faces: List<MeshFace>.unmodifiable(faces),
      terminals: ProceduralMeshes.terminalsForKind(kind),
    );
  }

  static int _materialColor(
    dynamic rawMaterials,
    dynamic materialIndex,
    String colorName,
  ) {
    var factor = const <double>[1, 1, 1, 1];
    var name = '';
    if (materialIndex is int && rawMaterials is List && materialIndex < rawMaterials.length) {
      final material = rawMaterials[materialIndex];
      if (material is Map) {
        name = material['name']?.toString() ?? '';
        final pbr = material['pbrMetallicRoughness'];
        final rawFactor = pbr is Map ? pbr['baseColorFactor'] : null;
        if (rawFactor is List && rawFactor.length == 4) {
          factor = rawFactor.map((value) => (value as num).toDouble()).toList();
        }
      }
    }
    if (name == 'statusLens') {
      return switch (colorName) {
        'green' => 0xff25a66a,
        'yellow' => 0xffe8b83d,
        _ => 0xffdb3b36,
      };
    }
    int channel(double value) => (value.clamp(0, 1) * 255).round();
    return (channel(factor[3]) << 24) |
        (channel(factor[0]) << 16) |
        (channel(factor[1]) << 8) |
        channel(factor[2]);
  }
}

class _AccessorReader {
  factory _AccessorReader(
    Map<String, dynamic> json,
    Uint8List bytes,
    int binaryOffset,
    int index, {
    required String expectedType,
    int? expectedComponent,
  }) {
    final accessors = json['accessors'];
    final views = json['bufferViews'];
    if (accessors is! List || index < 0 || index >= accessors.length || views is! List) {
      throw const FormatException('Invalid GLB accessor.');
    }
    final accessor = accessors[index];
    if (accessor is! Map ||
        accessor['type'] != expectedType ||
        accessor['count'] is! int ||
        accessor['componentType'] is! int ||
        accessor['sparse'] == true ||
        accessor['normalized'] == true) {
      throw const FormatException('Unsupported GLB accessor.');
    }
    final component = accessor['componentType'] as int;
    if (expectedComponent != null && component != expectedComponent) {
      throw const FormatException('Unsupported GLB component type.');
    }
    if (expectedType == 'SCALAR' && component != 5121 && component != 5123 && component != 5125) {
      throw const FormatException('Indices must be unsigned integers.');
    }
    final viewIndex = accessor['bufferView'];
    if (viewIndex is! int || viewIndex < 0 || viewIndex >= views.length) {
      throw const FormatException('Accessor has no valid buffer view.');
    }
    final view = views[viewIndex];
    if (view is! Map || view['buffer'] != 0) {
      throw const FormatException('Invalid GLB buffer view.');
    }
    final componentSize = switch (component) {
      5121 => 1,
      5123 => 2,
      5125 || 5126 => 4,
      _ => throw const FormatException('Unsupported component size.'),
    };
    final components = expectedType == 'VEC3' ? 3 : 1;
    final elementSize = componentSize * components;
    final stride = view['byteStride'] is int ? view['byteStride'] as int : elementSize;
    if (stride < elementSize) {
      throw const FormatException('Invalid accessor stride.');
    }
    final count = accessor['count'] as int;
    final start = binaryOffset +
        (view['byteOffset'] is int ? view['byteOffset'] as int : 0) +
        (accessor['byteOffset'] is int ? accessor['byteOffset'] as int : 0);
    final end = count == 0 ? start : start + (count - 1) * stride + elementSize;
    if (start < binaryOffset || end > bytes.length) {
      throw const FormatException('Accessor outside embedded buffer.');
    }
    return _AccessorReader._(
      ByteData.sublistView(bytes),
      start,
      stride,
      count,
      component,
    );
  }

  const _AccessorReader._(
    this.data,
    this.start,
    this.stride,
    this.count,
    this.component,
  );

  final ByteData data;
  final int start;
  final int stride;
  final int count;
  final int component;

  double _number(int offset) => switch (component) {
        5121 => data.getUint8(offset).toDouble(),
        5123 => data.getUint16(offset, Endian.little).toDouble(),
        5125 => data.getUint32(offset, Endian.little).toDouble(),
        5126 => data.getFloat32(offset, Endian.little),
        _ => throw StateError('Unsupported component.'),
      };

  int scalar(int index) => _number(start + index * stride).toInt();

  Vector3D vec3(int index) {
    final offset = start + index * stride;
    return Vector3D(
      _number(offset),
      _number(offset + 4),
      _number(offset + 8),
    );
  }
}
