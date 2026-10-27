import 'component.dart';
import 'geometry.dart';
import 'terminal.dart';

/// Shared rail positions for painting and editor snapping. Motors, panel
/// buttons and meters remain free-positioned devices.
abstract final class DinGeometry {
  static const railCenters = <double>[340, 570, 790];
  static const snapDistance = 22.0;

  static bool supports(ComponentKind kind) => switch (kind) {
        ComponentKind.dcSupply ||
        ComponentKind.acSupply ||
        ComponentKind.threePhaseSupply ||
        ComponentKind.circuitBreaker ||
        ComponentKind.differentialBreaker ||
        ComponentKind.motorBreaker ||
        ComponentKind.contactor ||
        ComponentKind.thermalRelay ||
        ComponentKind.auxiliaryRelay ||
        ComponentKind.timer ||
        ComponentKind.timerOffDelay ||
        ComponentKind.transformer ||
        ComponentKind.terminalBlock ||
        ComponentKind.fuse => true,
        _ => false,
      };

  static BoardPoint snapWithHeight(
    BoardPoint requested,
    CircuitComponent component,
    double height,
  ) {
    if (!supports(component.kind)) return requested;
    return _snapToRail(requested, height);
  }

  static BoardPoint _snapToRail(BoardPoint requested, double height) {
    final centerY = requested.y + height / 2;
    var nearest = railCenters.first;
    for (final rail in railCenters.skip(1)) {
      if ((rail - centerY).abs() < (nearest - centerY).abs()) nearest = rail;
    }
    if ((nearest - centerY).abs() > snapDistance) return requested;
    return BoardPoint(requested.x, nearest - height / 2);
  }
}
