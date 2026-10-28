import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  test('building switches and intermediate crossover drive a real lamp path',
      () {
    var project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device(
          's1',
          ComponentKind.lightSwitch,
          overrides: const <String, Object>{'closed': true},
        ),
        device('s2', ComponentKind.twoWaySwitch),
        device('s3', ComponentKind.intermediateSwitch),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 's1', 'input'),
        connection('w2', 's1', 'output', 's2', 'common'),
        connection('w3', 's2', 'out1', 's3', 'in1'),
        connection('w4', 's3', 'out1', 'h1', 'x1'),
        connection('w5', 'h1', 'x2', 'g1', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result['h1']!.active, isTrue);
    project = setProperty(project, 's3', 'crossed', true);
    result = simulator.step(project);
    expect(result['h1']!.active, isFalse);
    project = setProperty(project, 's2', 'position', 2);
    project = setProperty(project, 's3', 'crossed', false);
    project = project.copyWith(
      wires: project.wires
          .map(
            (wire) => wire.id == 'w3'
                ? wire.copyWith(
                    from: const TerminalRef(
                      componentId: 's2',
                      terminalId: 'out2',
                    ),
                  )
                : wire,
          )
          .toList(growable: false),
    );
    result = simulator.step(project);
    expect(result['h1']!.active, isTrue);
  });

  test('three-wire PNP sensors energize a coil only in the active state', () {
    for (final kind in <ComponentKind>[
      ComponentKind.proximitySensor,
      ComponentKind.capacitiveSensor,
      ComponentKind.photoelectricSensor,
    ]) {
      var project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device('b1', kind),
          device('k1', ComponentKind.contactor),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'b1', 'positive'),
          connection('w2', 'b1', 'negative', 'g1', 'negative'),
          connection('w3', 'b1', 'output', 'k1', 'a1'),
          connection('w4', 'k1', 'a2', 'g1', 'negative'),
        ],
      );
      final simulator = ElectricalSimulator();
      var result = simulator.step(project);
      expect(result['k1']!.energized, isFalse, reason: kind.name);
      project = setProperty(project, 'b1', 'active', true);
      result = simulator.step(project);
      expect(result['k1']!.energized, isTrue, reason: kind.name);
      expect(result['k1']!.voltage, greaterThan(20), reason: kind.name);
    }
  });

  test('impulse relay toggles on rising edges and retains its output', () {
    var project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('g2', ComponentKind.dcSupply),
        device('s1', ComponentKind.pushButtonNO),
        device('ka1', ComponentKind.impulseRelay),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 's1', 'input'),
        connection('w2', 's1', 'output', 'ka1', 'a1'),
        connection('w3', 'ka1', 'a2', 'g1', 'negative'),
        connection('w4', 'g2', 'positive', 'ka1', 'common'),
        connection('w5', 'ka1', 'no', 'h1', 'x1'),
        connection('w6', 'h1', 'x2', 'g2', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result['h1']!.active, isFalse);
    project = setProperty(project, 's1', 'pressed', true);
    result = simulator.step(project);
    expect(result['ka1']!.active, isTrue);
    expect(result['h1']!.active, isTrue);
    project = setProperty(project, 's1', 'pressed', false);
    result = simulator.step(project);
    expect(result['ka1']!.active, isTrue);
    expect(result['h1']!.active, isTrue);
    project = setProperty(project, 's1', 'pressed', true);
    result = simulator.step(project);
    expect(result['ka1']!.active, isFalse);
    expect(result['h1']!.active, isFalse);
  });

  test('thermostat applies heating hysteresis to its contact', () {
    var project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('th1', ComponentKind.thermostat),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 'th1', 'input'),
        connection('w2', 'th1', 'output', 'h1', 'x1'),
        connection('w3', 'h1', 'x2', 'g1', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(project);
    expect(result['h1']!.active, isTrue);
    project = setProperty(project, 'th1', 'temperature', 23.0);
    result = simulator.step(project);
    expect(result['h1']!.active, isFalse);
    project = setProperty(project, 'th1', 'temperature', 21.5);
    result = simulator.step(project);
    expect(result['h1']!.active, isFalse, reason: 'Inside hysteresis band.');
    project = setProperty(project, 'th1', 'temperature', 20.5);
    result = simulator.step(project);
    expect(result['h1']!.active, isTrue);
  });

  test('phase relay detects phase loss and reversed sequence', () {
    final base = projectOf(
      <CircuitComponent>[
        device('g3', ComponentKind.threePhaseSupply),
        device('g1', ComponentKind.dcSupply),
        device('qr1', ComponentKind.phaseRelay),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g3', 'l1', 'qr1', 'l1'),
        connection('w2', 'g3', 'l2', 'qr1', 'l2'),
        connection('w3', 'g3', 'l3', 'qr1', 'l3'),
        connection('w4', 'g1', 'positive', 'qr1', 'common'),
        connection('w5', 'qr1', 'no', 'h1', 'x1'),
        connection('w6', 'h1', 'x2', 'g1', 'negative'),
      ],
    );
    final simulator = ElectricalSimulator();
    var result = simulator.step(base);
    expect(result['qr1']!.energized, isTrue);
    expect(result['h1']!.active, isTrue);

    final missing = base.copyWith(
      wires: base.wires.where((wire) => wire.id != 'w3').toList(),
    );
    result = simulator.step(missing);
    expect(result['qr1']!.energized, isFalse);
    expect(result['h1']!.active, isFalse);
    expect(
      result.diagnostics.any((item) => item.code == 'phase_relay_fault'),
      isTrue,
    );

    final reversed = base.copyWith(
      wires: <CircuitWire>[
        ...base.wires.where((wire) => wire.id != 'w2' && wire.id != 'w3'),
        connection('w2', 'g3', 'l2', 'qr1', 'l3'),
        connection('w3', 'g3', 'l3', 'qr1', 'l2'),
      ],
    );
    result = simulator.step(reversed);
    expect(result['qr1']!.energized, isFalse);
    expect(result['h1']!.active, isFalse);
  });

  test('current transformer solves 100/5 ratio and secondary burden voltage',
      () {
    final project = projectOf(
      <CircuitComponent>[
        device(
          'g1',
          ComponentKind.acSupply,
          overrides: const <String, Object>{'voltage': 230.0},
        ),
        device('ct1', ComponentKind.currentTransformer),
        device(
          'h1',
          ComponentKind.indicator,
          overrides: const <String, Object>{
            'ratedVoltage': 230.0,
            'powerWatts': 2300.0,
          },
        ),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'line', 'ct1', 'p1'),
        connection('w2', 'ct1', 'p2', 'h1', 'x1'),
        connection('w3', 'h1', 'x2', 'g1', 'neutral'),
      ],
    );
    final result = ElectricalSimulator().step(project);
    expect(result.success, isTrue);
    expect(result['ct1']!.current, closeTo(10, 0.15));
    expect(result['ct1']!.secondaryCurrent, closeTo(0.5, 0.02));
    expect(result['ct1']!.voltage, closeTo(1, 0.06));
    expect(result['ct1']!.measurementValid, isTrue);
  });

  test('wattmeter frequency meter and VT measure the solved AC network', () {
    final project = projectOf(
      <CircuitComponent>[
        device(
          'g1',
          ComponentKind.acSupply,
          overrides: const <String, Object>{'voltage': 230.0},
        ),
        device('p1', ComponentKind.wattmeter),
        device('f1', ComponentKind.frequencyMeter),
        device('vt1', ComponentKind.voltageTransformer),
        device('h1', ComponentKind.ledLamp),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'line', 'p1', 'currentIn'),
        connection('w2', 'p1', 'currentOut', 'h1', 'line'),
        connection('w3', 'h1', 'neutral', 'g1', 'neutral'),
        connection('w4', 'p1', 'voltageL', 'h1', 'line'),
        connection('w5', 'p1', 'voltageN', 'h1', 'neutral'),
        connection('w6', 'f1', 'positive', 'h1', 'line'),
        connection('w7', 'f1', 'negative', 'h1', 'neutral'),
        connection('w8', 'g1', 'line', 'vt1', 'primaryLine'),
        connection('w9', 'g1', 'neutral', 'vt1', 'primaryNeutral'),
      ],
    );
    final result = ElectricalSimulator().step(project);
    expect(result.success, isTrue);
    expect(result['h1']!.active, isTrue);
    expect(result['p1']!.activePower, closeTo(12, 0.2));
    expect(result['p1']!.measurementValid, isTrue);
    expect(result['f1']!.frequency, 50);
    expect(result['f1']!.measurementValid, isTrue);
    expect(result['vt1']!.voltage, closeTo(100, 0.2));
    expect(result['vt1']!.active, isTrue);
  });

  test('RCCB trips residual current without pretending to be an MCB', () {
    final base = projectOf(
      <CircuitComponent>[
        device(
          'g1',
          ComponentKind.acSupply,
          overrides: const <String, Object>{'voltage': 230.0},
        ),
        device('q1', ComponentKind.rccb2P),
        device(
          'h1',
          ComponentKind.indicator,
          overrides: const <String, Object>{
            'ratedVoltage': 230.0,
            'powerWatts': 2300.0,
          },
        ),
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
    expect(result['q1']!.tripped, isFalse,
        reason: 'No residual or overcurrent model in RCCB.');
    expect(result['h1']!.active, isTrue);
    final faulted = base.copyWith(
      components: <CircuitComponent>[
        ...base.components,
        device(
          'h2',
          ComponentKind.indicator,
          overrides: const <String, Object>{
            'ratedVoltage': 230.0,
            'powerWatts': 100.0,
          },
        ),
      ],
      wires: <CircuitWire>[
        ...base.wires,
        connection('w5', 'q1', 'lineOut', 'h2', 'x1'),
        connection('w6', 'h2', 'x2', 'g1', 'neutral'),
      ],
    );
    result = simulator.step(faulted);
    expect(result['q1']!.tripped, isTrue);
    expect(
      result.diagnostics.any((item) => item.code == 'differential_trip'),
      isTrue,
    );
  });

  test('cable and feed-through accessories use calculated resistance and buses',
      () {
    final project = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.dcSupply),
        device('cb1', ComponentKind.cableSegment),
        device('x1', ComponentKind.distributionBlock),
        device('n1', ComponentKind.neutralBar),
        device('h1', ComponentKind.indicator),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'positive', 'cb1', 'a'),
        connection('w2', 'cb1', 'b', 'x1', 'a'),
        connection('w3', 'x1', 'return', 'h1', 'x1'),
        connection('w4', 'h1', 'x2', 'n1', 'a'),
        connection('w5', 'n1', 'return', 'g1', 'negative'),
      ],
    );
    final result = ElectricalSimulator().step(project);
    expect(result.success, isTrue);
    expect(result['h1']!.active, isTrue);
    expect(result['cb1']!.current, greaterThan(0.08));
    expect(
      result['cb1']!.voltage / result['cb1']!.current,
      closeTo(0.07, 0.0001),
    );
  });
}
