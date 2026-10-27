import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/board_geometry.dart';
import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/geometry.dart';
import '../models/project.dart';
import '../models/terminal.dart';
import '../models/wire.dart';
import '../simulation/simulation_result.dart';
import '../state/editor_controller.dart';
import '../three_d/mesh_model.dart';
import '../three_d/mesh_view.dart';
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
  State<CircuitBoard> createState() => _CircuitBoardState();
}

class _CircuitBoardState extends State<CircuitBoard> {
  final TransformationController _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final project = controller.project;
    final visibleLayers = project.layers
        .where((layer) => layer.visible)
        .map((layer) => layer.id)
        .toSet();
    final currentScale = _transformation.value.getMaxScaleOnAxis();
    if ((currentScale - controller.zoom).abs() > 0.005) {
      _transformation.value = Matrix4.diagonal3Values(
        controller.zoom,
        controller.zoom,
        1,
      );
    }
    return ColoredBox(
      color: const Color(0xff101923),
      child: InteractiveViewer(
        transformationController: _transformation,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(500),
        minScale: 0.35,
        maxScale: 3,
        panEnabled: true,
        scaleEnabled: true,
        onInteractionEnd: (_) {
          final matrix = _transformation.value;
          controller.setViewport(
            scale: matrix.getMaxScaleOnAxis(),
            offset: BoardPoint(matrix.storage[12], matrix.storage[13]),
          );
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
                    ),
                  ),
                ),
                ...project.components.where(
                  (component) => visibleLayers.contains(component.layerId),
                ).map(
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
      ),
    );
  }

  List<Widget> _buildWaypoints() {
    final controller = widget.controller;
    final wire = controller.selectedWire;
    if (wire == null) return const <Widget>[];
    final points = WireRouter.route(controller.project, wire);
    return <Widget>[
      for (var index = 0; index < wire.waypoints.length; index++)
        Positioned(
          left: points[index + 1].x - 11,
          top: points[index + 1].y - 11,
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
                    details.delta / math.max(0.35, controller.zoom),
                transient: true,
              );
            },
            onPanEnd: (_) => controller.endInteraction(),
            onPanCancel: controller.endInteraction,
            onDoubleTap: () => controller.removeWireWaypoint(wire.id, index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff087ff5), width: 3),
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
    controller.selectWire(nearest?.id);
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
  late DeviceMesh _mesh;

  @override
  void initState() {
    super.initState();
    _mesh = ProceduralMeshes.forComponent(widget.component);
  }

  @override
  void didUpdateWidget(BoardComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.component.kind != widget.component.kind ||
        oldWidget.component.text('color') != widget.component.text('color')) {
      _mesh = ProceduralMeshes.forComponent(widget.component);
    }
  }

  @override
  Widget build(BuildContext context) {
    final component = widget.component;
    final controller = widget.controller;
    final spec = ComponentCatalog.specOf(component.kind);
    final scale = component.scale;
    final width = spec.size.width * scale;
    final height = spec.size.height * scale;
    final selected = controller.selectedComponentId == component.id;
    final showLabels = selected || controller.pendingWireStart != null;
    final reading = widget.reading;
    final active = reading?.active ?? false;
    final tripped = reading?.tripped ?? false;
    return Positioned(
      left: component.position.x,
      top: component.position.y,
      width: width,
      height: height,
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
                    component.kind == ComponentKind.selectorSwitch)) {
              controller.toggleOperationalState(component.id);
            } else {
              controller.selectComponent(component.id);
            }
          },
          onDoubleTap: widget.onShowDetails,
          onPanStart: controller.isRunning
              ? null
              : (_) {
                  controller.selectComponent(component.id);
                  controller.beginInteraction();
                },
          onPanUpdate: controller.isRunning
              ? null
              : (details) => controller.moveComponent(
                    component.id,
                    component.position +
                        details.delta / math.max(0.35, controller.zoom),
                    transient: true,
                  ),
          onPanEnd: controller.isRunning
              ? null
              : (_) => controller.endInteraction(),
          onPanCancel: controller.isRunning ? null : controller.endInteraction,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
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
                  child: DeviceMeshView(mesh: _mesh),
                ),
              ),
              for (final terminal in spec.terminals)
                _TerminalButton(
                  terminal: terminal,
                  component: component,
                  scale: scale,
                  showLabel: showLabels,
                  pending: controller.pendingWireStart ==
                      TerminalRef(
                        componentId: component.id,
                        terminalId: terminal.id,
                      ),
                  onTap: () => _handleTerminal(terminal),
                ),
              Positioned(
                bottom: -18,
                left: 0,
                right: 0,
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
                  top: 4,
                  right: 4,
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

class _TerminalButton extends StatelessWidget {
  const _TerminalButton({
    required this.terminal,
    required this.component,
    required this.scale,
    required this.showLabel,
    required this.pending,
    required this.onTap,
  });

  final TerminalDefinition terminal;
  final CircuitComponent component;
  final double scale;
  final bool showLabel;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = 22.0;
    final left = terminal.position.x * scale - size / 2;
    final top = terminal.position.y * scale - size / 2;
    final color = pending ? const Color(0xffffb300) : const Color(0xff00b7ff);
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: pending ? 15 : 11,
              height: pending ? 15 : 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.22),
                border: Border.all(color: color, width: 2),
              ),
            ),
            if (showLabel)
              Positioned(
                top: terminal.position.y * scale < 20 ? 11 : -15,
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
    );
  }
}
