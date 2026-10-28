import 'dart:convert';

import 'package:elec_lab/src/models/board_geometry.dart';
import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/component_catalog.dart';
import 'package:elec_lab/src/models/connection_validator.dart';
import 'package:elec_lab/src/models/geometry.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/models/supply_bay.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/models/wire_sizing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('Component catalog and terminals', () {
    test('every simulated component has unique, bounded terminals', () {
      for (final spec in ComponentCatalog.byKind.values) {
        final ids = spec.terminals.map((terminal) => terminal.id).toList();
        expect(ids.toSet().length, ids.length, reason: spec.kind.name);
        expect(spec.terminals, isNotEmpty, reason: spec.kind.name);
        for (final terminal in spec.terminals) {
          expect(terminal.position.x, inInclusiveRange(0, spec.size.width));
          expect(terminal.position.y, inInclusiveRange(0, spec.size.height));
        }
      }
    });

    test('contactor exposes real power, coil and auxiliary terminal names', () {
      final spec = ComponentCatalog.specOf(ComponentKind.contactor);
      expect(
        spec.terminals.map((item) => item.id),
        containsAll(<String>[
          'l1',
          'l2',
          'l3',
          't1',
          't2',
          't3',
          'a1',
          'a2',
          'aux13',
          'aux14',
          'aux21',
          'aux22'
        ]),
      );
      expect(spec.terminal('a1').kind, TerminalKind.coil);
      expect(spec.terminal('t3').phase, 'L3');
    });

    test('terminal positions rotate around the actual device centre', () {
      final component =
          device('k1', ComponentKind.contactor).copyWith(rotation: 1);
      final spec = ComponentCatalog.specOf(ComponentKind.contactor);
      final original = BoardGeometry.terminalPosition(
        device('k1', ComponentKind.contactor),
        'l1',
      );
      final rotated = BoardGeometry.terminalPosition(component, 'l1');
      expect(rotated, isNot(original));
      expect(
        rotated.distanceTo(BoardGeometry.center(component)),
        closeTo(original.distanceTo(BoardGeometry.center(component)), 1e-9),
      );
      expect(spec.size.width, greaterThan(0));
    });

    test('scaled and rotated terminals use the same centre as board rendering',
        () {
      final component = device('k1', ComponentKind.contactor, x: 120, y: 80)
          .copyWith(scale: 1.4, rotation: 1);
      final spec = ComponentCatalog.specOf(component.kind);
      final terminal = spec.terminal('l1');
      final expectedCenter = component.position +
          BoardPoint(spec.size.width * 1.4 / 2, spec.size.height * 1.4 / 2);
      final delta = (terminal.position -
              BoardPoint(spec.size.width / 2, spec.size.height / 2)) *
          1.4;
      final expected = expectedCenter + BoardPoint(-delta.y, delta.x);
      expect(BoardGeometry.center(component), expectedCenter);
      expect(BoardGeometry.terminalPosition(component, 'l1'), expected);
    });
  });

  group('Project schema', () {
    test('round trip preserves components, layers, wires and manual path', () {
      final source = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply)
              .copyWith(rotation: 2, scale: 1.2),
          device('h1', ComponentKind.indicator, layer: 'signals'),
        ],
        <CircuitWire>[
          connection(
            'w1',
            'g1',
            'positive',
            'h1',
            'x1',
            waypoints: const <BoardPoint>[
              BoardPoint(220, 80),
              BoardPoint(280, 130)
            ],
          ),
          connection('w2', 'h1', 'x2', 'g1', 'negative'),
        ],
      ).copyWith(description: 'مخطط تجريبي');
      final decoded = ElectricalProject.fromJson(
        jsonDecode(source.encode()) as Map<String, dynamic>,
      );
      expect(decoded.encode(), source.encode());
      expect(decoded.wires.singleWhere((wire) => wire.id == 'w1').waypoints,
          hasLength(2));
      expect(decoded.components.first.rotation, 2);
      expect(decoded.layers, hasLength(4));
    });

    test('permanent supply bay has real disabled sources and persists N and PE',
        () {
      final empty = ElectricalProject.empty(
        id: 'supply_bay',
        name: 'Supply bay',
        now: testNow,
      );
      final project = SupplyBay.install(empty);
      expect(project.components, hasLength(3));
      expect(
          SupplyBay.ids
              .every(project.components.map((item) => item.id).contains),
          isTrue);
      expect(project.components.every((item) => !item.flag('enabled')), isTrue);
      final threePhase = project.componentById(SupplyBay.threePhaseId)!;
      expect(
        ComponentCatalog.specOf(threePhase.kind)
            .terminals
            .map((item) => item.id),
        containsAll(<String>['l1', 'l2', 'l3', 'neutral', 'pe']),
      );
      expect(identical(SupplyBay.install(project), project), isTrue);
      final wired = project.copyWith(
        components: <CircuitComponent>[
          ...project.components,
          device('m1', ComponentKind.motor3Phase),
        ],
        wires: <CircuitWire>[
          connection(
            'protective_earth',
            SupplyBay.threePhaseId,
            'pe',
            'm1',
            'earth',
          ),
        ],
      );
      final decoded = ElectricalProject.fromJson(
        jsonDecode(wired.encode()) as Map<String, dynamic>,
      );
      expect(decoded.componentById(SupplyBay.dcId)?.flag('enabled'), isFalse);
      expect(decoded.componentById(SupplyBay.threePhaseId)?.position,
          threePhase.position);
      expect(decoded.wires.single.from.componentId, SupplyBay.threePhaseId);
      expect(decoded.wires.single.from.terminalId, 'pe');
      expect(decoded.wires.single.to.componentId, 'm1');
    });

    test('supply installation restores a missing power layer in legacy blanks',
        () {
      final legacy = ElectricalProject.empty(
        id: 'legacy_blank',
        name: 'Legacy blank',
        now: testNow,
      );
      final withoutPower = legacy.copyWith(
        layers: legacy.layers.where((layer) => layer.id != 'power').toList(),
      );
      final installed = SupplyBay.install(withoutPower);
      expect(installed.layerById('power'), isNotNull);
      expect(installed.components, hasLength(3));
      expect(() => installed.validate(), returnsNormally);
    });

    test('version 1 document is migrated with default layers', () {
      final project = ElectricalProject.empty(
        id: 'legacy',
        name: 'Legacy',
        now: testNow,
      );
      final json = project.toJson()
        ..['schemaVersion'] = 1
        ..remove('layers')
        ..remove('simulationSettings');
      final migrated = ElectricalProject.fromJson(json);
      expect(migrated.schemaVersion, ElectricalProject.currentSchemaVersion);
      expect(migrated.layers, hasLength(4));
    });

    test('invalid references and unsafe ids are rejected', () {
      final project = projectOf(
        <CircuitComponent>[device('g1', ComponentKind.dcSupply)],
        <CircuitWire>[],
      );
      final bad = project.toJson();
      bad['id'] = '../escape';
      expect(() => ElectricalProject.fromJson(bad), throwsFormatException);
      expect(
        () => projectOf(
          <CircuitComponent>[device('g1', ComponentKind.dcSupply)],
          <CircuitWire>[connection('bad', 'g1', 'positive', 'g1', 'negative')],
        ),
        throwsFormatException,
      );
    });

    test('all delivered templates are valid non-empty circuits', () {
      for (final template in ProjectTemplateKind.values.skip(1)) {
        final empty = ElectricalProject.empty(
          id: 'template',
          name: 'Template',
          now: testNow,
        );
        final project = ProjectTemplates.apply(empty, template);
        expect(project.components, isNotEmpty);
        expect(project.wires, isNotEmpty);
        expect(() => project.validate(), returnsNormally);
      }
    });
  });

  group('Mechanical interlock documents', () {
    ElectricalProject pairProject() => projectOf(
          <CircuitComponent>[
            device(
              'km2',
              ComponentKind.contactor,
              overrides: const <String, Object>{
                'interlockGroup': 'motor_pair',
                'interlockRole': 'star',
              },
            ),
            device(
              'km3',
              ComponentKind.contactor,
              overrides: const <String, Object>{
                'interlockGroup': 'motor_pair',
                'interlockRole': 'delta',
              },
            ),
          ],
          const <CircuitWire>[],
        );

    test('exactly two complementary roles are required', () {
      final valid = pairProject();
      expect(valid.validate, returnsNormally);
      final dangling = valid.copyWith(
        components: <CircuitComponent>[valid.components.first],
      );
      expect(dangling.validate, throwsFormatException);
      final sameRoles = valid.copyWith(
        components: <CircuitComponent>[
          valid.components.first,
          valid.components.last.copyWith(
            properties: <String, Object>{
              ...valid.components.last.properties,
              'interlockRole': 'star',
            },
          ),
        ],
      );
      expect(sameRoles.validate, throwsFormatException);
      final third = device(
        'km4',
        ComponentKind.contactor,
        overrides: const <String, Object>{
          'interlockGroup': 'motor_pair',
          'interlockRole': 'star',
        },
      );
      expect(
        valid.copyWith(
          components: <CircuitComponent>[...valid.components, third],
        ).validate,
        throwsFormatException,
      );
      final unsupportedPeer = valid.copyWith(
        components: <CircuitComponent>[
          valid.components.first,
          device(
            'h1',
            ComponentKind.indicator,
            overrides: const <String, Object>{
              'interlockGroup': 'motor_pair',
              'interlockRole': 'delta',
            },
          ),
        ],
      );
      expect(unsupportedPeer.validate, throwsFormatException);
    });

    test('six-lead motor bridges are allowed only between distinct terminals',
        () {
      final motor = device('m1', ComponentKind.motor6Terminal);
      final bridge = connection('bridge', 'm1', 'u2', 'm1', 'v2');
      expect(
        projectOf(<CircuitComponent>[motor], <CircuitWire>[bridge]).validate,
        returnsNormally,
      );
      expect(
        () => projectOf(
          <CircuitComponent>[motor],
          <CircuitWire>[connection('bad', 'm1', 'u2', 'm1', 'u2')],
        ),
        throwsFormatException,
      );
    });
  });

  group('Connections and routing', () {
    test('duplicate and PE mismatch are explained and rejected', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g3', ComponentKind.threePhaseSupply),
          device('m1', ComponentKind.motor3Phase),
        ],
        <CircuitWire>[connection('pe', 'g3', 'pe', 'm1', 'earth')],
      );
      expect(
        ConnectionValidator.validate(
          project,
          const TerminalRef(componentId: 'g3', terminalId: 'pe'),
          const TerminalRef(componentId: 'm1', terminalId: 'earth'),
        )?.code,
        'duplicate',
      );
      expect(
        ConnectionValidator.validate(
          project,
          const TerminalRef(componentId: 'g3', terminalId: 'l1'),
          const TerminalRef(componentId: 'm1', terminalId: 'earth'),
        )?.code,
        'earth_mismatch',
      );
    });

    test('orthogonal route has clean points and exact terminal endpoints', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply, x: 50, y: 50),
          device('x1', ComponentKind.terminalBlock, x: 600, y: 400),
        ],
        <CircuitWire>[connection('w1', 'g1', 'positive', 'x1', 'a')],
      );
      final points = WireRouter.route(project, project.wires.single);
      expect(points.first,
          BoardGeometry.terminalPosition(project.components[0], 'positive'));
      expect(points.last,
          BoardGeometry.terminalPosition(project.components[1], 'a'));
      expect(points.toSet().length, points.length);
      expect(points.length, greaterThanOrEqualTo(2));
    });

    test('automatic orthogonal routing detours around another device', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply, x: 50, y: 100),
          device('k1', ComponentKind.contactor, x: 300, y: 60),
          device('x1', ComponentKind.terminalBlock, x: 600, y: 100),
        ],
        <CircuitWire>[connection('w1', 'g1', 'positive', 'x1', 'a')],
      );
      final points = WireRouter.route(project, project.wires.single);
      expect(points.length, greaterThanOrEqualTo(4));
      expect(
        points.any((point) => point.y < 60 || point.y > 218),
        isTrue,
        reason: 'The selected channel should leave the contactor bounding box.',
      );
    });

    test('wire sizing uses declared conditions and exposes disclaimer', () {
      final normal = EducationalWireSizing.suggest(
        const WireSizingInput(
          expectedCurrent: 10,
          material: ConductorMaterial.copper,
          usage: CableUsage.power,
          ambientTemperature: 30,
          groupedInConduit: false,
        ),
      );
      final derated = EducationalWireSizing.suggest(
        const WireSizingInput(
          expectedCurrent: 10,
          material: ConductorMaterial.aluminum,
          usage: CableUsage.power,
          ambientTemperature: 45,
          groupedInConduit: true,
        ),
      );
      expect(normal, isNotNull);
      expect(derated, isNotNull);
      expect(derated!.sectionMm2, greaterThan(normal!.sectionMm2));
      expect(derated.disclaimerAr, contains('ليس'));
      expect(
        EducationalWireSizing.suggest(
          const WireSizingInput(
            expectedCurrent: -2,
            material: ConductorMaterial.copper,
            usage: CableUsage.power,
            ambientTemperature: 30,
            groupedInConduit: false,
          ),
        ),
        isNull,
      );
    });
  });
}
