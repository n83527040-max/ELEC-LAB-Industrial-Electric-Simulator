import 'dart:convert';

import 'component.dart';
import 'component_catalog.dart';
import 'layer.dart';
import 'terminal.dart';
import 'wire.dart';

class ElectricalProject {
  const ElectricalProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.boardWidth,
    required this.boardHeight,
    required this.layers,
    required this.components,
    required this.wires,
    this.description = '',
    this.schemaVersion = currentSchemaVersion,
    this.simulationSettings = const <String, Object>{
      'timeStepMs': 100,
      'ambientTemperature': 25.0,
    },
    this.lastSimulation,
  });

  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double boardWidth;
  final double boardHeight;
  final List<CircuitLayer> layers;
  final List<CircuitComponent> components;
  final List<CircuitWire> wires;
  final Map<String, Object> simulationSettings;
  final Map<String, dynamic>? lastSimulation;

  factory ElectricalProject.empty({
    required String id,
    required String name,
    required DateTime now,
    String description = '',
    double boardWidth = 1200,
    double boardHeight = 900,
  }) {
    return ElectricalProject(
      id: id,
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      layers: CircuitLayer.defaults(),
      components: const <CircuitComponent>[],
      wires: const <CircuitWire>[],
    );
  }

  CircuitComponent? componentById(String id) {
    for (final component in components) {
      if (component.id == id) return component;
    }
    return null;
  }

  CircuitWire? wireById(String id) {
    for (final wire in wires) {
      if (wire.id == id) return wire;
    }
    return null;
  }

  CircuitLayer? layerById(String id) {
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  ElectricalProject copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    double? boardWidth,
    double? boardHeight,
    List<CircuitLayer>? layers,
    List<CircuitComponent>? components,
    List<CircuitWire>? wires,
    Map<String, Object>? simulationSettings,
    Map<String, dynamic>? lastSimulation,
    bool clearLastSimulation = false,
  }) {
    return ElectricalProject(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      boardWidth: boardWidth ?? this.boardWidth,
      boardHeight: boardHeight ?? this.boardHeight,
      layers: layers ?? this.layers,
      components: components ?? this.components,
      wires: wires ?? this.wires,
      simulationSettings: simulationSettings ?? this.simulationSettings,
      lastSimulation:
          clearLastSimulation ? null : lastSimulation ?? this.lastSimulation,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'board': <String, double>{'width': boardWidth, 'height': boardHeight},
        'layers': layers.map((layer) => layer.toJson()).toList(),
        'components': components.map((item) => item.toJson()).toList(),
        'wires': wires.map((wire) => wire.toJson()).toList(),
        'simulationSettings': simulationSettings,
        'lastSimulation': lastSimulation,
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory ElectricalProject.fromJson(Map<String, dynamic> source) {
    final json = _migrate(source);
    final schema = json['schemaVersion'];
    final id = json['id'];
    final name = json['name'];
    final description = json['description'] ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final board = json['board'];
    final layersJson = json['layers'];
    final componentsJson = json['components'];
    final wiresJson = json['wires'];
    if (schema != currentSchemaVersion ||
        id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        description is! String ||
        createdAt == null ||
        updatedAt == null ||
        board is! Map ||
        layersJson is! List ||
        componentsJson is! List ||
        wiresJson is! List) {
      throw const FormatException('Invalid or unsupported project document.');
    }
    final width = board['width'];
    final height = board['height'];
    if (width is! num ||
        height is! num ||
        !width.isFinite ||
        !height.isFinite ||
        width < 400 ||
        height < 300 ||
        width > 5000 ||
        height > 5000) {
      throw const FormatException('Invalid board dimensions.');
    }
    final settingsJson = json['simulationSettings'] ?? <String, Object>{};
    final lastJson = json['lastSimulation'];
    if (settingsJson is! Map || (lastJson != null && lastJson is! Map)) {
      throw const FormatException('Invalid simulation data.');
    }
    final project = ElectricalProject(
      schemaVersion: currentSchemaVersion,
      id: id,
      name: name,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      boardWidth: width.toDouble(),
      boardHeight: height.toDouble(),
      layers: layersJson
          .map(
            (item) => CircuitLayer.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      components: componentsJson
          .map(
            (item) => CircuitComponent.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      wires: wiresJson
          .map(
            (item) => CircuitWire.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      simulationSettings: settingsJson.map(
        (key, value) => MapEntry(key.toString(), _setting(value)),
      ),
      lastSimulation: lastJson == null
          ? null
          : Map<String, dynamic>.from(lastJson as Map),
    );
    project.validate();
    return project;
  }

  void validate() {
    _unique(<String>[...layers.map((item) => item.id)], 'layer');
    _unique(<String>[...components.map((item) => item.id)], 'component');
    _unique(<String>[...wires.map((item) => item.id)], 'wire');
    if (layers.isEmpty) throw const FormatException('A layer is required.');
    final layerIds = layers.map((item) => item.id).toSet();
    for (final component in components) {
      if (!layerIds.contains(component.layerId)) {
        throw FormatException('Missing layer ${component.layerId}.');
      }
      ComponentCatalog.specOf(component.kind);
      final role = component.text('interlockRole').trim();
      if (!const <String>{'', 'star', 'delta'}.contains(role)) {
        throw FormatException('Invalid interlock role for ${component.id}.');
      }
    }
    final interlockGroups = <String, List<CircuitComponent>>{};
    for (final component in components) {
      final group = component.text('interlockGroup').trim();
      if (group.isEmpty) continue;
      if (component.kind != ComponentKind.contactor &&
          component.kind != ComponentKind.contactor4P) {
        throw FormatException('Interlock requires contactors: ${component.id}.');
      }
      if (!const <String>{'star', 'delta'}.contains(
        component.text('interlockRole').trim(),
      )) {
        throw FormatException('Incomplete interlock role for ${component.id}.');
      }
      interlockGroups
          .putIfAbsent(group, () => <CircuitComponent>[])
          .add(component);
    }
    for (final entry in interlockGroups.entries) {
      final roles = entry.value
          .map((component) => component.text('interlockRole').trim())
          .toSet();
      if (entry.value.length != 2 ||
          !roles.containsAll(const <String>{'star', 'delta'})) {
        throw FormatException(
          'Interlock ${entry.key} requires one star and one delta contactor.',
        );
      }
    }
    final connections = <String>{};
    for (final wire in wires) {
      if (!layerIds.contains(wire.layerId) || wire.from == wire.to) {
        throw const FormatException('Invalid wire layer or endpoints.');
      }
      _validateTerminal(wire.from);
      _validateTerminal(wire.to);
      if (wire.from.componentId == wire.to.componentId) {
        final component = componentById(wire.from.componentId);
        final motorBridge = component?.kind == ComponentKind.motor6Terminal &&
            wire.from.terminalId != wire.to.terminalId;
        if (!motorBridge) {
          throw const FormatException(
            'A wire cannot connect a device to itself.',
          );
        }
      }
      final forward = '${wire.from.key}>${wire.to.key}';
      final reverse = '${wire.to.key}>${wire.from.key}';
      if (!connections.add(forward) || connections.contains(reverse)) {
        throw const FormatException('Duplicate wire connection.');
      }
    }
  }

  void _validateTerminal(TerminalRef ref) {
    final component = componentById(ref.componentId);
    if (component == null) {
      throw FormatException('Missing component ${ref.componentId}.');
    }
    ComponentCatalog.specOf(component.kind).terminal(ref.terminalId);
  }

  static Object _setting(Object? value) {
    if (value is String) return value;
    if (value is bool) return value;
    if (value is num && value.isFinite) return value;
    throw const FormatException('Invalid simulation setting.');
  }

  static void _unique(List<String> ids, String type) {
    if (ids.toSet().length != ids.length) {
      throw FormatException('Duplicate $type id.');
    }
  }

  static Map<String, dynamic> _migrate(Map<String, dynamic> source) {
    final json = Map<String, dynamic>.from(source);
    final version = json['schemaVersion'];
    if (version == 1) {
      json['layers'] ??= CircuitLayer.defaults()
          .map((layer) => layer.toJson())
          .toList(growable: false);
      json['simulationSettings'] ??= <String, Object>{
        'timeStepMs': 100,
        'ambientTemperature': 25.0,
      };
      json['schemaVersion'] = 2;
    }
    return json;
  }
}

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.componentCount,
    required this.wireCount,
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final int componentCount;
  final int wireCount;

  factory ProjectSummary.fromProject(ElectricalProject project) =>
      ProjectSummary(
        id: project.id,
        name: project.name,
        updatedAt: project.updatedAt,
        componentCount: project.components.length,
        wireCount: project.wires.length,
      );
}
