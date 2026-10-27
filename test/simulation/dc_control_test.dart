import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('DC load and measurements', () {
    test('push button controls calculated lamp current and light', () {
      final empty = ElectricalProject.empty(
        id: 'dc_lamp',
        name: 'DC lamp',
        now: testNow,
      );
      var project = ProjectTemplates.apply(empty, ProjectTemplateKind.dcLamp);
      final simulator = ElectricalSimulator();
      var result = simulator.step(project);
      expect(result.success, isTrue);
      expect(result['h1']!.active, isFalse);
      expect(result['h1']!.current, closeTo(0, 1e-6));

      project = setProperty(project, 's1', 'pressed', true);
      result = simulator.step(project);
      expect(result['h1']!.active, isTrue);
      expect(result['h1']!.voltage, greaterThan(20));
      expect(result['h1']!.current, closeTo(24 / 288, 0.002));
      expect(result['h1']!.activePower, greaterThan(1.5));
      expect(result.wireCurrents.values.every((current) => current > 0.07), isTrue);

      project = setProperty(project, 's1', 'pressed', false);
      result = simulator.step(project);
      expect(result['h1']!.active, isFalse);
      expect(result['h1']!.current, closeTo(0, 1e-6));
    });

    test('voltmeter and ammeter follow the same MNA solution', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device('h1', ComponentKind.indicator),
          device('a1', ComponentKind.ammeter),
          device('v1', ComponentKind.voltmeter),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'a1', 'positive'),
          connection('w2', 'a1', 'negative', 'h1', 'x1'),
          connection('w3', 'h1', 'x2', 'g1', 'negative'),
          connection('w4', 'v1', 'positive', 'h1', 'x1'),
          connection('w5', 'v1', 'negative', 'h1', 'x2'),
        ],
      );
      final result = ElectricalSimulator().step(project);
      expect(result.success, isTrue);
      expect(result['v1']!.measurementValid, isTrue);
      expect(result['a1']!.measurementValid, isTrue);
      expect(result['v1']!.voltage, closeTo(result['h1']!.voltage, 1e-6));
      expect(result['a1']!.current, closeTo(result['h1']!.current, 1e-6));
      expect(result['v1']!.voltage, greaterThan(20));
    });

    test('parallel ammeter is marked invalid', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device('a1', ComponentKind.ammeter),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'a1', 'positive'),
          connection('w2', 'a1', 'negative', 'g1', 'negative'),
        ],
      );
      final result = ElectricalSimulator().step(project);
      expect(result['a1']!.measurementValid, isFalse);
      expect(result['a1']!.current, greaterThan(10));
      expect(result.diagnostics.any((item) => item.code == 'invalid_measurement'), isTrue);
    });

    test('series voltmeter is marked invalid by alternate-path analysis', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device('v1', ComponentKind.voltmeter),
          device('h1', ComponentKind.indicator),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'v1', 'positive'),
          connection('w2', 'v1', 'negative', 'h1', 'x1'),
          connection('w3', 'h1', 'x2', 'g1', 'negative'),
        ],
      );
      final result = ElectricalSimulator().step(project);
      expect(result['v1']!.measurementValid, isFalse);
      expect(result['h1']!.active, isFalse);
      expect(result.diagnostics.any((item) => item.code == 'invalid_measurement'), isTrue);
    });

    test('open fault removes current without changing the model to a fake value', () {
      var project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device('h1', ComponentKind.indicator),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'h1', 'x1'),
          connection('w2', 'h1', 'x2', 'g1', 'negative'),
        ],
      );
      project = setProperty(project, 'h1', 'fault', 'open');
      final result = ElectricalSimulator().step(project);
      expect(result['h1']!.current, closeTo(0, 1e-8));
      expect(result['h1']!.active, isFalse);
      expect(result.diagnostics.any((item) => item.code == 'injected_open'), isTrue);
    });
  });

  group('Contactor, self-holding and timer', () {
    test('contactor picks up, self-holds after release, and drops with Stop NC', () {
      final empty = ElectricalProject.empty(
        id: 'holding',
        name: 'Holding',
        now: testNow,
      );
      var project = ProjectTemplates.apply(empty, ProjectTemplateKind.selfHolding);
      final simulator = ElectricalSimulator();
      var result = simulator.step(project);
      expect(result['k1']!.energized, isFalse);

      project = setProperty(project, 's1', 'pressed', true);
      result = simulator.step(project);
      expect(result['k1']!.energized, isTrue);
      expect(result['h1']!.active, isTrue);

      project = setProperty(project, 's1', 'pressed', false);
      result = simulator.step(project);
      expect(result['k1']!.energized, isTrue, reason: '13/14 must maintain the coil');
      expect(result['h1']!.active, isTrue);

      project = setProperty(project, 's0', 'pressed', true);
      result = simulator.step(project);
      expect(result['k1']!.energized, isFalse);
      expect(result['h1']!.active, isFalse);
    });

    test('coil open fault prevents pickup even with Start pressed', () {
      final empty = ElectricalProject.empty(
        id: 'coil_fault',
        name: 'Coil fault',
        now: testNow,
      );
      var project = ProjectTemplates.apply(empty, ProjectTemplateKind.selfHolding);
      project = setProperty(project, 'k1', 'fault', 'coilOpen');
      project = setProperty(project, 's1', 'pressed', true);
      final result = ElectricalSimulator().step(project);
      expect(result.success, isTrue);
      expect(result['k1']!.energized, isFalse);
      expect(result['k1']!.current, closeTo(0, 1e-8));
    });

    test('ON-delay timer uses explicit simulation time and resets on power loss', () {
      var project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device(
            'kt1',
            ComponentKind.timer,
            overrides: const <String, Object>{'delaySeconds': 0.5},
          ),
          device('h1', ComponentKind.indicator),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'kt1', 'a1'),
          connection('w2', 'kt1', 'a2', 'g1', 'negative'),
          connection('w3', 'g1', 'positive', 'kt1', 't15'),
          connection('w4', 'kt1', 't18', 'h1', 'x1'),
          connection('w5', 'h1', 'x2', 'g1', 'negative'),
        ],
      );
      final simulator = ElectricalSimulator();
      var result = simulator.step(project, deltaSeconds: 0.1);
      expect(result['kt1']!.energized, isTrue);
      expect(result['kt1']!.active, isFalse);
      expect(result['h1']!.active, isFalse);
      for (var index = 0; index < 6; index++) {
        result = simulator.step(project, deltaSeconds: 0.1);
      }
      expect(result['kt1']!.active, isTrue);
      expect(result['h1']!.active, isTrue);

      project = setProperty(project, 'g1', 'enabled', false);
      result = simulator.step(project, deltaSeconds: 0.1);
      expect(result['kt1']!.energized, isFalse);
      expect(result['kt1']!.active, isFalse);
      expect(result['h1']!.active, isFalse);
    });
  });
}
