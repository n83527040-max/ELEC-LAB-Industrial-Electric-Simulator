import 'component.dart';
import 'component_catalog.dart';
import 'geometry.dart';
import 'project.dart';
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
    if (kind == ProjectTemplateKind.blank) return empty;
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
        add('g1', ComponentKind.dcSupply, 'G1', 100, 160, 'power');
        add('s1', ComponentKind.pushButtonNO, 'S1', 360, 180, 'control');
        add('h1', ComponentKind.indicator, 'H1', 610, 170, 'signals');
        connect('g1', 'positive', 's1', 'input', 'power');
        connect('s1', 'output', 'h1', 'x1', 'control', color: 0xff1e88e5);
        connect('h1', 'x2', 'g1', 'negative', 'power', color: 0xff3949ab);
      case ProjectTemplateKind.selfHolding:
        add('g1', ComponentKind.dcSupply, 'G1', 70, 120, 'power');
        add('s0', ComponentKind.pushButtonNC, 'S0', 280, 90, 'control');
        add('s1', ComponentKind.pushButtonNO, 'S1', 280, 310, 'control');
        add('k1', ComponentKind.contactor, 'K1', 560, 170, 'control');
        add('h1', ComponentKind.indicator, 'H1', 900, 190, 'signals');
        connect('g1', 'positive', 's0', 'input', 'power');
        connect('s0', 'output', 's1', 'input', 'control', color: 0xff1e88e5);
        connect('s1', 'output', 'k1', 'a1', 'control', color: 0xff1e88e5);
        connect('k1', 'a2', 'g1', 'negative', 'control', color: 0xff3949ab);
        connect('s0', 'output', 'k1', 'aux13', 'control', color: 0xff1e88e5);
        connect('k1', 'aux14', 's1', 'output', 'control', color: 0xff1e88e5);
        connect('g1', 'positive', 'k1', 'l1', 'power');
        connect('k1', 't1', 'h1', 'x1', 'power');
        connect('h1', 'x2', 'g1', 'negative', 'power', color: 0xff3949ab);
      case ProjectTemplateKind.motorProtection:
        add('g3', ComponentKind.threePhaseSupply, 'G3', 50, 90, 'power');
        add('k1', ComponentKind.contactor, 'K1', 300, 90, 'power');
        add('f2', ComponentKind.thermalRelay, 'F2', 550, 100, 'power', <String, Object>{
          'ratedCurrent': 1.5,
        });
        add('m1', ComponentKind.motor3Phase, 'M1', 820, 100, 'power');
        add('g1', ComponentKind.acSupply, 'G1', 250, 500, 'control');
        connect('g3', 'l1', 'k1', 'l1', 'power');
        connect('g3', 'l2', 'k1', 'l2', 'power', color: 0xfffdd835);
        connect('g3', 'l3', 'k1', 'l3', 'power', color: 0xff1e88e5);
        connect('k1', 't1', 'f2', 'l1', 'power');
        connect('k1', 't2', 'f2', 'l2', 'power', color: 0xfffdd835);
        connect('k1', 't3', 'f2', 'l3', 'power', color: 0xff1e88e5);
        connect('f2', 't1', 'm1', 'u', 'power');
        connect('f2', 't2', 'm1', 'v', 'power', color: 0xfffdd835);
        connect('f2', 't3', 'm1', 'w', 'power', color: 0xff1e88e5);
        connect('g3', 'pe', 'm1', 'earth', 'power', color: 0xff43a047);
        connect('g1', 'line', 'f2', 'nc95', 'control', color: 0xff1e88e5);
        connect('f2', 'nc96', 'k1', 'a1', 'control', color: 0xff1e88e5);
        connect('k1', 'a2', 'g1', 'neutral', 'control', color: 0xff3949ab);
    }
    final result = empty.copyWith(components: components, wires: wires);
    result.validate();
    return result;
  }
}
