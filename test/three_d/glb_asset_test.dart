import 'dart:convert';

import 'package:elec_lab/src/models/component_catalog.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/three_d/glb_mesh_loader.dart';
import 'package:elec_lab/src/three_d/procedural_meshes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 81 bundled GLB assets decode and match manifest and terminals', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/models/manifest.json'),
    ) as Map<String, dynamic>;
    final models = manifest['models'] as List;
    expect(models, hasLength(ComponentKind.values.length));
    var files = 0;
    for (final rawModel in models) {
      final model = rawModel as Map<String, dynamic>;
      final kind = ComponentKind.values.byName(model['kind'] as String);
      final lods = model['lods'] as Map<String, dynamic>;
      for (final detail in MeshDetail.values) {
        final info = lods[detail.name] as Map<String, dynamic>;
        final path = info['path'] as String;
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, info['bytes'], reason: path);
        final mesh = GlbMeshDecoder.decode(data, kind: kind);
        files++;
        expect(mesh.faces, hasLength(info['triangles']), reason: path);
        expect(mesh.vertices, hasLength(info['vertices']), reason: path);
        expect(mesh.faces.length, greaterThan(100), reason: path);
        expect(
          mesh.terminals.map((terminal) => terminal.id).toSet(),
          ComponentCatalog.specOf(kind)
              .terminals
              .map((terminal) => terminal.id)
              .toSet(),
          reason: path,
        );
        final validTriangles = mesh.faces.every(
          (face) =>
              face.indices.length == 3 &&
              face.indices.every(
                (index) => index >= 0 && index < mesh.vertices.length,
              ),
        );
        // Validate every triangle without allocating hundreds of thousands of
        // individual matcher expectations in one Flutter test shell.
        expect(validTriangles, isTrue, reason: path);
      }
    }
    expect(files, 81);
  });

  test('GLB indicator material follows real component color property', () async {
    final red = await DeviceMeshRepository.forKind(
      ComponentKind.indicator,
      color: 'red',
    );
    final green = await DeviceMeshRepository.forKind(
      ComponentKind.indicator,
      color: 'green',
    );
    expect(red.faces.map((face) => face.colorValue).toSet(), contains(0xffdb3b36));
    expect(green.faces.map((face) => face.colorValue).toSet(), contains(0xff25a66a));
    expect(identical(red, green), isFalse);
  });

  test('invalid GLB is rejected instead of replaced by fake geometry', () {
    expect(
      () => GlbMeshDecoder.decode(
        ByteData(28),
        kind: ComponentKind.contactor,
      ),
      throwsFormatException,
    );
  });
}
