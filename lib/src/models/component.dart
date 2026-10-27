import 'dart:ui' show Size;

import 'geometry.dart';
import 'terminal.dart';

class ComponentSpec {
  const ComponentSpec({
    required this.kind,
    required this.nameAr,
    required this.nameFr,
    required this.category,
    required this.size,
    required this.terminals,
    required this.defaultProperties,
    required this.description,
  });

  final ComponentKind kind;
  final String nameAr;
  final String nameFr;
  final ComponentCategory category;
  final Size size;
  final List<TerminalDefinition> terminals;
  final Map<String, Object> defaultProperties;
  final String description;

  TerminalDefinition terminal(String id) => terminals.firstWhere(
        (item) => item.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'Unknown terminal'),
      );
}

class CircuitComponent {
  const CircuitComponent({
    required this.id,
    required this.kind,
    required this.label,
    required this.position,
    required this.layerId,
    this.rotation = 0,
    this.scale = 1,
    this.properties = const <String, Object>{},
  });

  final String id;
  final ComponentKind kind;
  final String label;
  final BoardPoint position;
  final String layerId;
  final int rotation;
  final double scale;
  final Map<String, Object> properties;

  CircuitComponent copyWith({
    String? label,
    BoardPoint? position,
    String? layerId,
    int? rotation,
    double? scale,
    Map<String, Object>? properties,
  }) {
    return CircuitComponent(
      id: id,
      kind: kind,
      label: label ?? this.label,
      position: position ?? this.position,
      layerId: layerId ?? this.layerId,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      properties: properties ?? this.properties,
    );
  }

  double number(String key) {
    final value = properties[key];
    if (value is num) return value.toDouble();
    throw StateError('$label: property $key is not numeric.');
  }

  bool flag(String key) => properties[key] == true;

  String text(String key) => properties[key]?.toString() ?? '';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'label': label,
        'position': position.toJson(),
        'layerId': layerId,
        'rotation': rotation,
        'scale': scale,
        'properties': properties,
      };

  factory CircuitComponent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    final layerId = json['layerId'];
    final kindName = json['kind'];
    final positionJson = json['position'];
    final propertiesJson = json['properties'];
    if (id is! String ||
        id.isEmpty ||
        label is! String ||
        layerId is! String ||
        kindName is! String ||
        positionJson is! Map ||
        propertiesJson is! Map) {
      throw const FormatException('Invalid component record.');
    }
    final kind = ComponentKind.values.asNameMap()[kindName];
    if (kind == null) {
      throw FormatException('Unsupported component kind: $kindName');
    }
    final rotation = json['rotation'] ?? 0;
    final scale = json['scale'] ?? 1.0;
    if (rotation is! int ||
        rotation < 0 ||
        rotation > 3 ||
        scale is! num ||
        !scale.isFinite ||
        scale < 0.6 ||
        scale > 1.8) {
      throw const FormatException('Invalid component transform.');
    }
    return CircuitComponent(
      id: id,
      kind: kind,
      label: label,
      position: BoardPoint.fromJson(
        Map<String, dynamic>.from(positionJson),
      ),
      layerId: layerId,
      rotation: rotation,
      scale: scale.toDouble(),
      properties: propertiesJson.map(
        (key, value) => MapEntry(key.toString(), _validateProperty(value)),
      ),
    );
  }

  static Object _validateProperty(Object? value) {
    if (value is String) return value;
    if (value is bool) return value;
    if (value is num && value.isFinite) return value;
    throw const FormatException('Component properties must be scalar values.');
  }
}
