import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/models/supply_bay.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  test('reserved supplies remain off until explicitly enabled', () {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'off', name: 'Off', now: testNow),
      ProjectTemplateKind.blank,
    );
    final result = ElectricalSimulator().step(project);
    for (final id in SupplyBay.ids) {
      expect(result[id]!.active, isFalse);
      expect(result[id]!.voltage, 0);
    }
    expect(
      result.diagnostics.any((item) => item.code == 'supply_disabled'),
      isTrue,
    );
  });

  test('transformer solves coupled ratio, secondary load and primary power', () {
    final project = projectOf(
      <CircuitComponent>[
        device(
          'g1',
          ComponentKind.acSupply,
          x: 40,
          y: 100,
          overrides: const <String, Object>{'voltage': 230.0},
        ),
        device('t1', ComponentKind.transformer, x: 280, y: 100),
        device('h1', ComponentKind.indicator, x: 520, y: 100),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'line', 't1', 'primaryLine'),
        connection('w2', 'g1', 'neutral', 't1', 'primaryNeutral'),
        connection('w3', 't1', 'secondaryLine', 'h1', 'x1'),
        connection('w4', 't1', 'secondaryNeutral', 'h1', 'x2'),
      ],
    );
    final result = ElectricalSimulator().step(project);
    expect(result.success, isTrue);
    expect(result['t1']!.voltage, closeTo(23.99, 0.03));
    expect(result['t1']!.current, greaterThan(0.08));
    expect(result['t1']!.activePower, greaterThan(1.8));
    expect(result['h1']!.active, isTrue);
  });

  test('OFF-delay keeps an independently powered output then opens after delay', () {
    var project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('g2', ComponentKind.dcSupply),
        device(
          'kt1',
          ComponentKind.timerOffDelay,
          overrides: const <String, Object>{'delaySeconds': 0.5},
        ),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 'kt1', 'a1'),
        connection('w2', 'kt1', 'a2', 'g1', 'negative'),
        connection('w3', 'g2', 'positive', 'kt1', 't15'),
        connection('w4', 'kt1', 't18', 'h1', 'x1'),
        connection('w5', 'h1', 'x2', 'g2', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project, deltaSeconds: 0.1);
    expect(result['kt1']!.energized, isTrue);
    expect(result['kt1']!.active, isTrue);
    expect(result['h1']!.active, isTrue);

    project = setProperty(project, 'g1', 'enabled', false);
    result = simulator.step(project, deltaSeconds: 0.1);
    expect(result['kt1']!.energized, isFalse);
    expect(result['kt1']!.active, isTrue);
    expect(result['kt1']!.timerRemaining, greaterThan(0.3));
    expect(result['h1']!.active, isTrue);

    for (var index = 0; index < 5; index++) {
      result = simulator.step(project, deltaSeconds: 0.1);
    }
    expect(result['kt1']!.active, isFalse);
    expect(result['h1']!.active, isFalse);
  });

  test('differential breaker measures residual current and trips on neutral bypass', () {
    final base = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.acSupply),
        device('q1', ComponentKind.differentialBreaker),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'line', 'q1', 'lineIn'),
        connection('w2', 'q1', 'lineOut', 'h1', 'x1'),
        connection('w3', 'h1', 'x2', 'q1', 'neutralOut'),
        connection('w4', 'q1', 'neutralIn', 'g1', 'neutral'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(base);
    expect(result['q1']!.tripped, isFalse);
    expect(result['q1']!.residualCurrent, lessThan(0.001));
    expect(result['h1']!.active, isTrue);

    final faulted = base.copyWith(
      components: <CircuitComponent>[
        ...base.components,
        device('h2', ComponentKind.indicator),
      ],
      wires: <CircuitWire>[
        ...base.wires,
        connection('w5', 'q1', 'lineOut', 'h2', 'x1'),
        connection('w6', 'h2', 'x2', 'g1', 'neutral'),
      ],
    );
    result = simulator.step(faulted);
    expect(result['q1']!.tripped, isTrue);
    expect(result['h1']!.active, isFalse);
    expect(result['h2']!.active, isFalse);
    expect(
      result.diagnostics.any((item) => item.code == 'differential_trip'),
      isTrue,
    );
  });

  test('single-phase motor and motor breaker use solved current', () {
    final running = projectOf(
      <CircuitComponent>[
        device(
          'g1',
          ComponentKind.acSupply,
          overrides: const <String, Object>{'voltage': 230.0},
        ),
        device('m1', ComponentKind.motor1Phase),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'line', 'm1', 'u'),
        connection('w2', 'm1', 'v', 'g1', 'neutral'),
      ],
    );
    final motor = ElectricalSimulator().step(running);
    expect(motor['m1']!.active, isTrue);
    expect(motor['m1']!.voltage, closeTo(230, 1));
    expect(motor['m1']!.current, closeTo(2, 0.03));

    final protectedMotor = projectOf(
      <CircuitComponent>[
        device('g3', ComponentKind.threePhaseSupply),
        device(
          'q1',
          ComponentKind.motorBreaker,
          overrides: const <String, Object>{'ratedCurrent': 0.1},
        ),
        device('m1', ComponentKind.motor3Phase),
      ],
      <CircuitWire>[
        connection('w1', 'g3', 'l1', 'q1', 'l1'),
        connection('w2', 'g3', 'l2', 'q1', 'l2'),
        connection('w3', 'g3', 'l3', 'q1', 'l3'),
        connection('w4', 'q1', 't1', 'm1', 'u'),
        connection('w5', 'q1', 't2', 'm1', 'v'),
        connection('w6', 'q1', 't3', 'm1', 'w'),
      ],
    );
    final protection = ElectricalSimulator().step(protectedMotor);
    expect(protection['q1']!.tripped, isTrue);
    expect(protection['m1']!.active, isFalse);
    expect(
      protection.diagnostics.any((item) => item.code == 'motor_breaker_trip'),
      isTrue,
    );
  });

  test('emergency stop and three-position rotary switch drive real contacts', () {
    var emergency = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('s0', ComponentKind.emergencyStop),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 's0', 'input'),
        connection('w2', 's0', 'output', 'h1', 'x1'),
        connection('w3', 'h1', 'x2', 'g1', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(emergency);
    expect(result['h1']!.active, isTrue);
    emergency = setProperty(emergency, 's0', 'closed', false);
    result = simulator.step(emergency);
    expect(result['h1']!.active, isFalse);

    var rotary = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device(
          'sa1',
          ComponentKind.rotarySwitch,
          overrides: const <String, Object>{'position': 1},
        ),
        device('h1', ComponentKind.indicator),
        device('h2', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 'sa1', 'common'),
        connection('w2', 'sa1', 'out1', 'h1', 'x1'),
        connection('w3', 'sa1', 'out2', 'h2', 'x1'),
        connection('w4', 'h1', 'x2', 'g1', 'negative'),
        connection('w5', 'h2', 'x2', 'g1', 'negative'),
      ],
    );
    result = ElectricalSimulator().step(rotary);
    expect(result['h1']!.active, isTrue);
    expect(result['h2']!.active, isFalse);
    rotary = setProperty(rotary, 'sa1', 'position', 2);
    result = ElectricalSimulator().step(rotary);
    expect(result['h1']!.active, isFalse);
    expect(result['h2']!.active, isTrue);
  });

  test('sensor, limit switch and selector form a real series control chain', () {
    var project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('b1', ComponentKind.sensor),
        device('b2', ComponentKind.limitSwitch),
        device('sa1', ComponentKind.selectorSwitch),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 'b1', 'input'),
        connection('w2', 'b1', 'output', 'b2', 'input'),
        connection('w3', 'b2', 'output', 'sa1', 'input'),
        connection('w4', 'sa1', 'output', 'h1', 'x1'),
        connection('w5', 'h1', 'x2', 'g1', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result['h1']!.active, isFalse);
    project = setProperty(project, 'b1', 'active', true);
    project = setProperty(project, 'b2', 'active', true);
    project = setProperty(project, 'sa1', 'closed', true);
    result = simulator.step(project);
    expect(result['h1']!.active, isTrue);
    project = setProperty(project, 'b2', 'active', false);
    result = simulator.step(project);
    expect(result['h1']!.active, isFalse);
  });

  test('Start Stop self-holding thermal relay motor and PE work together', () {
    var project = projectOf(
      <CircuitComponent>[
        device('g3', ComponentKind.threePhaseSupply),
        device('g1', ComponentKind.acSupply),
        device('s0', ComponentKind.pushButtonNC),
        device('s1', ComponentKind.pushButtonNO),
        device('k1', ComponentKind.contactor),
        device('f2', ComponentKind.thermalRelay),
        device('m1', ComponentKind.motor3Phase),
      ],
      <CircuitWire>[
        connection('p1', 'g3', 'l1', 'k1', 'l1'),
        connection('p2', 'g3', 'l2', 'k1', 'l2'),
        connection('p3', 'g3', 'l3', 'k1', 'l3'),
        connection('p4', 'k1', 't1', 'f2', 'l1'),
        connection('p5', 'k1', 't2', 'f2', 'l2'),
        connection('p6', 'k1', 't3', 'f2', 'l3'),
        connection('p7', 'f2', 't1', 'm1', 'u'),
        connection('p8', 'f2', 't2', 'm1', 'v'),
        connection('p9', 'f2', 't3', 'm1', 'w'),
        connection('pe', 'g3', 'pe', 'm1', 'earth'),
        connection('c1', 'g1', 'line', 's0', 'input', layer: 'control'),
        connection('c2', 's0', 'output', 'f2', 'nc95', layer: 'control'),
        connection('c3', 'f2', 'nc96', 's1', 'input', layer: 'control'),
        connection('c4', 's1', 'output', 'k1', 'a1', layer: 'control'),
        connection('c5', 'k1', 'a2', 'g1', 'neutral', layer: 'control'),
        connection('c6', 'f2', 'nc96', 'k1', 'aux13', layer: 'control'),
        connection('c7', 'k1', 'aux14', 's1', 'output', layer: 'control'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result['k1']!.energized, isFalse);
    expect(result['m1']!.active, isFalse);
    project = setProperty(project, 's1', 'pressed', true);
    result = simulator.step(project);
    expect(result['k1']!.energized, isTrue);
    expect(result['m1']!.active, isTrue);
    project = setProperty(project, 's1', 'pressed', false);
    result = simulator.step(project);
    expect(result['k1']!.energized, isTrue);
    expect(result['m1']!.active, isTrue);
    project = setProperty(project, 's0', 'pressed', true);
    result = simulator.step(project);
    expect(result['k1']!.energized, isFalse);
    expect(result['m1']!.active, isFalse);
  });

  test('digital counter integrates measured power into kWh', () {
    final project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('p1', ComponentKind.digitalCounter),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 'p1', 'currentIn'),
        connection('w2', 'p1', 'currentOut', 'h1', 'x1'),
        connection('w3', 'h1', 'x2', 'g1', 'negative'),
        connection('w4', 'p1', 'voltageL', 'h1', 'x1'),
        connection('w5', 'p1', 'voltageN', 'h1', 'x2'),
      ],
    );
    final simulator = ElectricalSimulator();
    final first = simulator.step(project, deltaSeconds: 1);
    expect(first['p1']!.measurementValid, isTrue);
    expect(first['p1']!.voltage, greaterThan(20));
    expect(first['p1']!.activePower, greaterThan(1.5));
    expect(first['p1']!.energyKwh, greaterThan(0));
    final second = simulator.step(project, deltaSeconds: 1);
    expect(second['p1']!.energyKwh, greaterThan(first['p1']!.energyKwh));
  });
}
