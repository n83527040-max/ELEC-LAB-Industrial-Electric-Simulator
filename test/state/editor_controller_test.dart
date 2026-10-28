import 'package:elec_lab/src/models/geometry.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/models/supply_bay.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/state/editor_controller.dart';
import 'package:elec_lab/src/state/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  late ElectricalProject empty;
  late EditorController controller;

  setUp(() {
    empty = ElectricalProject.empty(id: 'editor', name: 'Editor', now: testNow);
    controller = EditorController(
      project: empty,
      idFactory: IdFactory(clock: () => testNow),
      clock: () => testNow,
    );
  });

  tearDown(() => controller.dispose());

  test(
      'add, snap, move, rotate, duplicate, delete and undo/redo are real edits',
      () {
    final id = controller.addComponent(
        ComponentKind.dcSupply, const BoardPoint(103, 207));
    expect(controller.project.componentById(id)!.position,
        const BoardPoint(100, 200));
    controller.moveComponent(id, const BoardPoint(122, 244));
    expect(controller.project.componentById(id)!.position,
        const BoardPoint(120, 240));
    controller.rotateComponent(id);
    expect(controller.project.componentById(id)!.rotation, 1);
    final duplicate = controller.duplicateComponent(id)!;
    expect(duplicate, isNot(id));
    expect(controller.project.components, hasLength(5));
    controller.deleteComponent(id);
    expect(
      controller.project.components.map((item) => item.id),
      containsAll(<String>[...SupplyBay.ids, duplicate]),
    );
    expect(controller.project.components, hasLength(4));
    controller.undo();
    expect(controller.project.components, hasLength(5));
    controller.redo();
    expect(controller.project.components, hasLength(4));
    expect(controller.project.componentById(duplicate), isNotNull);
  });

  test('continuous drag is one undo operation', () {
    final id = controller.addComponent(
        ComponentKind.indicator, const BoardPoint(100, 100));
    final before = controller.undoCount;
    controller.beginInteraction();
    controller.moveComponent(id, const BoardPoint(120, 100), transient: true);
    controller.moveComponent(id, const BoardPoint(140, 100), transient: true);
    controller.moveComponent(id, const BoardPoint(160, 100), transient: true);
    controller.endInteraction();
    expect(controller.undoCount, before + 1);
    expect(controller.project.componentById(id)!.position,
        const BoardPoint(160, 100));
    controller.undo();
    expect(controller.project.componentById(id)!.position,
        const BoardPoint(100, 100));
  });

  test('terminal-to-terminal flow validates and edits wires and waypoints', () {
    final sourceId = controller.addComponent(
      ComponentKind.dcSupply,
      const BoardPoint(100, 100),
    );
    final lampId = controller.addComponent(
      ComponentKind.indicator,
      const BoardPoint(500, 100),
    );
    final source = controller.project.componentById(sourceId)!;
    final lamp = controller.project.componentById(lampId)!;
    final start = TerminalRef(componentId: source.id, terminalId: 'positive');
    final end = TerminalRef(componentId: lamp.id, terminalId: 'x1');
    controller.beginWire(start);
    expect(controller.pendingWireStart, start);
    final wireId = controller.completeWire(end)!;
    expect(wireId, isNotNull);
    expect(controller.project.wires, hasLength(1));
    expect(controller.selectedWireId, wireId);
    controller.addWireWaypoint(wireId, const BoardPoint(305, 205));
    expect(
        controller.selectedWire!.waypoints.single, const BoardPoint(300, 200));
    controller.moveWireWaypoint(wireId, 0, const BoardPoint(330, 240));
    expect(
        controller.selectedWire!.waypoints.single, const BoardPoint(340, 240));
    controller
        .updateWire(controller.selectedWire!.copyWith(crossSectionMm2: 2.5));
    expect(controller.selectedWire!.crossSectionMm2, 2.5);
    controller.autoRouteWire(wireId);
    expect(controller.selectedWire!.waypoints, isEmpty);
    controller.beginWire(start);
    expect(controller.completeWire(end), isNull);
    expect(controller.lastError, contains('موجود'));
    controller.deleteWire(wireId);
    expect(controller.project.wires, isEmpty);
    controller.undo();
    expect(controller.project.wires, hasLength(1));
  });

  test(
      'source-to-coil wiring is stored on the control layer with control color',
      () {
    final contactorId = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(500, 261),
    );
    controller.beginWire(
      const TerminalRef(
        componentId: SupplyBay.dcId,
        terminalId: 'positive',
      ),
    );
    final wireId = controller.completeWire(
      TerminalRef(componentId: contactorId, terminalId: 'a1'),
    );
    final wire = controller.project.wireById(wireId!)!;
    expect(wire.layerId, 'control');
    expect(wire.colorValue, 0xff1e88e5);
    expect(wire.from.componentId, SupplyBay.dcId);
    expect(wire.to.terminalId, 'a1');
  });

  test('layers rename, hide, lock and protect against accidental deletion', () {
    final id = controller.addComponent(
        ComponentKind.dcSupply, const BoardPoint(100, 100));
    final before = controller.project.componentById(id)!.position;
    controller.setLayerVisibility('power', false);
    expect(controller.project.layerById('power')!.visible, isFalse);
    controller.setLayerLocked('power', true);
    controller.moveComponent(id, const BoardPoint(300, 300));
    expect(controller.project.componentById(id)!.position, before);
    expect(controller.deleteLayer('power'), isFalse);
    final layerId = controller.addLayer('إشارات خاصة');
    controller.renameLayer(layerId, 'قياس');
    expect(controller.project.layerById(layerId)!.name, 'قياس');
    expect(controller.deleteLayer(layerId), isTrue);
  });

  test('reserved supplies stay fixed and DIN devices snap near a rail', () {
    final supply = controller.project.componentById(SupplyBay.threePhaseId)!;
    controller.moveComponent(supply.id, const BoardPoint(700, 500));
    controller.rotateComponent(supply.id);
    controller.resizeComponent(supply.id, 1.8);
    expect(controller.duplicateComponent(supply.id), isNull);
    controller.deleteComponent(supply.id);
    final retained = controller.project.componentById(supply.id)!;
    expect(retained.position, supply.position);
    expect(retained.rotation, supply.rotation);
    expect(retained.scale, supply.scale);
    controller.setSupplyEnabled(supply.id, true);
    expect(
        controller.project.componentById(supply.id)!.flag('enabled'), isTrue);

    final id = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(300, 260),
    );
    expect(controller.project.componentById(id)!.position,
        const BoardPoint(300, 261));
    controller.moveComponent(id, const BoardPoint(320, 420));
    expect(controller.project.componentById(id)!.position,
        const BoardPoint(320, 420));
  });

  test('viewport limits and snap settings are enforced', () {
    controller.setViewport(scale: 10, offset: const BoardPoint(20, 30));
    expect(controller.zoom, 3);
    expect(controller.viewportOffset, const BoardPoint(20, 30));
    controller.setViewport(scale: 0.01);
    expect(controller.zoom, 0.08);
    controller.setGrid(visible: false, snap: false, size: 25);
    expect(controller.showGrid, isFalse);
    controller.setIndustrialSurface(false);
    expect(controller.industrialSurface, isFalse);
    expect(controller.snap(const BoardPoint(31, 32)), const BoardPoint(31, 32));
    controller.setGrid(snap: true);
    expect(controller.snap(const BoardPoint(31, 32)), const BoardPoint(25, 25));
  });

  test('flush persists the actual edited project', () async {
    ElectricalProject? saved;
    final savingController = EditorController(
      project: empty,
      onSave: (project) async {
        saved = project;
      },
    );
    savingController.addComponent(
        ComponentKind.dcSupply, const BoardPoint(100, 100));
    await savingController.flush();
    expect(saved, isNotNull);
    expect(saved!.components, hasLength(4));
    expect(saved!.name, 'Editor');
    savingController.dispose();
  });

  test('interlock pair is validated and committed atomically with undo/redo',
      () {
    final first = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(250, 261),
    );
    final second = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(450, 261),
    );
    expect(
      controller.configureInterlockPair(first, '', 'motor_1', 'star'),
      isNotNull,
    );
    expect(controller.project.componentById(first)!.text('interlockGroup'),
        isEmpty);

    final before = controller.undoCount;
    expect(
      controller.configureInterlockPair(first, second, 'motor_1', 'star'),
      isNull,
    );
    controller.project.validate();
    expect(controller.undoCount, before + 1);
    expect(
        controller.project.componentById(first)!.text('interlockRole'), 'star');
    expect(controller.project.componentById(second)!.text('interlockRole'),
        'delta');
    expect(
      controller.project.componentById(first)!.text('interlockGroup'),
      controller.project.componentById(second)!.text('interlockGroup'),
    );

    controller.undo();
    expect(controller.project.componentById(first)!.text('interlockGroup'),
        isEmpty);
    expect(controller.project.componentById(second)!.text('interlockGroup'),
        isEmpty);
    controller.redo();
    expect(controller.project.componentById(first)!.text('interlockGroup'),
        'motor_1');

    controller.updateComponentProperties(first, <String, Object>{
      ...controller.project.componentById(first)!.properties,
      'interlockGroup': 'dangling',
    });
    expect(controller.project.componentById(first)!.text('interlockGroup'),
        'motor_1');
    expect(controller.lastError, contains('زوج التعشيق'));

    expect(controller.clearInterlockPair(first), isNull);
    controller.project.validate();
    expect(controller.project.componentById(first)!.text('interlockGroup'),
        isEmpty);
    expect(controller.project.componentById(second)!.text('interlockGroup'),
        isEmpty);
  });

  test('pair reassignment duplication and deletion never leave dangling groups',
      () {
    final first = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(250, 261),
    );
    final second = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(450, 261),
    );
    final third = controller.addComponent(
      ComponentKind.contactor4P,
      const BoardPoint(650, 261),
    );
    final fourth = controller.addComponent(
      ComponentKind.contactor,
      const BoardPoint(850, 261),
    );
    expect(controller.configureInterlockPair(first, second, 'pair_a', 'star'),
        isNull);
    expect(controller.configureInterlockPair(third, fourth, 'pair_a', 'star'),
        isNotNull);
    expect(controller.project.componentById(third)!.text('interlockGroup'),
        isEmpty);
    expect(controller.project.componentById(fourth)!.text('interlockGroup'),
        isEmpty);

    expect(controller.configureInterlockPair(first, third, 'pair_b', 'delta'),
        isNull);
    controller.project.validate();
    expect(controller.project.componentById(first)!.text('interlockRole'),
        'delta');
    expect(
        controller.project.componentById(third)!.text('interlockRole'), 'star');
    expect(controller.project.componentById(second)!.text('interlockGroup'),
        isEmpty);
    expect(controller.project.componentById(second)!.text('interlockRole'),
        isEmpty);

    final duplicate = controller.duplicateComponent(first)!;
    expect(controller.project.componentById(duplicate)!.text('interlockGroup'),
        isEmpty);
    expect(controller.project.componentById(duplicate)!.text('interlockRole'),
        isEmpty);
    controller.deleteComponent(third);
    controller.project.validate();
    expect(controller.project.componentById(first)!.text('interlockGroup'),
        isEmpty);
    expect(controller.project.componentById(first)!.text('interlockRole'),
        isEmpty);
  });

  test('controller stores the last calculated result when simulation stops',
      () {
    final project = ProjectTemplates.apply(empty, ProjectTemplateKind.dcLamp);
    final simulationController = EditorController(project: project);
    simulationController.startSimulation();
    simulationController.setMomentaryPressed('s1', true);
    expect(simulationController.result?['h1']?.active, isTrue);
    simulationController.stopSimulation();
    expect(simulationController.project.lastSimulation, isNotNull);
    expect(simulationController.project.lastSimulation!['success'], isTrue);
    simulationController.dispose();
  });
}
