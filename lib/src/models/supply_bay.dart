import 'component.dart';
import 'component_catalog.dart';
import 'geometry.dart';
import 'layer.dart';
import 'project.dart';
import 'terminal.dart';

/// Reserved, project-backed supply terminals at the top of every editor board.
/// They are ordinary electrical components for persistence and MNA, but their
/// position and identity are protected by the editor.
abstract final class SupplyBay {
  static const threePhaseId = 'supply_bay_three_phase';
  static const singlePhaseId = 'supply_bay_single_phase';
  static const dcId = 'supply_bay_dc';
  static const reservedHeight = 220.0;

  static const ids = <String>{threePhaseId, singlePhaseId, dcId};

  static ElectricalProject install(ElectricalProject project) {
    var base = project;
    if (base.layerById('power') == null) {
      final power = CircuitLayer.defaults().singleWhere(
        (layer) => layer.id == 'power',
      );
      base = base.copyWith(
        layers: <CircuitLayer>[...base.layers, power],
      );
    }
    final existing = base.components.map((item) => item.id).toSet();
    final additions = <CircuitComponent>[
      if (!existing.contains(threePhaseId))
        _source(
          threePhaseId,
          ComponentKind.threePhaseSupply,
          'G3',
          54,
        ),
      if (!existing.contains(singlePhaseId))
        _source(singlePhaseId, ComponentKind.acSupply, 'G1', 230),
      if (!existing.contains(dcId))
        _source(dcId, ComponentKind.dcSupply, 'GDC', 376),
    ];
    if (additions.isEmpty) return base;
    return base.copyWith(
      components: <CircuitComponent>[...additions, ...base.components],
    );
  }

  static bool isFixed(CircuitComponent component) =>
      ids.contains(component.id) && component.properties['supplyBay'] == true;

  static bool isSupplyKind(ComponentKind kind) =>
      kind == ComponentKind.dcSupply ||
      kind == ComponentKind.acSupply ||
      kind == ComponentKind.threePhaseSupply;

  static CircuitComponent _source(
    String id,
    ComponentKind kind,
    String label,
    double x,
  ) {
    return CircuitComponent(
      id: id,
      kind: kind,
      label: label,
      position: BoardPoint(x, 62),
      layerId: 'power',
      properties: <String, Object>{
        ...ComponentCatalog.specOf(kind).defaultProperties,
        'enabled': false,
        'supplyBay': true,
      },
    );
  }
}
