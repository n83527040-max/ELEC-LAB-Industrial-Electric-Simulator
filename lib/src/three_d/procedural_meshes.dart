import 'dart:math' as math;

import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/terminal.dart';
import 'mesh_model.dart';

/// Board meshes deliberately use fewer faces. Detailed geometry is allocated
/// only when its tab is opened; library previews are lazy and cached by kind.
enum MeshDetail { board, preview, detailed }

abstract final class ProceduralMeshes {
  static final Map<String, DeviceMesh> _cache = <String, DeviceMesh>{};

  static DeviceMesh forComponent(
    CircuitComponent component, {
    MeshDetail detail = MeshDetail.preview,
  }) {
    return _cached(
      component.kind,
      detail,
      component.text('color'),
    );
  }

  static DeviceMesh forKind(
    ComponentKind kind, {
    MeshDetail detail = MeshDetail.preview,
  }) {
    final spec = ComponentCatalog.specOf(kind);
    return _cached(kind, detail, spec.defaultProperties['color']?.toString() ?? '');
  }

  /// Terminal metadata is shared with GLB assets without building a legacy
  /// procedural mesh. The electrical catalog remains the only source of XY.
  static List<MeshTerminal> terminalsForKind(ComponentKind kind) {
    final spec = ComponentCatalog.specOf(kind);
    final depth = _depthFor(kind);
    return List<MeshTerminal>.unmodifiable(
      spec.terminals.map(
        (terminal) => MeshTerminal(
          id: terminal.id,
          label: terminal.label,
          position: _terminalPosition(terminal, spec, depth),
        ),
      ),
    );
  }

  static DeviceMesh _cached(
    ComponentKind kind,
    MeshDetail detail,
    String color,
  ) {
    final key = '${kind.name}:${detail.name}:$color';
    return _cache.putIfAbsent(
      key,
      () => _build(ComponentCatalog.specOf(kind), detail, color),
    );
  }

  static DeviceMesh _build(
    ComponentSpec spec,
    MeshDetail detail,
    String color,
  ) {
    final builder = MeshBuilder();
    final width = spec.size.width / 48;
    final height = spec.size.height / 48;
    final depth = _depthFor(spec.kind);
    final context = _MeshContext(
      builder,
      spec,
      detail,
      width,
      height,
      depth,
      color,
    );

    switch (spec.kind) {
      case ComponentKind.contactor:
        _contactor(context);
      case ComponentKind.circuitBreaker:
        _circuitBreaker(context);
      case ComponentKind.differentialBreaker:
        _differentialBreaker(context);
      case ComponentKind.motorBreaker:
        _motorBreaker(context);
      case ComponentKind.fuse:
        _fuse(context);
      case ComponentKind.thermalRelay:
        _thermalRelay(context);
      case ComponentKind.auxiliaryRelay:
        _auxiliaryRelay(context);
      case ComponentKind.timer:
        _timer(context);
      case ComponentKind.timerOffDelay:
        _offDelayTimer(context);
      case ComponentKind.pushButtonNO:
      case ComponentKind.pushButtonNC:
      case ComponentKind.selectorSwitch:
        _controlDevice(context);
      case ComponentKind.emergencyStop:
        _emergencyStop(context);
      case ComponentKind.rotarySwitch:
        _rotarySwitch(context);
      case ComponentKind.sensor:
        _sensor(context);
      case ComponentKind.limitSwitch:
        _limitSwitch(context);
      case ComponentKind.indicator:
        _indicator(context);
      case ComponentKind.motor3Phase:
        _motor(context);
      case ComponentKind.motor1Phase:
        _singlePhaseMotor(context);
      case ComponentKind.transformer:
        _transformer(context);
      case ComponentKind.dcSupply:
      case ComponentKind.acSupply:
      case ComponentKind.threePhaseSupply:
        _supply(context);
      case ComponentKind.voltmeter:
      case ComponentKind.ammeter:
        _meter(context);
      case ComponentKind.digitalCounter:
        _digitalCounter(context);
      case ComponentKind.terminalBlock:
        _terminalBlock(context);
      default:
        _extendedDevice(context);
    }

    final terminals = <MeshTerminal>[];
    for (final terminal in spec.terminals) {
      final position = _terminalPosition(terminal, spec, depth);
      terminals.add(
        MeshTerminal(id: terminal.id, label: terminal.label, position: position),
      );
      _terminalHardware(
        context,
        position,
        terminal.kind,
        radius: detail == MeshDetail.board ? 0.065 : 0.082,
      );
    }
    return builder.build(terminals);
  }

  static void _contactor(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, -0.08), Vector3D(w, h, d), c.white,
        bevel: 0.1);
    b.addBox(Vector3D(0, 0, -d * 0.58), Vector3D(w * 0.7, h * 0.16, 0.14),
        c.graphite);
    b.addBeveledBox(Vector3D(0, h * 0.37, d * 0.35),
        Vector3D(w * 0.98, h * 0.25, d * 0.35), c.graphite, bevel: 0.045);
    b.addBeveledBox(Vector3D(0, -h * 0.39, d * 0.34),
        Vector3D(w * 0.98, h * 0.19, d * 0.32), c.graphite, bevel: 0.04);
    b.addBeveledBox(Vector3D(-w * 0.43, -h * 0.02, d * 0.35),
        Vector3D(w * 0.16, h * 0.52, d * 0.25), c.lightGrey, bevel: 0.025);
    b.addBeveledBox(Vector3D(0, h * 0.02, d * 0.55),
        Vector3D(w * 0.59, h * 0.35, 0.2), c.black, bevel: 0.045);
    b.addBox(Vector3D(0, h * 0.02, d * 0.7),
        Vector3D(w * 0.39, h * 0.12, 0.13), c.blue);
    b.addBox(Vector3D(0, -h * 0.18, d * 0.62),
        Vector3D(w * 0.47, h * 0.09, 0.035), c.label);
    if (c.detail != MeshDetail.board) {
      for (var i = -2; i <= 2; i++) {
        b.addBox(Vector3D(i * w * 0.12, h * 0.49, d * 0.48),
            Vector3D(w * 0.055, h * 0.045, 0.055), c.black);
      }
      b.addBox(Vector3D(w * 0.42, 0, d * 0.45),
          Vector3D(w * 0.08, h * 0.37, 0.09), c.lightGrey);
    }
  }

  static void _circuitBreaker(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, 0), Vector3D(w, h, d), c.white, bevel: 0.09);
    b.addBox(Vector3D(0, 0, -d * 0.58), Vector3D(w * 0.72, h * 0.12, 0.15),
        c.graphite);
    b.addBeveledBox(Vector3D(0, h * 0.04, d * 0.47),
        Vector3D(w * 0.78, h * 0.58, 0.18), c.lightGrey, bevel: 0.04);
    b.addBox(Vector3D(0, h * 0.29, d * 0.58),
        Vector3D(w * 0.63, h * 0.1, 0.035), c.label);
    b.addBox(Vector3D(0, h * 0.02, d * 0.62),
        Vector3D(w * 0.4, h * 0.29, 0.12), c.black);
    b.addBeveledBox(Vector3D(0, h * 0.04, d * 0.78),
        Vector3D(w * 0.24, h * 0.25, 0.22), c.blue, bevel: 0.035);
    b.addBox(Vector3D(0, -h * 0.24, d * 0.58),
        Vector3D(w * 0.62, h * 0.055, 0.035), c.graphite);
    if (c.detail == MeshDetail.detailed) {
      for (final side in <double>[-1, 1]) {
        b.addBox(Vector3D(side * w * 0.43, 0, d * 0.22),
            Vector3D(0.025, h * 0.67, d * 0.35), c.midGrey);
      }
    }
  }

  static void _fuse(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, 0), Vector3D(w, h, d), c.white, bevel: 0.08);
    b.addBeveledBox(Vector3D(0, 0, d * 0.46),
        Vector3D(w * 0.82, h * 0.72, 0.18), c.graphite, bevel: 0.045);
    b.addBox(Vector3D(0, 0, d * 0.59), Vector3D(w * 0.54, h * 0.51, 0.07),
        c.black);
    b.addCylinder(Vector3D(0, 0, d * 0.65), w * 0.16, h * 0.36, c.glass,
        axis: MeshAxis.y, segments: c.segments);
    for (final side in <double>[-1, 1]) {
      b.addCylinder(Vector3D(0, side * h * 0.2, d * 0.65), w * 0.19,
          h * 0.07, c.metal, axis: MeshAxis.y, segments: c.segments);
    }
    b.addBox(Vector3D(w * 0.34, 0, d * 0.72),
        Vector3D(w * 0.1, h * 0.34, 0.12), c.lightGrey);
    b.addSphere(Vector3D(-w * 0.25, -h * 0.31, d * 0.65), w * 0.055, c.red,
        segments: c.segments, rings: c.rings);
  }

  static void _thermalRelay(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, -0.03), Vector3D(w, h, d), c.graphite,
        bevel: 0.09);
    b.addBox(Vector3D(0, h * 0.36, d * 0.36),
        Vector3D(w * 0.96, h * 0.25, d * 0.3), c.black);
    b.addBeveledBox(Vector3D(0, -h * 0.11, d * 0.46),
        Vector3D(w * 0.9, h * 0.55, 0.18), c.lightGrey, bevel: 0.04);
    b.addCylinder(Vector3D(-w * 0.19, -h * 0.08, d * 0.65), w * 0.16, 0.14,
        c.blue, segments: c.segments);
    b.addCylinder(Vector3D(-w * 0.19, -h * 0.08, d * 0.74), w * 0.06, 0.04,
        c.metal, segments: c.segments);
    b.addBox(Vector3D(w * 0.2, h * 0.02, d * 0.65),
        Vector3D(w * 0.18, h * 0.11, 0.13), c.red);
    b.addBox(Vector3D(w * 0.2, -h * 0.17, d * 0.65),
        Vector3D(w * 0.18, h * 0.11, 0.13), c.green);
    b.addBox(Vector3D(0, -h * 0.34, d * 0.57),
        Vector3D(w * 0.67, h * 0.08, 0.035), c.label);
    if (c.detail == MeshDetail.detailed) {
      for (var i = 0; i < 7; i++) {
        final angle = -math.pi * 0.75 + i * math.pi * 0.25;
        b.addBox(
          Vector3D(-w * 0.19 + math.cos(angle) * w * 0.2,
              -h * 0.08 + math.sin(angle) * w * 0.2, d * 0.66),
          Vector3D(0.025, 0.055, 0.025),
          c.label,
          angleZ: angle,
        );
      }
    }
  }

  static void _auxiliaryRelay(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, -h * 0.34, 0),
        Vector3D(w, h * 0.32, d), c.graphite, bevel: 0.07);
    b.addBeveledBox(Vector3D(0, h * 0.12, -0.02),
        Vector3D(w * 0.91, h * 0.7, d * 0.9), c.relayBlue, bevel: 0.09);
    b.addBox(Vector3D(0, h * 0.14, d * 0.47),
        Vector3D(w * 0.67, h * 0.3, 0.06), c.label);
    b.addBox(Vector3D(0, -h * 0.09, d * 0.53),
        Vector3D(w * 0.43, h * 0.07, 0.05), c.blue);
    for (final side in <double>[-1, 1]) {
      b.addBox(Vector3D(side * w * 0.41, h * 0.12, d * 0.22),
          Vector3D(w * 0.07, h * 0.55, d * 0.35), c.metal);
    }
  }

  static void _timer(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, 0), Vector3D(w, h, d), c.white, bevel: 0.085);
    b.addBeveledBox(Vector3D(0, h * 0.25, d * 0.47),
        Vector3D(w * 0.76, h * 0.21, 0.13), c.graphite, bevel: 0.025);
    b.addBox(Vector3D(0, h * 0.25, d * 0.56),
        Vector3D(w * 0.55, h * 0.07, 0.035), c.displayGreen);
    b.addCylinder(Vector3D(0, -h * 0.09, d * 0.57), w * 0.24, 0.18,
        c.graphite, segments: c.segments);
    b.addBox(Vector3D(0, -h * 0.09, d * 0.69),
        Vector3D(0.055, w * 0.29, 0.055), c.orange, angleZ: -0.5);
    for (final side in <double>[-1, 1]) {
      b.addBeveledBox(Vector3D(side * w * 0.22, -h * 0.35, d * 0.54),
          Vector3D(w * 0.22, h * 0.1, 0.12), c.lightGrey, bevel: 0.02);
    }
    if (c.detail != MeshDetail.board) {
      for (var i = -2; i <= 2; i++) {
        b.addBox(Vector3D(i * w * 0.13, h * 0.43, d * 0.46),
            Vector3D(w * 0.06, h * 0.035, 0.04), c.graphite);
      }
    }
  }

  static void _controlDevice(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, -h * 0.17, -d * 0.24),
        Vector3D(w * 0.68, h * 0.57, d * 0.58), c.contactBlock, bevel: 0.06);
    b.addBox(Vector3D(0, -h * 0.17, d * 0.08),
        Vector3D(w * 0.5, h * 0.28, 0.12), c.blue);
    b.addCylinder(Vector3D(0, h * 0.13, d * 0.3), w * 0.41, 0.18, c.metal,
        segments: c.segments);
    b.addCylinder(Vector3D(0, h * 0.13, d * 0.41), w * 0.34, 0.13, c.black,
        segments: c.segments);
    if (c.spec.kind == ComponentKind.selectorSwitch) {
      b.addCylinder(Vector3D(0, h * 0.13, d * 0.55), w * 0.18, 0.2,
          c.graphite, segments: c.segments);
      b.addBeveledBox(Vector3D(0, h * 0.13, d * 0.71),
          Vector3D(w * 0.17, h * 0.47, 0.18), c.graphite, bevel: 0.04);
    } else if (c.spec.kind == ComponentKind.pushButtonNC) {
      b.addFrustum(Vector3D(0, h * 0.13, d * 0.59), w * 0.27, w * 0.41,
          0.35, c.red, segments: c.segments);
      b.addCylinder(Vector3D(0, h * 0.13, d * 0.79), w * 0.41, 0.1, c.red,
          segments: c.segments);
    } else {
      b.addFrustum(Vector3D(0, h * 0.13, d * 0.57), w * 0.31, w * 0.29,
          0.28, c.green, segments: c.segments);
      b.addCylinder(Vector3D(0, h * 0.13, d * 0.73), w * 0.29, 0.07,
          c.green, segments: c.segments);
    }
  }

  static void _sensor(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addCylinder(Vector3D(0, 0, 0), w * 0.3, h * 0.63, c.metal,
        axis: MeshAxis.y, segments: c.segments);
    for (var i = -3; i <= 3; i++) {
      b.addCylinder(Vector3D(0, i * h * 0.065, 0), w * 0.315, h * 0.018,
          c.midGrey, axis: MeshAxis.y, segments: c.segments);
    }
    b.addCylinder(Vector3D(0, h * 0.33, 0), w * 0.31, h * 0.06, c.cyan,
        axis: MeshAxis.y, segments: c.segments);
    b.addCylinder(Vector3D(0, -h * 0.31, 0), w * 0.38, h * 0.11,
        c.graphite, axis: MeshAxis.y, segments: c.segments);
    b.addBeveledBox(Vector3D(0, -h * 0.41, -d * 0.08),
        Vector3D(w * 0.58, h * 0.18, d * 0.6), c.contactBlock, bevel: 0.04);
  }

  static void _indicator(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    final lens = switch (c.colorName) {
      'green' => c.green,
      'yellow' => c.yellow,
      _ => c.red,
    };
    final lensDark = c.colorName == 'red' || c.colorName.isEmpty
        ? c.redDark
        : c.graphite;
    b.addBeveledBox(Vector3D(0, -h * 0.25, -d * 0.18),
        Vector3D(w * 0.6, h * 0.43, d * 0.55), c.contactBlock, bevel: 0.05);
    b.addCylinder(Vector3D(0, h * 0.1, d * 0.23), w * 0.39, 0.2, c.metal,
        segments: c.segments);
    b.addCylinder(Vector3D(0, h * 0.1, d * 0.38), w * 0.32, 0.16, lensDark,
        segments: c.segments);
    b.addSphere(Vector3D(0, h * 0.1, d * 0.49), w * 0.31, lens,
        segments: c.segments, rings: c.rings, scale: const Vector3D(1, 1, 0.58));
    b.addSphere(Vector3D(-w * 0.09, h * 0.2, d * 0.65), w * 0.07, c.label,
        segments: c.segments, rings: c.rings);
  }

  static void _motor(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    final centerY = -h * 0.08;
    final radius = h * 0.29;
    b.addCylinder(Vector3D(0, centerY, 0), radius, w * 0.58, c.motorBlue,
        axis: MeshAxis.x, segments: c.segments);
    for (final side in <double>[-1, 1]) {
      b.addCylinder(Vector3D(side * w * 0.32, centerY, 0), radius * 1.06,
          w * 0.1, c.motorDark, axis: MeshAxis.x, segments: c.segments);
    }
    for (final side in <double>[-1, 1]) {
      b.addBox(Vector3D(0, centerY + side * radius * 0.78, 0),
          Vector3D(w * 0.51, h * 0.065, d * 0.73), c.motorDark);
      b.addBox(Vector3D(0, centerY, side * radius * 0.83),
          Vector3D(w * 0.51, h * 0.38, d * 0.07), c.motorDark);
    }
    b.addCylinder(Vector3D(w * 0.43, centerY, 0), radius * 0.34, w * 0.22,
        c.metal, axis: MeshAxis.x, segments: c.segments);
    b.addCylinder(Vector3D(w * 0.55, centerY, 0), radius * 0.2, w * 0.08,
        c.lightGrey, axis: MeshAxis.x, segments: c.segments);
    b.addCylinder(Vector3D(-w * 0.4, centerY, 0), radius * 0.9, w * 0.08,
        c.graphite, axis: MeshAxis.x, segments: c.segments);
    for (final side in <double>[-1, 1]) {
      b.addBeveledBox(Vector3D(side * w * 0.22, -h * 0.43, 0),
          Vector3D(w * 0.22, h * 0.13, d * 0.63), c.motorDark, bevel: 0.035);
    }
    b.addBeveledBox(Vector3D(0, h * 0.35, 0),
        Vector3D(w * 0.43, h * 0.24, d * 0.58), c.motorDark, bevel: 0.06);
    b.addBox(Vector3D(0, h * 0.35, d * 0.31),
        Vector3D(w * 0.32, h * 0.14, 0.05), c.graphite);
    if (c.detail == MeshDetail.detailed) {
      for (var i = -3; i <= 3; i++) {
        b.addBox(Vector3D(i * w * 0.07, centerY + radius * 0.85, 0),
            Vector3D(w * 0.025, h * 0.09, d * 0.68), c.motorBlue);
      }
    }
  }

  static void _supply(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, 0), Vector3D(w, h, d), c.lightGrey,
        bevel: 0.09);
    b.addBox(Vector3D(0, 0, -d * 0.58), Vector3D(w * 0.7, h * 0.12, 0.14),
        c.graphite);
    b.addBeveledBox(Vector3D(0, h * 0.17, d * 0.47),
        Vector3D(w * 0.72, h * 0.29, 0.14), c.black, bevel: 0.03);
    b.addBox(Vector3D(0, h * 0.17, d * 0.56),
        Vector3D(w * 0.5, h * 0.06, 0.035), c.cyan);
    if (c.spec.kind == ComponentKind.dcSupply) {
      for (var i = -2; i <= 2; i++) {
        b.addBox(Vector3D(i * w * 0.13, -h * 0.22, d * 0.49),
            Vector3D(w * 0.055, h * 0.22, 0.055), c.graphite);
      }
    } else if (c.spec.kind == ComponentKind.acSupply) {
      b.addCylinder(Vector3D(0, -h * 0.2, d * 0.52), w * 0.23, 0.12,
          c.graphite, segments: c.segments);
      b.addCylinder(Vector3D(0, -h * 0.2, d * 0.61), w * 0.1, 0.08,
          c.metal, segments: c.segments);
    } else {
      for (var i = -1; i <= 1; i++) {
        b.addSphere(Vector3D(i * w * 0.22, -h * 0.16, d * 0.54), w * 0.07,
            i == 0 ? c.orange : c.green,
            segments: c.segments, rings: c.rings);
      }
      b.addBox(Vector3D(0, -h * 0.34, d * 0.45),
          Vector3D(w * 0.82, h * 0.13, 0.1), c.graphite);
    }
  }

  static void _meter(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, 0), Vector3D(w, h, d), c.graphite,
        bevel: 0.1);
    b.addBeveledBox(Vector3D(0, h * 0.08, d * 0.46),
        Vector3D(w * 0.82, h * 0.52, 0.16), c.black, bevel: 0.045);
    b.addBox(Vector3D(0, h * 0.08, d * 0.56),
        Vector3D(w * 0.64, h * 0.34, 0.04), c.displayDark);
    for (var i = -1; i <= 1; i++) {
      b.addBox(Vector3D(i * w * 0.17, h * 0.08, d * 0.6),
          Vector3D(w * 0.1, h * 0.055, 0.025),
          c.spec.kind == ComponentKind.voltmeter ? c.displayGreen : c.cyan);
      b.addBox(Vector3D(i * w * 0.17, h * 0.16, d * 0.6),
          Vector3D(w * 0.1, h * 0.025, 0.025),
          c.spec.kind == ComponentKind.voltmeter ? c.displayGreen : c.cyan);
    }
    if (c.spec.kind == ComponentKind.voltmeter) {
      b.addCylinder(Vector3D(0, -h * 0.31, d * 0.51), w * 0.12, 0.12,
          c.midGrey, segments: c.segments);
    } else {
      b.addBox(Vector3D(0, -h * 0.3, -d * 0.43),
          Vector3D(w * 0.74, h * 0.18, d * 0.3), c.metal);
    }
  }

  static void _terminalBlock(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(Vector3D(0, 0, 0), Vector3D(w, h, d), c.bornier,
        bevel: 0.09);
    b.addBox(Vector3D(0, 0, -d * 0.56), Vector3D(w * 0.7, h * 0.16, 0.12),
        c.graphite);
    b.addBox(Vector3D(0, 0, d * 0.48), Vector3D(w * 0.28, h * 0.7, 0.1),
        c.metal);
    b.addBox(Vector3D(0, 0, d * 0.57), Vector3D(w * 0.54, h * 0.22, 0.05),
        c.label);
    for (final side in <double>[-1, 1]) {
      b.addBox(Vector3D(side * w * 0.39, 0, d * 0.25),
          Vector3D(w * 0.09, h * 0.66, d * 0.35), c.bornierDark);
    }
  }

  static void _differentialBreaker(_MeshContext c) {
    _circuitBreaker(c);
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(-w * 0.23, h * 0.03, d * 0.76),
      Vector3D(w * 0.18, h * 0.26, 0.18),
      c.blue,
      bevel: 0.025,
    );
    b.addBeveledBox(
      Vector3D(w * 0.31, -h * 0.22, d * 0.63),
      Vector3D(w * 0.18, h * 0.1, 0.1),
      c.orange,
      bevel: 0.02,
    );
    b.addBox(
      Vector3D(0, -h * 0.39, d * 0.54),
      Vector3D(w * 0.68, h * 0.06, 0.04),
      c.graphite,
    );
  }

  static void _motorBreaker(_MeshContext c) {
    _thermalRelay(c);
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(w * 0.19, -h * 0.11, d * 0.67),
      Vector3D(w * 0.25, h * 0.25, 0.18),
      c.graphite,
      bevel: 0.04,
    );
    b.addCylinder(
      Vector3D(w * 0.19, -h * 0.11, d * 0.79),
      w * 0.1,
      0.08,
      c.red,
      segments: c.segments,
    );
    b.addBox(
      Vector3D(0, h * 0.47, d * 0.5),
      Vector3D(w * 0.74, h * 0.06, 0.08),
      c.metal,
    );
  }

  static void _emergencyStop(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(0, 0, -d * 0.12),
      Vector3D(w * 0.92, h * 0.82, d * 0.45),
      c.yellow,
      bevel: 0.09,
    );
    b.addBeveledBox(
      Vector3D(0, -h * 0.28, -d * 0.3),
      Vector3D(w * 0.58, h * 0.25, d * 0.5),
      c.contactBlock,
      bevel: 0.05,
    );
    b.addCylinder(
      Vector3D(0, h * 0.08, d * 0.24),
      w * 0.35,
      0.22,
      c.graphite,
      segments: c.segments,
    );
    b.addFrustum(
      Vector3D(0, h * 0.08, d * 0.52),
      w * 0.28,
      w * 0.43,
      0.42,
      c.red,
      segments: c.segments,
    );
    b.addCylinder(
      Vector3D(0, h * 0.08, d * 0.77),
      w * 0.43,
      0.12,
      c.red,
      segments: c.segments,
    );
    if (c.detail == MeshDetail.detailed) {
      for (var i = 0; i < 4; i++) {
        final angle = i * math.pi / 2;
        b.addCylinder(
          Vector3D(math.cos(angle) * w * 0.37, math.sin(angle) * h * 0.31, d * 0.16),
          0.045,
          0.04,
          c.metal,
          segments: c.segments,
        );
      }
    }
  }

  static void _rotarySwitch(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(0, 0, -d * 0.16),
      Vector3D(w * 0.9, h * 0.84, d * 0.52),
      c.yellow,
      bevel: 0.1,
    );
    b.addCylinder(
      Vector3D(0, 0, d * 0.24),
      w * 0.36,
      0.22,
      c.graphite,
      segments: c.segments,
    );
    b.addCylinder(
      Vector3D(0, 0, d * 0.43),
      w * 0.29,
      0.18,
      c.redDark,
      segments: c.segments,
    );
    b.addBeveledBox(
      Vector3D(0, h * 0.06, d * 0.66),
      Vector3D(w * 0.18, h * 0.58, 0.24),
      c.red,
      bevel: 0.07,
    );
    b.addBox(
      Vector3D(0, h * 0.31, d * 0.55),
      Vector3D(w * 0.07, h * 0.09, 0.05),
      c.label,
    );
  }

  static void _offDelayTimer(_MeshContext c) {
    _timer(c);
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(w * 0.29, -h * 0.1, d * 0.57),
      Vector3D(w * 0.16, h * 0.25, 0.14),
      c.blue,
      bevel: 0.025,
    );
    b.addBox(
      Vector3D(-w * 0.25, h * 0.25, d * 0.6),
      Vector3D(w * 0.13, h * 0.055, 0.03),
      c.orange,
    );
  }

  static void _limitSwitch(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(0, -h * 0.14, 0),
      Vector3D(w * 0.62, h * 0.64, d * 0.72),
      c.graphite,
      bevel: 0.07,
    );
    b.addBeveledBox(
      Vector3D(0, h * 0.24, d * 0.05),
      Vector3D(w * 0.46, h * 0.2, d * 0.58),
      c.black,
      bevel: 0.04,
    );
    b.addBox(
      Vector3D(w * 0.12, h * 0.36, d * 0.32),
      Vector3D(w * 0.1, h * 0.42, 0.09),
      c.metal,
      angleZ: -0.48,
    );
    b.addCylinder(
      Vector3D(w * 0.28, h * 0.45, d * 0.35),
      w * 0.15,
      0.18,
      c.lightGrey,
      segments: c.segments,
    );
    b.addBox(
      Vector3D(0, -h * 0.13, d * 0.41),
      Vector3D(w * 0.35, h * 0.09, 0.04),
      c.label,
    );
  }

  static void _singlePhaseMotor(_MeshContext c) {
    _motor(c);
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(-w * 0.18, h * 0.39, -d * 0.34),
      Vector3D(w * 0.24, h * 0.29, d * 0.42),
      c.graphite,
      bevel: 0.07,
    );
    b.addCylinder(
      Vector3D(-w * 0.18, h * 0.39, d * 0.03),
      w * 0.1,
      h * 0.23,
      c.metal,
      axis: MeshAxis.y,
      segments: c.segments,
    );
  }

  static void _transformer(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(0, -h * 0.42, 0),
      Vector3D(w * 0.94, h * 0.15, d * 0.9),
      c.graphite,
      bevel: 0.04,
    );
    for (final side in <double>[-1, 1]) {
      b.addBox(
        Vector3D(side * w * 0.34, 0, 0),
        Vector3D(w * 0.18, h * 0.72, d * 0.72),
        c.metal,
      );
    }
    b.addBox(
      Vector3D(0, h * 0.31, 0),
      Vector3D(w * 0.84, h * 0.15, d * 0.74),
      c.metal,
    );
    b.addBox(
      Vector3D(0, -h * 0.28, 0),
      Vector3D(w * 0.84, h * 0.14, d * 0.74),
      c.metal,
    );
    b.addCylinder(
      Vector3D(0, 0, d * 0.08),
      w * 0.24,
      h * 0.48,
      c.orange,
      axis: MeshAxis.y,
      segments: c.segments,
    );
    for (var i = -4; i <= 4; i++) {
      b.addCylinder(
        Vector3D(0, i * h * 0.052, d * 0.08),
        w * 0.255,
        h * 0.012,
        c.brass,
        axis: MeshAxis.y,
        segments: c.segments,
      );
    }
    b.addBeveledBox(
      Vector3D(0, h * 0.43, d * 0.18),
      Vector3D(w * 0.7, h * 0.12, d * 0.4),
      c.bornier,
      bevel: 0.025,
    );
    if (c.detail == MeshDetail.detailed) {
      for (var i = -3; i <= 3; i++) {
        b.addBox(
          Vector3D(i * w * 0.1, 0, -d * 0.39),
          Vector3D(0.025, h * 0.66, 0.025),
          c.graphite,
        );
      }
    }
  }

  static void _digitalCounter(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    b.addBeveledBox(
      Vector3D(0, 0, 0),
      Vector3D(w, h, d),
      c.graphite,
      bevel: 0.09,
    );
    b.addBeveledBox(
      Vector3D(0, h * 0.1, d * 0.49),
      Vector3D(w * 0.84, h * 0.45, 0.14),
      c.black,
      bevel: 0.035,
    );
    for (var digit = -1; digit <= 1; digit++) {
      final x = digit * w * 0.23;
      for (final y in <double>[-0.09, 0.09]) {
        b.addBox(
          Vector3D(x, h * 0.1 + y * h, d * 0.6),
          Vector3D(w * 0.15, h * 0.035, 0.025),
          c.red,
        );
      }
      b.addBox(
        Vector3D(x, h * 0.1, d * 0.6),
        Vector3D(w * 0.15, h * 0.028, 0.025),
        c.redDark,
      );
      for (final side in <double>[-1, 1]) {
        b.addBox(
          Vector3D(x + side * w * 0.075, h * 0.1, d * 0.6),
          Vector3D(w * 0.025, h * 0.19, 0.025),
          c.red,
        );
      }
    }
    b.addBox(
      Vector3D(0, -h * 0.31, d * 0.5),
      Vector3D(w * 0.55, h * 0.08, 0.04),
      c.label,
    );
  }

  /// Lightweight fallback for extended catalog devices. Bundled GLBs remain the
  /// normal renderer; this path keeps direct procedural previews functional.
  static void _extendedDevice(_MeshContext c) {
    final b = c.builder;
    final w = c.width;
    final h = c.height;
    final d = c.depth;
    final variant = c.spec.kind.index % 5;
    switch (c.spec.category) {
      case ComponentCategory.motors:
        b.addCylinder(const Vector3D(0, 0, 0), h * 0.3, w * 0.62, c.motorBlue,
            axis: MeshAxis.x, segments: c.segments);
        for (var index = 0; index < 6 + variant; index++) {
          final angle = index * math.pi / (6 + variant);
          b.addBox(
            Vector3D(0, math.cos(angle) * h * 0.31, math.sin(angle) * h * 0.31),
            Vector3D(w * 0.55, 0.045, 0.045),
            c.motorDark,
          );
        }
        b.addCylinder(Vector3D(w * 0.42, 0, 0), h * 0.1, w * 0.22,
            c.metal, axis: MeshAxis.x, segments: c.segments);
      case ComponentCategory.signals:
        b.addBeveledBox(Vector3D(0, 0, -0.1), Vector3D(w * 0.8, h * 0.85, d * 0.6),
            c.graphite, bevel: 0.05);
        b.addSphere(Vector3D(0, 0, d * 0.35), math.min(w, h) * 0.3,
            variant.isEven ? c.red : c.green, segments: c.segments, rings: c.rings);
      case ComponentCategory.sensors:
        b.addBeveledBox(const Vector3D(0, 0, 0), Vector3D(w * 0.65, h * 0.7, d * 0.7),
            c.midGrey, bevel: 0.06);
        b.addCylinder(Vector3D(0, h * 0.12, d * 0.4), math.min(w, h) * 0.2,
            0.14, variant.isEven ? c.glass : c.brass, segments: c.segments);
      default:
        b.addBeveledBox(const Vector3D(0, 0, 0), Vector3D(w, h, d), c.white, bevel: 0.08);
        b.addBox(Vector3D(0, 0, -d * 0.56), Vector3D(w * 0.7, h * 0.14, 0.14),
            c.graphite);
        b.addBeveledBox(Vector3D(0, h * 0.05, d * 0.45),
            Vector3D(w * 0.76, h * 0.56, 0.16), c.lightGrey, bevel: 0.035);
        for (var index = 0; index <= variant; index++) {
          b.addBox(
            Vector3D((index - variant / 2) * w * 0.12, h * 0.06, d * 0.58),
            Vector3D(w * 0.055, h * 0.28, 0.08),
            c.blue,
          );
        }
        b.addBox(Vector3D(0, -h * 0.31, d * 0.48),
            Vector3D(w * 0.64, h * 0.08, 0.035), c.label);
    }
  }

  static void _terminalHardware(
    _MeshContext c,
    Vector3D position,
    TerminalKind kind, {
    required double radius,
  }) {
    final b = c.builder;
    final color = switch (kind) {
      TerminalKind.earth => c.green,
      TerminalKind.coil => c.metal,
      TerminalKind.neutral => c.blue,
      _ => c.brass,
    };
    b.addCylinder(position - const Vector3D(0, 0, 0.035), radius * 1.35,
        0.055, c.graphite, segments: c.segments);
    b.addCylinder(position, radius, 0.09, color, segments: c.segments);
    if (c.detail == MeshDetail.detailed) {
      b.addBox(position + const Vector3D(0, 0, 0.052),
          Vector3D(radius * 1.25, 0.022, 0.018), c.black);
      b.addBox(position + const Vector3D(0, 0, 0.053),
          Vector3D(0.022, radius * 1.25, 0.018), c.black);
    }
  }

  static double _depthFor(ComponentKind kind) => switch (kind) {
        ComponentKind.motor3Phase => 1.65,
        ComponentKind.motor1Phase => 1.45,
        ComponentKind.indicator ||
        ComponentKind.pushButtonNO ||
        ComponentKind.pushButtonNC ||
        ComponentKind.emergencyStop ||
        ComponentKind.selectorSwitch ||
        ComponentKind.rotarySwitch => 1.05,
        ComponentKind.sensor || ComponentKind.limitSwitch => 0.9,
        _ => 0.82,
      };

  static Vector3D _terminalPosition(
    TerminalDefinition terminal,
    ComponentSpec spec,
    double depth,
  ) {
    return Vector3D(
      (terminal.position.x / spec.size.width - 0.5) * spec.size.width / 48,
      (0.5 - terminal.position.y / spec.size.height) * spec.size.height / 48,
      depth * 0.78,
    );
  }
}

class _MeshContext {
  const _MeshContext(
    this.builder,
    this.spec,
    this.detail,
    this.width,
    this.height,
    this.depth,
    this.colorName,
  );

  final MeshBuilder builder;
  final ComponentSpec spec;
  final MeshDetail detail;
  final double width;
  final double height;
  final double depth;
  final String colorName;

  int get segments => switch (detail) {
        MeshDetail.board => 8,
        MeshDetail.preview => 12,
        MeshDetail.detailed => 24,
      };
  int get rings => switch (detail) {
        MeshDetail.board => 3,
        MeshDetail.preview => 5,
        MeshDetail.detailed => 9,
      };

  int get white => 0xffe7ebee;
  int get lightGrey => 0xffbdc8cf;
  int get midGrey => 0xff778691;
  int get label => 0xfff5f3e9;
  int get graphite => 0xff28343d;
  int get black => 0xff10161b;
  int get blue => 0xff087dc1;
  int get relayBlue => 0xff86b8c4;
  int get cyan => 0xff20c4df;
  int get metal => 0xffa8b2b8;
  int get brass => 0xffc59a50;
  int get green => 0xff25a66a;
  int get red => 0xffdb3b36;
  int get redDark => 0xff8e201f;
  int get lightRed => 0xffff9a8f;
  int get orange => 0xffe69a2d;
  int get yellow => 0xffe8b83d;
  int get glass => 0xffc6d9d8;
  int get contactBlock => 0xffd7d9d2;
  int get displayGreen => 0xff62e6a4;
  int get displayDark => 0xff102a27;
  int get motorBlue => 0xff17679c;
  int get motorDark => 0xff0e476e;
  int get bornier => 0xffd6a64d;
  int get bornierDark => 0xffa97930;
}
