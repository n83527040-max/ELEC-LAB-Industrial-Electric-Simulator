import 'component.dart';
import 'component_catalog.dart';
import 'geometry.dart';
import 'project.dart';
import 'supply_bay.dart';
import 'terminal.dart';
import 'wire.dart';

enum ProjectTemplateKind {
  blank,
  dcLamp,
  selfHolding,
  motorProtection,
  directOnLine,
  starDelta,
}

abstract final class ProjectTemplates {
  static String name(ProjectTemplateKind kind) => switch (kind) {
        ProjectTemplateKind.blank => 'لوحة فارغة',
        ProjectTemplateKind.dcLamp => 'تشغيل مصباح DC',
        ProjectTemplateKind.selfHolding => 'تشغيل/إيقاف مع تعشيق ذاتي',
        ProjectTemplateKind.motorProtection => 'حماية محرك ثلاثي الطور',
        ProjectTemplateKind.directOnLine =>
          'Démarrage direct — تشغيل مباشر مثلث',
        ProjectTemplateKind.starDelta =>
          'Étoile-triangle — تشغيل نجمة/مثلث',
      };

  static ElectricalProject apply(
    ElectricalProject empty,
    ProjectTemplateKind kind,
  ) {
    if (kind == ProjectTemplateKind.blank) return SupplyBay.install(empty);
    final components = <CircuitComponent>[];
    final wires = <CircuitWire>[];
    var wireIndex = 0;

    void add(
      String id,
      ComponentKind kind,
      String label,
      double x,
      double y,
      String layer, [
      Map<String, Object> overrides = const <String, Object>{},
    ]) {
      components.add(
        CircuitComponent(
          id: id,
          kind: kind,
          label: label,
          position: BoardPoint(x, y),
          layerId: layer,
          properties: <String, Object>{
            ...ComponentCatalog.specOf(kind).defaultProperties,
            ...overrides,
          },
        ),
      );
    }

    void connect(
      String fromComponent,
      String fromTerminal,
      String toComponent,
      String toTerminal,
      String layer, {
      int color = 0xffe53935,
    }) {
      wireIndex++;
      wires.add(
        CircuitWire(
          id: 'template_wire_$wireIndex',
          from: TerminalRef(
            componentId: fromComponent,
            terminalId: fromTerminal,
          ),
          to: TerminalRef(componentId: toComponent, terminalId: toTerminal),
          layerId: layer,
          colorValue: color,
        ),
      );
    }

    void control(
      String fromComponent,
      String fromTerminal,
      String toComponent,
      String toTerminal, {
      int color = 0xff1e88e5,
    }) {
      connect(
        fromComponent,
        fromTerminal,
        toComponent,
        toTerminal,
        'control',
        color: color,
      );
    }

    void phase(
      String fromComponent,
      String fromTerminal,
      String toComponent,
      String toTerminal,
      int phaseNumber,
    ) {
      connect(
        fromComponent,
        fromTerminal,
        toComponent,
        toTerminal,
        'power',
        color: const <int>[0xffe53935, 0xfffdd835, 0xff1e88e5][phaseNumber],
      );
    }

    void startStopControl(String contactorId, String thermalId) {
      control(SupplyBay.singlePhaseId, 'line', 's0', 'input');
      control('s0', 'output', thermalId, 'nc95');
      control(thermalId, 'nc96', 's1', 'input');
      control('s1', 'output', contactorId, 'a1');
      control(
        contactorId,
        'a2',
        SupplyBay.singlePhaseId,
        'neutral',
        color: 0xff3949ab,
      );
      control(thermalId, 'nc96', contactorId, 'aux13');
      control(contactorId, 'aux14', 's1', 'output');
    }

    const coil230 = <String, Object>{
      'coilVoltage': 230.0,
      'coilResistance': 3000.0,
    };
    const motor400 = <String, Object>{
      'nominalVoltage': 400.0,
      'nominalCurrent': 2.0,
      'powerFactor': 0.8,
    };

    switch (kind) {
      case ProjectTemplateKind.blank:
        break;
      case ProjectTemplateKind.dcLamp:
        add('s1', ComponentKind.pushButtonNO, 'S1', 360, 280, 'control');
        add('h1', ComponentKind.indicator, 'H1', 610, 280, 'signals');
        connect(SupplyBay.dcId, 'positive', 's1', 'input', 'power');
        connect('s1', 'output', 'h1', 'x1', 'control', color: 0xff1e88e5);
        connect('h1', 'x2', SupplyBay.dcId, 'negative', 'power', color: 0xff3949ab);
      case ProjectTemplateKind.selfHolding:
        add('s0', ComponentKind.pushButtonNC, 'S0', 280, 270, 'control');
        add('s1', ComponentKind.pushButtonNO, 'S1', 280, 490, 'control');
        add('k1', ComponentKind.contactor, 'K1', 560, 261, 'control');
        add('h1', ComponentKind.indicator, 'H1', 900, 290, 'signals');
        connect(SupplyBay.dcId, 'positive', 's0', 'input', 'power');
        connect('s0', 'output', 's1', 'input', 'control', color: 0xff1e88e5);
        connect('s1', 'output', 'k1', 'a1', 'control', color: 0xff1e88e5);
        connect('k1', 'a2', SupplyBay.dcId, 'negative', 'control', color: 0xff3949ab);
        connect('s0', 'output', 'k1', 'aux13', 'control', color: 0xff1e88e5);
        connect('k1', 'aux14', 's1', 'output', 'control', color: 0xff1e88e5);
        connect(SupplyBay.dcId, 'positive', 'k1', 'l1', 'power');
        connect('k1', 't1', 'h1', 'x1', 'power');
        connect('h1', 'x2', SupplyBay.dcId, 'negative', 'power', color: 0xff3949ab);
      case ProjectTemplateKind.motorProtection:
        add('k1', ComponentKind.contactor, 'K1', 300, 261, 'power');
        add('f2', ComponentKind.thermalRelay, 'F2', 550, 276, 'power', <String, Object>{
          'ratedCurrent': 1.5,
        });
        add('m1', ComponentKind.motor3Phase, 'M1', 820, 280, 'power');
        connect(SupplyBay.threePhaseId, 'l1', 'k1', 'l1', 'power');
        connect(SupplyBay.threePhaseId, 'l2', 'k1', 'l2', 'power', color: 0xfffdd835);
        connect(SupplyBay.threePhaseId, 'l3', 'k1', 'l3', 'power', color: 0xff1e88e5);
        connect('k1', 't1', 'f2', 'l1', 'power');
        connect('k1', 't2', 'f2', 'l2', 'power', color: 0xfffdd835);
        connect('k1', 't3', 'f2', 'l3', 'power', color: 0xff1e88e5);
        connect('f2', 't1', 'm1', 'u', 'power');
        connect('f2', 't2', 'm1', 'v', 'power', color: 0xfffdd835);
        connect('f2', 't3', 'm1', 'w', 'power', color: 0xff1e88e5);
        connect(SupplyBay.threePhaseId, 'pe', 'm1', 'earth', 'power', color: 0xff43a047);
        connect(SupplyBay.singlePhaseId, 'line', 'f2', 'nc95', 'control', color: 0xff1e88e5);
        connect('f2', 'nc96', 'k1', 'a1', 'control', color: 0xff1e88e5);
        connect('k1', 'a2', SupplyBay.singlePhaseId, 'neutral', 'control', color: 0xff3949ab);
      case ProjectTemplateKind.directOnLine:
        add('q1', ComponentKind.motorBreaker, 'Q1', 60, 300, 'power', <String, Object>{
          'ratedCurrent': 4.0,
        });
        add('km1', ComponentKind.contactor, 'KM1', 260, 300, 'power', coil230);
        add('f2', ComponentKind.thermalRelay, 'F2', 490, 312, 'power', <String, Object>{
          'ratedCurrent': 2.5,
          'tripTime': 5.0,
        });
        add('m1', ComponentKind.motor6Terminal, 'M1', 810, 320, 'power', motor400);
        add('s0', ComponentKind.pushButtonNC, 'S0 STOP', 130, 680, 'control');
        add('s1', ComponentKind.pushButtonNO, 'S1 START', 310, 680, 'control');
        for (var index = 0; index < 3; index++) {
          final input = <String>['l1', 'l2', 'l3'][index];
          final output = <String>['t1', 't2', 't3'][index];
          phase(SupplyBay.threePhaseId, input, 'q1', input, index);
          phase('q1', output, 'km1', input, index);
          phase('km1', output, 'f2', input, index);
        }
        // Delta connection for a 400/690 V six-lead motor on a 400 V line:
        // U1-W2, V1-U2 and W1-V2 are each fed by one line phase.
        phase('f2', 't1', 'm1', 'u1', 0);
        phase('f2', 't1', 'm1', 'w2', 0);
        phase('f2', 't2', 'm1', 'v1', 1);
        phase('f2', 't2', 'm1', 'u2', 1);
        phase('f2', 't3', 'm1', 'w1', 2);
        phase('f2', 't3', 'm1', 'v2', 2);
        connect(SupplyBay.threePhaseId, 'pe', 'm1', 'earth', 'power', color: 0xff43a047);
        startStopControl('km1', 'f2');
      case ProjectTemplateKind.starDelta:
        add('q1', ComponentKind.motorBreaker, 'Q1', 45, 282, 'power', <String, Object>{
          'ratedCurrent': 4.0,
        });
        add('km1', ComponentKind.contactor, 'KM1 MAIN', 230, 282, 'power', coil230);
        add('f2', ComponentKind.thermalRelay, 'F2', 450, 294, 'power', <String, Object>{
          'ratedCurrent': 2.5,
          'tripTime': 5.0,
        });
        add('kt1', ComponentKind.timer, 'KT1', 690, 282, 'control', <String, Object>{
          ...coil230,
          'delaySeconds': 3.0,
        });
        add('m1', ComponentKind.motor6Terminal, 'M1', 880, 400, 'power', motor400);
        add('km2', ComponentKind.contactor, 'KM2 STAR', 235, 560, 'power', <String, Object>{
          ...coil230,
          'interlockGroup': 'm1_star_delta',
          'interlockRole': 'star',
        });
        add('km3', ComponentKind.contactor, 'KM3 DELTA', 480, 560, 'power', <String, Object>{
          ...coil230,
          'interlockGroup': 'm1_star_delta',
          'interlockRole': 'delta',
        });
        add('x1', ComponentKind.terminalBlock, 'X STAR', 735, 585, 'power');
        add('s0', ComponentKind.pushButtonNC, 'S0 STOP', 45, 730, 'control');
        add('s1', ComponentKind.pushButtonNO, 'S1 START', 170, 730, 'control');
        for (var index = 0; index < 3; index++) {
          final input = <String>['l1', 'l2', 'l3'][index];
          final output = <String>['t1', 't2', 't3'][index];
          phase(SupplyBay.threePhaseId, input, 'q1', input, index);
          phase('q1', output, 'km1', input, index);
          phase('km1', output, 'f2', input, index);
          phase('f2', output, 'km3', input, index);
        }
        phase('f2', 't1', 'm1', 'u1', 0);
        phase('f2', 't2', 'm1', 'v1', 1);
        phase('f2', 't3', 'm1', 'w1', 2);
        // KM3 crosses the winding ends for delta; KM2 joins them to X STAR.
        phase('km3', 't1', 'm1', 'w2', 0);
        phase('km3', 't2', 'm1', 'u2', 1);
        phase('km3', 't3', 'm1', 'v2', 2);
        phase('m1', 'u2', 'km2', 'l1', 1);
        phase('m1', 'v2', 'km2', 'l2', 2);
        phase('m1', 'w2', 'km2', 'l3', 0);
        phase('km2', 't1', 'x1', 'a', 0);
        phase('km2', 't2', 'x1', 'a', 0);
        phase('km2', 't3', 'x1', 'a', 0);
        connect(SupplyBay.threePhaseId, 'pe', 'm1', 'earth', 'power', color: 0xff43a047);
        startStopControl('km1', 'f2');
        // The timer starts with KM1. Its changeover contact transfers the
        // control supply from the star coil to the delta coil after the delay.
        control('s1', 'output', 'kt1', 'a1');
        control('kt1', 'a2', SupplyBay.singlePhaseId, 'neutral', color: 0xff3949ab);
        control('s1', 'output', 'kt1', 't15');
        control('kt1', 't16', 'km3', 'aux21');
        control('km3', 'aux22', 'km2', 'a1');
        control('km2', 'a2', SupplyBay.singlePhaseId, 'neutral', color: 0xff3949ab);
        control('kt1', 't18', 'km2', 'aux21');
        control('km2', 'aux22', 'km3', 'a1');
        control('km3', 'a2', SupplyBay.singlePhaseId, 'neutral', color: 0xff3949ab);
    }
    final installed = SupplyBay.install(empty);
    final enabledSources = switch (kind) {
      ProjectTemplateKind.dcLamp ||
      ProjectTemplateKind.selfHolding => const <String>{SupplyBay.dcId},
      ProjectTemplateKind.motorProtection ||
      ProjectTemplateKind.directOnLine ||
      ProjectTemplateKind.starDelta => const <String>{
          SupplyBay.threePhaseId,
          SupplyBay.singlePhaseId,
        },
      ProjectTemplateKind.blank => const <String>{},
    };
    final supplies = installed.components.map((component) {
      if (!enabledSources.contains(component.id)) return component;
      return component.copyWith(
        properties: <String, Object>{...component.properties, 'enabled': true},
      );
    });
    final result = installed.copyWith(
      components: <CircuitComponent>[...supplies, ...components],
      wires: wires,
    );
    result.validate();
    return result;
  }
}
