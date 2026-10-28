import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  ElectricalProject template(ProjectTemplateKind kind) =>
      ProjectTemplates.apply(
        ElectricalProject.empty(
          id: 'starter_${kind.name}',
          name: kind.name,
          now: testNow,
        ),
        kind,
      );

  test('DOL starts only with START, holds, solves delta current and stops', () {
    var project = template(ProjectTemplateKind.directOnLine);
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result.success, isTrue);
    expect(result['km1']!.energized, isFalse);
    expect(result['m1']!.active, isFalse);

    project = setProperty(project, 's1', 'pressed', true);
    result = simulator.step(project);
    expect(result['km1']!.energized, isTrue);
    expect(result['m1']!.active, isTrue);
    expect(result['m1']!.connectionMode, 'delta');
    expect(result['m1']!.direction, 1);
    expect(result['m1']!.current, closeTo(2, 0.12));
    expect(result['m1']!.activePower, greaterThan(900));

    project = setProperty(project, 's1', 'pressed', false);
    result = simulator.step(project);
    expect(result['km1']!.energized, isTrue, reason: 'NO 13/14 must seal in.');
    expect(result['m1']!.active, isTrue);

    project = setProperty(project, 's0', 'pressed', true);
    result = simulator.step(project);
    expect(result['km1']!.energized, isFalse);
    expect(result['m1']!.active, isFalse);
  });

  test('star-delta transfers from real star to delta after the ON delay', () {
    var project = template(ProjectTemplateKind.starDelta);
    final simulator = ElectricalSimulator();
    project = setProperty(project, 's1', 'pressed', true);
    var result = simulator.step(project);
    expect(result.success, isTrue);
    expect(result['km1']!.energized, isTrue);
    expect(result['km2']!.energized, isTrue, reason: 'Star coil before delay.');
    expect(result['km3']!.energized, isFalse,
        reason: 'Delta NO is still open.');
    expect(result['m1']!.active, isTrue);
    expect(result['m1']!.connectionMode, 'star');
    expect(result['m1']!.current, closeTo(2 / 3, 0.12));
    final starCurrent = result['m1']!.current;

    project = setProperty(project, 's1', 'pressed', false);
    result = simulator.step(project);
    expect(result['km1']!.energized, isTrue,
        reason: 'Main contactor seals in.');
    expect(result['km2']!.energized, isTrue);

    for (var index = 0; index < 32; index++) {
      result = simulator.step(project);
    }
    expect(result['kt1']!.active, isTrue);
    expect(result['km2']!.energized, isFalse, reason: 'Timer NC opens star.');
    expect(result['km3']!.energized, isTrue,
        reason: 'Timer NO energizes delta.');
    expect(result['m1']!.active, isTrue);
    expect(result['m1']!.connectionMode, 'delta');
    expect(result['m1']!.current, greaterThan(starCurrent * 2.5));
    expect(result['m1']!.current, closeTo(2, 0.15));
    expect(
      result.diagnostics.any((item) => item.code == 'interlock_conflict'),
      isFalse,
    );

    project = setProperty(project, 's0', 'pressed', true);
    result = simulator.step(project);
    expect(result['km1']!.energized, isFalse);
    expect(result['km2']!.energized, isFalse);
    expect(result['km3']!.energized, isFalse);
    expect(result['m1']!.active, isFalse);
  });

  test('six-lead phase loss is diagnosed instead of showing fake rotation', () {
    var project = template(ProjectTemplateKind.directOnLine);
    project = setProperty(project, 's1', 'pressed', true);
    final simulator = ElectricalSimulator();
    final running = simulator.step(project);
    expect(running['m1']!.active, isTrue);
    project = project.copyWith(
      wires: project.wires
          .where(
            (wire) => !(wire.from.componentId == 'f2' &&
                wire.from.terminalId == 't3' &&
                wire.to.componentId == 'm1' &&
                wire.to.terminalId == 'w1'),
          )
          .toList(growable: false),
    );
    final result = simulator.step(project);
    expect(result['m1']!.active, isFalse);
    expect(
      result.diagnostics.any((item) => item.code == 'motor_phase_problem'),
      isTrue,
    );
  });

  test('mechanical interlock blocks power contacts only for assigned instances',
      () {
    const starAssignment = <String, Object>{
      'interlockGroup': 'test_pair',
      'interlockRole': 'star',
    };
    const deltaAssignment = <String, Object>{
      'interlockGroup': 'test_pair',
      'interlockRole': 'delta',
    };
    var project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('g2', ComponentKind.dcSupply),
        device('g3', ComponentKind.dcSupply),
        device('km2', ComponentKind.contactor, overrides: starAssignment),
        device('km3', ComponentKind.contactor, overrides: deltaAssignment),
        device('h1', ComponentKind.indicator),
        device('h2', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('c1', 'g1', 'positive', 'km2', 'a1'),
        connection('c2', 'km2', 'a2', 'g1', 'negative'),
        connection('c3', 'g2', 'positive', 'km3', 'a1'),
        connection('c4', 'km3', 'a2', 'g2', 'negative'),
        connection('p1', 'g3', 'positive', 'km2', 'l1'),
        connection('p2', 'g3', 'positive', 'km3', 'l1'),
        connection('p3', 'km2', 't1', 'h1', 'x1'),
        connection('p4', 'km3', 't1', 'h2', 'x1'),
        connection('p5', 'h1', 'x2', 'g3', 'negative'),
        connection('p6', 'h2', 'x2', 'g3', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result.success, isTrue);
    expect(result['km2']!.energized, isTrue);
    expect(result['km3']!.energized, isTrue);
    expect(result['h1']!.active, isFalse,
        reason: 'Star power is mechanically blocked.');
    expect(result['h2']!.active, isFalse,
        reason: 'Delta power is mechanically blocked.');
    expect(
      result.diagnostics.any((item) => item.code == 'interlock_conflict'),
      isTrue,
    );

    final dangling = project.copyWith(
      components: project.components
          .where((component) => component.id != 'km3')
          .toList(growable: false),
      wires: project.wires
          .where(
            (wire) =>
                wire.from.componentId != 'km3' && wire.to.componentId != 'km3',
          )
          .toList(growable: false),
    );
    result = simulator.step(dangling);
    expect(result['h1']!.active, isFalse,
        reason: 'Invalid groups fail safe open.');
    expect(
      result.diagnostics.any((item) => item.code == 'interlock_config'),
      isTrue,
    );

    project = setProperty(project, 'g2', 'enabled', false);
    result = simulator.step(project);
    expect(result['km3']!.energized, isFalse);
    expect(result['h1']!.active, isTrue);
    expect(result['h2']!.active, isFalse);

    // Same ComponentKind, but no per-instance assignment: no inherited group,
    // no false conflict, and both power paths are allowed to close.
    project = project.copyWith(
      components: project.components.map((component) {
        if (component.id != 'km2' && component.id != 'km3') return component;
        return component.copyWith(
          properties: <String, Object>{
            ...component.properties,
            'interlockGroup': '',
            'interlockRole': '',
          },
        );
      }).toList(growable: false),
    );
    project.validate();
    project = setProperty(project, 'g2', 'enabled', true);
    result = simulator.step(project);
    expect(result['km2']!.energized, isTrue);
    expect(result['km3']!.energized, isTrue);
    expect(result['h1']!.active, isTrue);
    expect(result['h2']!.active, isTrue);
    expect(
      result.diagnostics.any((item) => item.code == 'interlock_conflict'),
      isFalse,
    );
  });
}
