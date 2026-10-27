import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('Protection and faults', () {
    test('short circuit trips MCB and remains tripped until explicit reset', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device(
            'q1',
            ComponentKind.circuitBreaker,
            overrides: const <String, Object>{'ratedCurrent': 10.0},
          ),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'q1', 'line'),
          connection('w2', 'q1', 'load', 'g1', 'negative'),
        ],
      );
      final simulator = ElectricalSimulator();
      var result = simulator.step(project);
      expect(result['q1']!.tripped, isTrue);
      expect(result['q1']!.current, closeTo(0, 1e-6));
      expect(result.diagnostics.any((item) => item.code == 'breaker_trip'), isTrue);

      simulator.resetProtection('q1');
      result = simulator.step(project);
      expect(result['q1']!.tripped, isTrue, reason: 'The short is still present.');
    });

    test('fuse blows under severe overcurrent and opens the path', () {
      final project = projectOf(
        <CircuitComponent>[
          device('g1', ComponentKind.dcSupply),
          device(
            'fu1',
            ComponentKind.fuse,
            overrides: const <String, Object>{'ratedCurrent': 0.01},
          ),
          device('h1', ComponentKind.indicator),
        ],
        <CircuitWire>[
          connection('w1', 'g1', 'positive', 'fu1', 'line'),
          connection('w2', 'fu1', 'load', 'h1', 'x1'),
          connection('w3', 'h1', 'x2', 'g1', 'negative'),
        ],
      );
      final result = ElectricalSimulator().step(project);
      expect(result['fu1']!.blown, isTrue);
      expect(result['h1']!.active, isFalse);
      expect(result.diagnostics.any((item) => item.code == 'fuse_blown'), isTrue);
    });

    test('thermal relay accumulates overload, trips, and drops contactor coil', () {
      final empty = ElectricalProject.empty(
        id: 'thermal',
        name: 'Thermal',
        now: testNow,
      );
      final project = ProjectTemplates.apply(empty, ProjectTemplateKind.motorProtection);
      final simulator = ElectricalSimulator();
      var result = simulator.step(project);
      expect(result['m1']!.active, isTrue);
      expect(result['k1']!.energized, isTrue);
      var sawTripDiagnostic = false;
      for (var index = 0; index < 120; index++) {
        result = simulator.step(project);
        sawTripDiagnostic = sawTripDiagnostic ||
            result.diagnostics.any((item) => item.code == 'thermal_trip');
      }
      expect(result['f2']!.tripped, isTrue);
      expect(result['k1']!.energized, isFalse);
      expect(result['m1']!.active, isFalse);
      expect(sawTripDiagnostic, isTrue);
    });
  });

  group('Balanced three-phase motor model', () {
    ElectricalProject directMotor() => projectOf(
          <CircuitComponent>[
            device('g3', ComponentKind.threePhaseSupply),
            device('m1', ComponentKind.motor3Phase),
          ],
          <CircuitWire>[
            connection('w1', 'g3', 'l1', 'm1', 'u'),
            connection('w2', 'g3', 'l2', 'm1', 'v'),
            connection('w3', 'g3', 'l3', 'm1', 'w'),
            connection('pe', 'g3', 'pe', 'm1', 'earth'),
          ],
        );

    test('calculates approximately nominal phase current and forward sequence', () {
      final result = ElectricalSimulator().step(directMotor());
      expect(result.success, isTrue);
      expect(result['m1']!.active, isTrue);
      expect(result['m1']!.direction, 1);
      expect(result['m1']!.voltage, closeTo(400, 1));
      expect(result['m1']!.current, closeTo(2, 0.03));
      expect(result['m1']!.activePower, greaterThan(900));
      expect(result.diagnostics.any((item) => item.code == 'motor_running'), isTrue);
    });

    test('swapping two phases reverses calculated phase sequence', () {
      final original = directMotor();
      final reversed = original.copyWith(
        wires: <CircuitWire>[
          connection('w1', 'g3', 'l1', 'm1', 'u'),
          connection('w2', 'g3', 'l2', 'm1', 'w'),
          connection('w3', 'g3', 'l3', 'm1', 'v'),
          connection('pe', 'g3', 'pe', 'm1', 'earth'),
        ],
      );
      final result = ElectricalSimulator().step(reversed);
      expect(result['m1']!.active, isTrue);
      expect(result['m1']!.direction, -1);
    });

    test('loss of one phase stops the motor and explains the problem', () {
      final project = directMotor().copyWith(
        wires: directMotor().wires.where((wire) => wire.id != 'w3').toList(),
      );
      final result = ElectricalSimulator().step(project);
      expect(result['m1']!.active, isFalse);
      expect(result.diagnostics.any((item) => item.code == 'motor_phase_problem'), isTrue);
    });

    test('identical circuits produce reproducible values', () {
      final first = ElectricalSimulator().step(directMotor());
      final second = ElectricalSimulator().step(directMotor());
      expect(first['m1']!.voltage, closeTo(second['m1']!.voltage, 1e-10));
      expect(first['m1']!.current, closeTo(second['m1']!.current, 1e-10));
      expect(first['m1']!.activePower, closeTo(second['m1']!.activePower, 1e-10));
    });
  });
}
