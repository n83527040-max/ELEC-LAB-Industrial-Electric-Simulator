import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/component_catalog.dart';
import 'package:elec_lab/src/models/component_catalog_extensions.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/wire.dart';
import 'package:elec_lab/src/simulation/electrical_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  test('catalog contains 41 unique extensions without replacing legacy motor',
      () {
    expect(ComponentKind.values, hasLength(68));
    expect(ExtendedComponentCatalog.byKind, hasLength(41));
    expect(ExtendedComponentCatalog.byKind.keys.toSet(), hasLength(41));
    expect(
      ComponentCatalog.specOf(ComponentKind.motor3Phase)
          .terminals
          .map((t) => t.id)
          .toSet(),
      <String>{'u', 'v', 'w', 'earth'},
    );
    expect(
      ComponentCatalog.specOf(ComponentKind.motor6Terminal)
          .terminals
          .map((t) => t.id)
          .toSet(),
      <String>{'u1', 'v1', 'w1', 'u2', 'v2', 'w2', 'earth'},
    );
  });

  test('every model has unique finite terminals and a solvable isolated stamp',
      () {
    for (final kind in ComponentKind.values) {
      final spec = ComponentCatalog.specOf(kind);
      expect(spec.terminals, isNotEmpty, reason: kind.name);
      expect(
        spec.terminals.map((terminal) => terminal.id).toSet(),
        hasLength(spec.terminals.length),
        reason: kind.name,
      );
      for (final terminal in spec.terminals) {
        expect(terminal.id, isNotEmpty, reason: kind.name);
        expect(terminal.position.x.isFinite, isTrue,
            reason: '${kind.name}/${terminal.id}');
        expect(terminal.position.y.isFinite, isTrue,
            reason: '${kind.name}/${terminal.id}');
      }
      for (final entry in spec.defaultProperties.entries) {
        final value = entry.value;
        if (value is num) {
          expect(value.isFinite, isTrue, reason: '${kind.name}/${entry.key}');
        }
      }
      final project = projectOf(
        <CircuitComponent>[device('dut', kind)],
        const <CircuitWire>[],
      );
      final result = ElectricalSimulator().step(project);
      expect(result.success, isTrue, reason: kind.name);
      final reading = result['dut'];
      expect(reading, isNotNull, reason: kind.name);
      expect(reading!.voltage.isFinite, isTrue, reason: kind.name);
      expect(reading.current.isFinite, isTrue, reason: kind.name);
      expect(reading.activePower.isFinite, isTrue, reason: kind.name);
      expect(reading.secondaryCurrent.isFinite, isTrue, reason: kind.name);
      expect(reading.frequency.isFinite, isTrue, reason: kind.name);
    }
  });

  test('six-lead motor preserves star and delta electrical topology', () {
    final star = projectOf(
      <CircuitComponent>[
        device('g1', ComponentKind.threePhaseSupply),
        device('m1', ComponentKind.motor6Terminal),
      ],
      <CircuitWire>[
        connection('w1', 'g1', 'l1', 'm1', 'u1'),
        connection('w2', 'g1', 'l2', 'm1', 'v1'),
        connection('w3', 'g1', 'l3', 'm1', 'w1'),
        connection('w4', 'm1', 'u2', 'm1', 'v2'),
        connection('w5', 'm1', 'v2', 'm1', 'w2'),
      ],
    );
    final starResult = ElectricalSimulator().step(star);
    expect(starResult.success, isTrue);
    expect(starResult['m1']!.active, isTrue);
    expect(starResult['m1']!.connectionMode, 'star');
    expect(starResult['m1']!.current, closeTo(2 / 3, 0.15));

    final delta = star.copyWith(
      wires: <CircuitWire>[
        ...star.wires.where(
            (wire) => wire.id == 'w1' || wire.id == 'w2' || wire.id == 'w3'),
        connection('w4', 'm1', 'u2', 'm1', 'v1'),
        connection('w5', 'm1', 'v2', 'm1', 'w1'),
        connection('w6', 'm1', 'w2', 'm1', 'u1'),
      ],
    );
    final deltaResult = ElectricalSimulator().step(delta);
    expect(deltaResult.success, isTrue);
    expect(deltaResult['m1']!.active, isTrue);
    expect(deltaResult['m1']!.connectionMode, 'delta');
    expect(deltaResult['m1']!.current, closeTo(2, 0.2));
  });
}
