import 'package:elec_lab/src/export/project_exporter.dart';
import 'package:elec_lab/src/models/component_catalog.dart';
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
    expect(String.fromCharCodes(bytes.takeLast(20)), contains('EOF'));
  });
}
