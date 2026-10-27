import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/board_geometry.dart';
import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/geometry.dart';
import '../models/supply_bay.dart';
import '../models/terminal.dart';
import '../models/wire.dart';
import '../simulation/simulation_result.dart';
import '../state/editor_controller.dart';
import '../three_d/asset_mesh_view.dart';
import '../three_d/procedural_meshes.dart';
import 'board_painter.dart';

class CircuitBoard extends StatefulWidget {
  const CircuitBoard({
    required this.controller,
    required this.onShowDetails,
    super.key,
  });

  final EditorController controller;
  final ValueChanged<CircuitComponent> onShowDetails;

  @override
  State<CircuitBoard> createState() => CircuitBoardState();
}

class CircuitBoardState extends State<CircuitBoard> {
  final TransformationController _transformation = TransformationController();
  Size _viewportSize = Size.zero;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  BoardPoint get visibleCenter {
    final matrix = _transformation.value;
    final scale = math.max(0.08, matrix.getMaxScaleOnAxis());
    final translation = matrix.getTranslation();
    return BoardPoint(
      (_viewportSize.width / 2 - translation.x) / scale,
      (_viewportSize.height / 2 - translation.y) / scale,
    );
  }

  static const double _frameMargin = 12;

  double get _fitScale {
    if (_viewportSize.isEmpty) return 1;
    final project = widget.controller.project;
    return math.min(
      (_viewportSize.width - _frameMargin * 2) / project.boardWidth,
      (_viewportSize.height - _frameMargin * 2) / project.boardHeight,
    ).clamp(0.08, 2.0).toDouble();
  }

  double get _maximumScale =>
      math.max(1.5, _fitScale * 4).clamp(1.5, 3.0).toDouble();

  /// Fits the complete fixed mounting plate, including its frame, DIN rails and
  /// supply bay. It never focuses on a subset that could crop the enclosure.
  void fitToContent() {
    if (_viewportSize.isEmpty) return;
    final project = widget.controller.project;
    _applyViewport(
      _fitScale,
      BoardPoint(project.boardWidth / 2, project.boardHeight / 2),
      Offset(_viewportSize.width / 2, _viewportSize.height / 2),
    );
  }

  void zoomBy(double delta) {
    if (_viewportSize.isEmpty) return;
    final current = _transformation.value.getMaxScaleOnAxis();
    final next = (current * (1 + delta)).clamp(_fitScale, _maximumScale).toDouble();
    final focal = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final translation = _transformation.value.getTranslation();
    final boardFocus = BoardPoint(
      (focal.dx - translation.x) / current,
      (focal.dy - translation.y) / current,
    );
    _applyViewport(next, boardFocus, focal);
  }

  void _applyViewport(double scale, BoardPoint boardFocus, Offset screenFocus) {
    final tx = screenFocus.dx - boardFocus.x * scale;
    final ty = screenFocus.dy - boardFocus.y * scale;
    _transformation.value = _boundedMatrix(
      Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(tx, ty, 0),
    );
    _syncController();
  }

  Matrix4 _boundedMatrix(Matrix4 candidate) {
    final project = widget.controller.project;
    final scale = candidate.getMaxScaleOnAxis().clamp(_fitScale, _maximumScale).toDouble();
    final translation = candidate.getTranslation();
    final width = project.boardWidth * scale;
    final height = project.boardHeight * scale;
    double axisTranslation(double viewport, double scaled, double value) {
      if (scaled <= viewport) return (viewport - scaled) / 2;
      return value.clamp(viewport - scaled, 0).toDouble();
    }

    final tx = axisTranslation(_viewportSize.width, width, translation.x);
    final ty = axisTranslation(_viewportSize.height, height, translation.y);
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  void _syncController() {
    final matrix = _transformation.value;
    widget.controller.setViewport(
      scale: matrix.getMaxScaleOnAxis(),
      offset: BoardPoint(matrix.storage[12], matrix.storage[13]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final project = controller.project;
    final visibleLayers = project.layers
        .where((layer) => layer.visible)
        .map((layer) => layer.id)
        .toSet();
    return ColoredBox(
      color: const Color(0xff101923),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nextSize = constraints.biggest;
          if (_viewportSize != nextSize && !nextSize.isEmpty) {
            _viewportSize = nextSize;
            _transformation.value = _boundedMatrix(Matrix4.identity());
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _viewportSize == nextSize) fitToContent();
            });
          }
          return InteractiveViewer(
            transformationController: _transformation,
            constrained: false,
            boundaryMargin: EdgeInsets.zero,
            minScale: 0.08,
            maxScale: 3,
            // One-finger gestures belong to devices and wires, never to the
            // fixed enclosure. Two-finger zoom remains bounded to the plate.
            panEnabled: false,
            scaleEnabled: true,
            onInteractionUpdate: (_) {
              _transformation.value = _boundedMatrix(_transformation.value);
            },
            onInteractionEnd: (_) {
              _transformation.value = _boundedMatrix(_transformation.value);
              _syncController();
            },
            child: SizedBox(
              width: project.boardWidth,
              height: project.boardHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleBoardTap(details.localPosition),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BoardPainter(
                          project: project,
                          showGrid: controller.showGrid,
                          gridSize: controller.gridSize,
                          visibleLayers: visibleLayers,
                          result: controller.result,
                          selectedWireId: controller.selectedWireId,
                          industrialSurface: controller.industrialSurface,
                        ),
                      ),
                    ),
                    ...project.components
                        .where(
                          (component) =>
                              SupplyBay.isFixed(component) ||
                              visibleLayers.contains(component.layerId),
                        )
                        .map(
                          (component) => BoardComponent(
                            key: ValueKey<String>(component.id),
                            component: component,
                            controller: controller,
                            reading: controller.result?[component.id],
                            onShowDetails: () => widget.onShowDetails(component),
                          ),
                        ),
                    ..._buildWaypoints(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildWaypoints() {
    final controller = widget.controller;
    final wire = controller.selectedWire;
    if (wire == null) return const <Widget>[];
    final points = WireRouter.route(controller.project, wire);
    final hitSize = 30 / controller.zoom.clamp(0.08, 3.0);
    return <Widget>[
      for (var index = 0; index < wire.waypoints.length; index++)
        Positioned(
          left: points[index + 1].x - hitSize / 2,
          top: points[index + 1].y - hitSize / 2,
          width: hitSize,
          height: hitSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => controller.beginInteraction(),
            onPanUpdate: (details) {
              final current = controller.project.wireById(wire.id);
              if (current == null || index >= current.waypoints.length) return;
              controller.moveWireWaypoint(
                wire.id,
                index,
                current.waypoints[index] +
                    BoardPoint(
                      details.delta.dx / math.max(0.08, controller.zoom),
                      details.delta.dy / math.max(0.08, controller.zoom),
                    ),
                transient: true,
              );
            },
            onPanEnd: (_) => controller.endInteraction(),
            onPanCancel: controller.endInteraction,
            onDoubleTap: () => controller.removeWireWaypoint(wire.id, index),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xff087ff5), width: 3),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  void _handleBoardTap(Offset position) {
    final controller = widget.controller;
    if (controller.pendingWireStart != null) return;
    final point = BoardPoint(position.dx, position.dy);
    CircuitWire? nearest;
    var distance = 12.0;
    for (final wire in controller.project.wires) {
      if (!(controller.project.layerById(wire.layerId)?.visible ?? true)) {
        continue;
      }
      final current = BoardPainter.distanceToWire(
        controller.project,
        wire,
        point,
      );
      if (current < distance) {
        distance = current;
        nearest = wire;
      }
    }
    // A child device may handle the same tap before this board-level handler.
    // Never clear its fresh selection when no wire was actually hit.
    if (nearest != null) controller.selectWire(nearest.id);
  }
}

class BoardComponent extends StatefulWidget {
  const BoardComponent({
    required this.component,
    required this.controller,
    required this.onShowDetails,
    super.key,
    this.reading,
  });

  final CircuitComponent component;
  final EditorController controller;
  final DeviceReading? reading;
  final VoidCallback onShowDetails;

  @override
  State<BoardComponent> createState() => _BoardComponentState();
}

class _BoardComponentState extends State<BoardComponent> {
  @override
  Widget build(BuildContext context) {
    final component = widget.component;
    final controller = widget.controller;
    final spec = ComponentCatalog.specOf(component.kind);
    final scale = component.scale;
    final width = spec.size.width * scale;
    final height = spec.size.height * scale;
    final selected = controller.selectedComponentId == component.id;
    final fixedSupply = SupplyBay.isFixed(component);
    final showTerminals = fixedSupply ||
        (!controller.isRunning &&
            (selected || controller.pendingWireStart != null));
    final movable = !fixedSupply && !controller.isRunning;
    final reading = widget.reading;
    final active = reading?.active ?? false;
    final tripped = reading?.tripped ?? false;
    // Terminals can sit exactly at x=0/x=width. Extra hit space is enabled
    // only while wiring/selecting, without changing electrical coordinates.
    final hitOverflow = showTerminals ? 24.0 : 0.0;
    return Positioned(
      left: component.position.x - hitOverflow,
      top: component.position.y - hitOverflow,
      width: width + hitOverflow * 2,
      height: height + hitOverflow * 2,
      child: Transform.rotate(
        angle: component.rotation * math.pi / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: controller.isRunning &&
                  (component.kind == ComponentKind.pushButtonNO ||
                      component.kind == ComponentKind.pushButtonNC)
              ? (_) => controller.setMomentaryPressed(component.id, true)
              : null,
          onTapUp: controller.isRunning &&
                  (component.kind == ComponentKind.pushButtonNO ||
                      component.kind == ComponentKind.pushButtonNC)
              ? (_) => controller.setMomentaryPressed(component.id, false)
              : null,
          onTapCancel: () => controller.setMomentaryPressed(component.id, false),
          onTap: () {
            if (controller.isRunning &&
                (component.kind == ComponentKind.sensor ||
                    component.kind == ComponentKind.limitSwitch ||
                    component.kind == ComponentKind.selectorSwitch ||
                    component.kind == ComponentKind.rotarySwitch ||
                    component.kind == ComponentKind.emergencyStop)) {
              controller.toggleOperationalState(component.id);
            } else {
              controller.selectComponent(component.id);
            }
          },
          onDoubleTap: widget.onShowDetails,
          onPanStart: movable
              ? (_) {
                  controller.selectComponent(component.id);
                  controller.beginInteraction();
                }
              : null,
          onPanUpdate: movable
              ? (details) => controller.moveComponent(
                    component.id,
                    component.position +
                        BoardPoint(
                          details.delta.dx / math.max(0.08, controller.zoom),
                          details.delta.dy / math.max(0.08, controller.zoom),
                        ),
                    transient: true,
                  )
              : null,
          onPanEnd: movable ? (_) => controller.endInteraction() : null,
          onPanCancel: movable ? controller.endInteraction : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: hitOverflow,
                top: hitOverflow,
                width: width,
                height: height,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    border: selected || tripped
                        ? Border.all(
                            color: tripped
                                ? const Color(0xffff5252)
                                : const Color(0xff00a6ff),
                            width: 2,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: active
                        ? <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xff37d99a).withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: RepaintBoundary(
                    child: ComponentMeshView(
                      component: component,
                      detail: MeshDetail.board,
                      fixedScale: 48 * scale,
                    ),
                  ),
                ),
              ),
              if (fixedSupply)
                Positioned(
                  top: hitOverflow + 5,
                  left: hitOverflow + 5,
                  child: _SupplyToggle(
                    key: Key('supply-toggle-${component.id}'),
                    enabled: component.flag('enabled'),
                    onChanged: (enabled) => controller.setSupplyEnabled(
                      component.id,
                      enabled,
                    ),
                  ),
                ),
              if (showTerminals)
                for (final terminal in spec.terminals)
                  _TerminalButton(
                    key: ValueKey<String>(
                      'terminal-${component.id}-${terminal.id}',
                    ),
                    terminal: terminal,
                    component: component,
                    scale: scale,
                    origin: hitOverflow,
                    hitSize: 34 / controller.zoom.clamp(0.08, 3.0),
                    interactive: !controller.isRunning,
                    pending: controller.pendingWireStart ==
                        TerminalRef(
                          componentId: component.id,
                          terminalId: terminal.id,
                        ),
                    onTap: () => _handleTerminal(terminal),
                  ),
              Positioned(
                bottom: hitOverflow - 18,
                left: hitOverflow,
                right: hitOverflow,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xdd101923),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      component.label,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (reading != null && (reading.energized || active || tripped))
                Positioned(
                  top: hitOverflow + 4,
                  right: hitOverflow + 4,
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: tripped
                        ? const Color(0xffff5252)
                        : const Color(0xff37d99a),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTerminal(TerminalDefinition terminal) {
    final ref = TerminalRef(
      componentId: widget.component.id,
      terminalId: terminal.id,
    );
    if (widget.controller.pendingWireStart == null) {
      widget.controller.beginWire(ref);
    } else {
      widget.controller.completeWire(ref);
    }
  }
}

class _SupplyToggle extends StatelessWidget {
  const _SupplyToggle({
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: enabled ? 'تعطيل مصدر التغذية' : 'تفعيل مصدر التغذية',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!enabled),
        child: Container(
          width: 38,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xff148b62) : const Color(0xff273846),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? const Color(0xff65e0ae) : const Color(0xff748897),
            ),
          ),
          child: Text(
            enabled ? 'ON' : 'OFF',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalButton extends StatelessWidget {
  const _TerminalButton({
    required this.terminal,
    required this.component,
    required this.scale,
    required this.origin,
    required this.hitSize,
    required this.interactive,
    required this.pending,
    required this.onTap,
    super.key,
  });

  final TerminalDefinition terminal;
  final CircuitComponent component;
  final double scale;
  final double origin;
  final double hitSize;
  final bool interactive;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = origin + terminal.position.x * scale - hitSize / 2;
    final top = origin + terminal.position.y * scale - hitSize / 2;
    final terminalColor = switch (terminal.phase) {
      'L1' => const Color(0xffe53935),
      'L2' => const Color(0xfffdd835),
      'L3' => const Color(0xff1e88e5),
      _ => switch (terminal.kind) {
          TerminalKind.earth => const Color(0xff43a047),
          TerminalKind.neutral => const Color(0xff64b5f6),
          _ => terminal.id == 'positive'
              ? const Color(0xffe53935)
              : terminal.label == '0V'
                  ? const Color(0xff64b5f6)
                  : const Color(0xff00b7ff),
        },
    };
    final color = pending ? const Color(0xffffb300) : terminalColor;
    return Positioned(
      left: left,
      top: top,
      width: hitSize,
      height: hitSize,
      child: Semantics(
        button: true,
        label: 'طرف ${terminal.label} في ${component.label}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? onTap : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: pending ? 15 : 11,
                height: pending ? 15 : 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.28),
                  border: Border.all(color: color, width: 2),
                ),
              ),
              Positioned(
                top: terminal.position.y * scale < 20 ? hitSize / 2 : -15,
                child: Container(
                  color: const Color(0xdd07111f),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    terminal.label,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
