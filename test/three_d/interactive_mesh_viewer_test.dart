import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/three_d/glb_mesh_loader.dart';
import 'package:elec_lab/src/three_d/mesh_view.dart';
import 'package:elec_lab/src/three_d/procedural_meshes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3D viewer responds to rotation gestures', (tester) async {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'viewer', name: 'Viewer', now: testNow),
      ProjectTemplateKind.selfHolding,
    );
    final component = project.componentById('k1')!;
    final mesh = await DeviceMeshRepository.forComponent(
      component,
      detail: MeshDetail.detailed,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: InteractiveMeshViewer(mesh: mesh),
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
  }, timeout: const Timeout(Duration(seconds: 45)));
}
