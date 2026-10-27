import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/component_catalog.dart';
import 'package:elec_lab/src/models/geometry.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/wire.dart';

final DateTime testNow = DateTime.utc(2026, 10, 27, 12);

CircuitComponent device(
  String id,
  ComponentKind kind, {
  double x = 100,
  double y = 100,
  String layer = 'power',
  Map<String, Object> overrides = const <String, Object>{},
}) {
  return CircuitComponent(
    id: id,
    kind: kind,
    label: id.toUpperCase(),
    position: BoardPoint(x, y),
    layerId: layer,
    properties: <String, Object>{
      ...ComponentCatalog.specOf(kind).defaultProperties,
      ...overrides,
    },
  );
}

CircuitWire connection(
  String id,
  String fromComponent,
  String fromTerminal,
  String toComponent,
  String toTerminal, {
  String layer = 'power',
  List<BoardPoint> waypoints = const <BoardPoint>[],
}) {
  return CircuitWire(
    id: id,
    from: TerminalRef(componentId: fromComponent, terminalId: fromTerminal),
    to: TerminalRef(componentId: toComponent, terminalId: toTerminal),
    layerId: layer,
    waypoints: waypoints,
  );
}

ElectricalProject projectOf(
  List<CircuitComponent> components,
  List<CircuitWire> wires,
) {
  final project = ElectricalProject.empty(
    id: 'test_project',
    name: 'Test project',
    now: testNow,
  ).copyWith(components: components, wires: wires);
  project.validate();
  return project;
}

ElectricalProject setProperty(
  ElectricalProject project,
  String id,
  String key,
  Object value,
) {
  return project.copyWith(
    components: project.components.map((component) {
      if (component.id != id) return component;
      return component.copyWith(
        properties: <String, Object>{...component.properties, key: value},
      );
    }).toList(growable: false),
  );
}
