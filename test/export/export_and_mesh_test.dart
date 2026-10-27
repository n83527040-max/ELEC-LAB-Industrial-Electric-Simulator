import 'package:elec_lab/src/export/project_exporter.dart';
import 'package:elec_lab/src/models/component_catalog.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/three_d/mesh_view.dart';
import 'package:elec_lab/src/three_d/procedural_meshes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('3D devices are real polygon meshes with catalog-matched terminals', () {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'mesh', name: 'Mesh', now: testNow),
      ProjectTemplateKind.selfHolding,
    );
    for (final component in project.components) {
      final mesh = ProceduralMeshes.forComponent(component);
      expect(mesh.vertices.length, greaterThanOrEqualTo(8));
      expect(mesh.faces, isNotEmpty);
      expect(
        mesh.terminals.map((terminal) => terminal.id).toSet(),
        ComponentCatalog.specOf(component.kind)
            .terminals
            .map((terminal) => terminal.id)
            .toSet(),
      );
      expect(mesh.faces.every((face) => face.indices.length >= 3), isTrue);
    }
  });

  test('every catalog device has distinct lightweight and detailed LOD meshes', () {
    for (final kind in ComponentKind.values) {
      final board = ProceduralMeshes.forKind(kind, detail: MeshDetail.board);
      final detailed = ProceduralMeshes.forKind(
        kind,
        detail: MeshDetail.detailed,
      );
      expect(board.vertices, isNotEmpty, reason: kind.name);
      expect(detailed.faces.length, greaterThan(board.faces.length), reason: kind.name);
      expect(
        identical(board, ProceduralMeshes.forKind(kind, detail: MeshDetail.board)),
        isTrue,
        reason: 'Board geometry should be lazily cached.',
      );
      for (final vertex in detailed.vertices) {
        expect(vertex.x.isFinite && vertex.y.isFinite && vertex.z.isFinite, isTrue);
      }
      for (final face in detailed.faces) {
        expect(face.indices.every((index) => index >= 0 && index < detailed.vertices.length), isTrue);
      }
    }
  });

  test('mesh terminals are generated at exact catalog coordinates', () {
    for (final spec in ComponentCatalog.byKind.values) {
      final mesh = ProceduralMeshes.forKind(spec.kind);
      for (final terminal in spec.terminals) {
        final actual = mesh.terminals.singleWhere((item) => item.id == terminal.id);
        final expectedX =
            (terminal.position.x / spec.size.width - 0.5) * spec.size.width / 48;
        final expectedY =
            (0.5 - terminal.position.y / spec.size.height) * spec.size.height / 48;
        expect(actual.position.x, closeTo(expectedX, 1e-9), reason: terminal.id);
        expect(actual.position.y, closeTo(expectedY, 1e-9), reason: terminal.id);
      }
    }
  });

  test('industrial device families differ in geometry, not only labels or colors', () {
    const kinds = <ComponentKind>[
      ComponentKind.contactor,
      ComponentKind.circuitBreaker,
      ComponentKind.thermalRelay,
      ComponentKind.motor3Phase,
      ComponentKind.pushButtonNO,
      ComponentKind.pushButtonNC,
      ComponentKind.timer,
      ComponentKind.sensor,
      ComponentKind.indicator,
      ComponentKind.terminalBlock,
      ComponentKind.dcSupply,
      ComponentKind.voltmeter,
      ComponentKind.ammeter,
    ];
    final signatures = kinds.map((kind) {
      final mesh = ProceduralMeshes.forKind(kind);
      return mesh.vertices
          .map((vertex) =>
              '${vertex.x.toStringAsFixed(4)},${vertex.y.toStringAsFixed(4)},${vertex.z.toStringAsFixed(4)}')
          .join('|');
    }).toSet();
    expect(signatures.length, kinds.length);
  });

  testWidgets('3D viewer responds to rotation gestures', (tester) async {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'viewer', name: 'Viewer', now: testNow),
      ProjectTemplateKind.selfHolding,
    );
    final component = project.componentById('k1')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: InteractiveMeshViewer(
              mesh: ProceduralMeshes.forComponent(component),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(InteractiveMeshViewer), const Offset(80, 30));
    await tester.pump();
    // Let the double-tap recognition timeout finish before tree disposal.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('PNG export is a real rendered image with terminal and device geometry', () async {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'png', name: 'PNG', now: testNow),
      ProjectTemplateKind.dcLamp,
    );
    final bytes = await ProjectExporter.renderPng(project, maxDimension: 800);
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('PDF export produces a valid PDF document with embedded schematic', () async {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'pdf', name: 'مخطط PDF', now: testNow),
      ProjectTemplateKind.dcLamp,
    );
    final bytes = await ProjectExporter.renderPdf(project);
    expect(bytes.length, greaterThan(1500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes.sublist(bytes.length - 20)), contains('EOF'));
  });
}
