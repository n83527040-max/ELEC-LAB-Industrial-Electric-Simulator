import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/terminal.dart';
import 'mesh_model.dart';

abstract final class ProceduralMeshes {
  static DeviceMesh forComponent(CircuitComponent component) {
    final spec = ComponentCatalog.specOf(component.kind);
    final width = spec.size.width / 48;
    final height = spec.size.height / 48;
    final depth = switch (component.kind) {
      ComponentKind.motor3Phase => 1.8,
      ComponentKind.indicator || ComponentKind.pushButtonNO ||
          ComponentKind.pushButtonNC => 1.0,
      _ => 0.85,
    };
    final builder = MeshBuilder();
    const white = 0xffe8edf2;
    const light = 0xffc5d3df;
    const dark = 0xff202b38;
    const black = 0xff101720;
    const blue = 0xff087ff5;
    const metal = 0xff9eacb9;

    switch (component.kind) {
      case ComponentKind.contactor:
        builder.addBox(Vector3D(0, 0, 0), Vector3D(width, height, depth), white);
        builder.addBox(
          Vector3D(0, height * 0.36, 0.03),
          Vector3D(width * 0.98, height * 0.25, depth * 1.05),
          dark,
        );
        builder.addBox(
          Vector3D(0, -height * 0.39, 0.02),
          Vector3D(width * 0.98, height * 0.18, depth),
          dark,
        );
        builder.addBox(
          Vector3D(0, 0, depth * 0.57),
          Vector3D(width * 0.55, height * 0.28, 0.18),
          black,
        );
        builder.addBox(
          Vector3D(0, 0.03, depth * 0.7),
          Vector3D(width * 0.4, height * 0.09, 0.15),
          blue,
        );
      case ComponentKind.circuitBreaker:
      case ComponentKind.fuse:
        builder.addBox(Vector3D(0, 0, 0), Vector3D(width, height, depth), white);
        builder.addBox(
          Vector3D(0, height * 0.28, depth * 0.48),
          Vector3D(width * 0.75, height * 0.18, 0.08),
          light,
        );
        builder.addBox(
          Vector3D(0, -height * 0.02, depth * 0.62),
          Vector3D(width * 0.5, height * 0.3, 0.2),
          blue,
        );
      case ComponentKind.thermalRelay:
        builder.addBox(Vector3D(0, 0, 0), Vector3D(width, height, depth), dark);
        builder.addBox(
          Vector3D(0, -height * 0.16, depth * 0.55),
          Vector3D(width * 0.92, height * 0.58, 0.18),
          white,
        );
        builder.addCylinder(
          Vector3D(-width * 0.2, -height * 0.1, depth * 0.75),
          width * 0.1,
          0.15,
          blue,
        );
        builder.addCylinder(
          Vector3D(width * 0.2, -height * 0.1, depth * 0.75),
          width * 0.1,
          0.15,
          0xffe53935,
        );
      case ComponentKind.auxiliaryRelay:
      case ComponentKind.timer:
        builder.addBox(Vector3D(0, 0, 0), Vector3D(width, height, depth), white);
        builder.addBox(
          Vector3D(0, height * 0.22, depth * 0.55),
          Vector3D(width * 0.72, height * 0.18, 0.12),
          dark,
        );
        builder.addCylinder(
          Vector3D(0, -height * 0.16, depth * 0.65),
          width * 0.24,
          0.16,
          dark,
        );
        builder.addBox(
          Vector3D(0, -height * 0.16, depth * 0.78),
          Vector3D(0.06, width * 0.3, 0.05),
          blue,
        );
      case ComponentKind.pushButtonNO:
      case ComponentKind.pushButtonNC:
      case ComponentKind.selectorSwitch:
      case ComponentKind.sensor:
        builder.addBox(Vector3D(0, 0, -0.15), Vector3D(width, height, depth), black);
        final color = component.kind == ComponentKind.pushButtonNO
            ? 0xff22b573
            : component.kind == ComponentKind.pushButtonNC
                ? 0xffe53935
                : component.kind == ComponentKind.sensor
                    ? 0xff26c6da
                    : metal;
        if (component.kind == ComponentKind.selectorSwitch) {
          builder.addBox(
            Vector3D(0, 0, depth * 0.55),
            Vector3D(width * 0.16, height * 0.55, 0.22),
            dark,
          );
        } else {
          builder.addCylinder(
            Vector3D(0, 0, depth * 0.5),
            width * 0.32,
            0.38,
            color,
          );
        }
      case ComponentKind.indicator:
        builder.addCylinder(
          Vector3D(0, -height * 0.12, 0),
          width * 0.25,
          height * 0.55,
          dark,
          axis: MeshAxis.y,
        );
        builder.addCylinder(
          Vector3D(0, height * 0.22, 0),
          width * 0.36,
          height * 0.35,
          0xffe53935,
          axis: MeshAxis.y,
        );
      case ComponentKind.motor3Phase:
        builder.addCylinder(
          Vector3D(0, -height * 0.08, 0),
          height * 0.36,
          width * 0.62,
          0xff0869c8,
          axis: MeshAxis.x,
          segments: 24,
        );
        for (var index = -3; index <= 3; index++) {
          builder.addBox(
            Vector3D(index * width * 0.075, -height * 0.08, 0),
            Vector3D(0.055, height * 0.76, height * 0.76),
            0xff0759aa,
          );
        }
        builder.addCylinder(
          Vector3D(width * 0.42, -height * 0.08, 0),
          height * 0.13,
          width * 0.28,
          metal,
          axis: MeshAxis.x,
        );
        builder.addBox(
          Vector3D(0, -height * 0.46, 0),
          Vector3D(width * 0.72, height * 0.12, depth * 0.65),
          dark,
        );
        builder.addBox(
          Vector3D(0, height * 0.3, 0),
          Vector3D(width * 0.35, height * 0.22, depth * 0.5),
          0xff0759aa,
        );
      case ComponentKind.dcSupply:
      case ComponentKind.acSupply:
      case ComponentKind.threePhaseSupply:
        builder.addBox(Vector3D(0, 0, 0), Vector3D(width, height, depth), light);
        builder.addBox(
          Vector3D(0, height * 0.08, depth * 0.55),
          Vector3D(width * 0.72, height * 0.34, 0.12),
          black,
        );
        builder.addBox(
          Vector3D(0, height * 0.08, depth * 0.63),
          Vector3D(width * 0.5, height * 0.06, 0.03),
          0xff00c8ff,
        );
        builder.addCylinder(
          Vector3D(0, -height * 0.3, depth * 0.58),
          width * 0.12,
          0.14,
          dark,
        );
      case ComponentKind.voltmeter:
      case ComponentKind.ammeter:
        builder.addBox(Vector3D(0, 0, 0), Vector3D(width, height, depth), dark);
        builder.addBox(
          Vector3D(0, height * 0.08, depth * 0.55),
          Vector3D(width * 0.72, height * 0.38, 0.12),
          black,
        );
        builder.addBox(
          Vector3D(0, height * 0.08, depth * 0.63),
          Vector3D(width * 0.48, height * 0.07, 0.03),
          0xff52ffa8,
        );
      case ComponentKind.terminalBlock:
        builder.addBox(
          Vector3D(0, 0, 0),
          Vector3D(width, height, depth),
          0xffd8a242,
        );
        builder.addBox(
          Vector3D(0, 0, depth * 0.52),
          Vector3D(width * 0.6, height * 0.45, 0.08),
          light,
        );
    }

    final terminals = <MeshTerminal>[];
    for (final terminal in spec.terminals) {
      final position = _terminalPosition(terminal, spec, depth);
      terminals.add(
        MeshTerminal(id: terminal.id, label: terminal.label, position: position),
      );
      if (terminal.kind != TerminalKind.earth) {
        builder.addCylinder(
          position,
          0.075,
          0.08,
          terminal.kind == TerminalKind.coil ? metal : 0xffb88a44,
          segments: 10,
        );
      }
    }
    return builder.build(terminals);
  }

  static Vector3D _terminalPosition(
    TerminalDefinition terminal,
    ComponentSpec spec,
    double depth,
  ) {
    return Vector3D(
      (terminal.position.x / spec.size.width - 0.5) * spec.size.width / 48,
      (0.5 - terminal.position.y / spec.size.height) * spec.size.height / 48,
      depth * 0.62,
    );
  }
}
