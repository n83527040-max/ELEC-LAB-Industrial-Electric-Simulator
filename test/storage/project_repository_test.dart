import 'dart:convert';
import 'dart:io';

import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/storage/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  late ElectricalProject project;

  setUp(() {
    project = ProjectTemplates.apply(
      ElectricalProject.empty(
          id: 'storage_test', name: 'مشروع التخزين', now: testNow),
      ProjectTemplateKind.dcLamp,
    );
  });

  test('memory repository renames, duplicates and retains circuit content',
      () async {
    final repository = ProjectRepository(MemoryProjectStorage());
    await repository.saveProject(project);
    final renamed = await repository.renameProject(project.id, 'اسم جديد');
    expect(renamed.name, 'اسم جديد');
    final duplicate = await repository.duplicateProject(project.id);
    expect(duplicate.id, isNot(project.id));
    expect(duplicate.components, hasLength(project.components.length));
    expect(duplicate.wires, hasLength(project.wires.length));
    expect(await repository.listProjects(), hasLength(2));
  });

  test(
      'checksummed project import detects tampering and avoids overwriting ids',
      () async {
    final repository = ProjectRepository(MemoryProjectStorage());
    await repository.saveProject(project);
    final exported = repository.exportProject(project);
    final imported = await repository.importProject(exported);
    expect(imported.id, isNot(project.id));
    expect(imported.name, contains('مستورد'));
    expect(imported.wires, hasLength(project.wires.length));

    final json = jsonDecode(exported) as Map<String, dynamic>;
    (json['project'] as Map<String, dynamic>)['name'] = 'Tampered';
    expect(
      () => repository.importProject(jsonEncode(json)),
      throwsFormatException,
    );
  });

  test('offline backup restores all projects', () async {
    final storage = MemoryProjectStorage();
    final repository = ProjectRepository(storage);
    await repository.saveProject(project);
    final other = await repository.duplicateProject(project.id);
    final backup = await repository.createBackup();
    await storage.delete(project.id);
    await storage.delete(other.id);
    expect(await repository.listProjects(), isEmpty);
    expect(await repository.restoreBackup(backup), 2);
    expect(await repository.listProjects(), hasLength(2));
    final restored = await repository.loadProject(project.id);
    expect(restored!.components, isNotEmpty);
  });

  group('real atomic file storage', () {
    late Directory directory;
    late LocalProjectStorage storage;

    setUp(() async {
      directory =
          await Directory.systemTemp.createTemp('elec_lab_storage_test');
      storage = LocalProjectStorage(directory);
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('save, close/reopen, list and delete use real JSON files', () async {
      await storage.save(project);
      final reopened = LocalProjectStorage(directory);
      final loaded = await reopened.load(project.id);
      expect(loaded, isNotNull);
      expect(loaded!.encode(), project.encode());
      expect(await reopened.list(), hasLength(1));
      final files =
          await directory.list().where((entity) => entity is File).toList();
      expect(files, isNotEmpty);
      await reopened.delete(project.id);
      expect(await reopened.load(project.id), isNull);
    });

    test('previous valid generation recovers a damaged primary file', () async {
      await storage.save(project);
      await storage.save(project.copyWith(name: 'نسخة ثانية'));
      final primary = File('${directory.path}/${project.id}.eleclab.json');
      await primary.writeAsString('{ damaged', flush: true);
      final recovered = await storage.load(project.id);
      expect(recovered, isNotNull);
      expect(recovered!.name, 'مشروع التخزين');
    });

    test('path traversal ids never escape the project directory', () async {
      await expectLater(storage.load('../secret'), throwsArgumentError);
      final file = File('${directory.path}/${project.id}.eleclab.json');
      expect(file.parent.path, directory.path);
    });
  });
}
