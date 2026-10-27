import 'component.dart';
import 'component_catalog.dart';
import 'geometry.dart';
import 'project.dart';
import 'supply_bay.dart';
import 'terminal.dart';
import 'wire.dart';

enum ProjectTemplateKind { blank, dcLamp, selfHolding, motorProtection }

abstract final class ProjectTemplates {
  static String name(ProjectTemplateKind kind) => switch (kind) {
        ProjectTemplateKind.blank => 'لوحة فارغة',
        ProjectTemplateKind.dcLamp => 'تشغيل مصباح DC',
        ProjectTemplateKind.selfHolding => 'تشغيل/إيقاف مع تعشيق ذاتي',
        ProjectTemplateKind.motorProtection => 'حماية محرك ثلاثي الطور',
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
    }
    final installed = SupplyBay.install(empty);
    final enabledSources = switch (kind) {
      ProjectTemplateKind.dcLamp ||
      ProjectTemplateKind.selfHolding => const <String>{SupplyBay.dcId},
      ProjectTemplateKind.motorProtection => const <String>{
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
