import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/project.dart';
import '../state/id_factory.dart';

abstract interface class ProjectStorage {
  Future<List<ProjectSummary>> list();
  Future<ElectricalProject?> load(String id);
  Future<void> save(ElectricalProject project);
  Future<void> delete(String id);
}

/// File-backed offline storage. Every project write uses flush + atomic rename;
/// the previous valid generation is retained as a .bak recovery file.
class LocalProjectStorage implements ProjectStorage {
  LocalProjectStorage(this.directory);

  final Directory directory;

  @override
  Future<List<ProjectSummary>> list() async {
    await directory.create(recursive: true);
    final projects = <ElectricalProject>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.eleclab.json')) continue;
      try {
        final project = ElectricalProject.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
        projects.add(project);
      } on Object {
        // A single damaged file must not hide the remaining offline projects.
        continue;
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects.map(ProjectSummary.fromProject).toList(growable: false);
  }

  @override
  Future<ElectricalProject?> load(String id) async {
    final file = _file(id);
    if (!await file.exists()) return null;
    try {
      return ElectricalProject.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on Object {
      final backup = File('${file.path}.bak');
      if (!await backup.exists()) rethrow;
      return ElectricalProject.fromJson(
        jsonDecode(await backup.readAsString()) as Map<String, dynamic>,
      );
    }
  }

  @override
  Future<void> save(ElectricalProject project) async {
    project.validate();
    await directory.create(recursive: true);
    final file = _file(project.id);
    final temporary =
        File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await temporary.writeAsString(project.encode(), flush: true);
    if (await file.exists()) {
      await file.copy('${file.path}.bak');
    }
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (await file.exists()) await file.delete();
    final backup = File('${file.path}.bak');
    if (await backup.exists()) await backup.delete();
  }

  File _file(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Unsafe project id');
    }
    return File('${directory.path}${Platform.pathSeparator}$id.eleclab.json');
  }
}

class MemoryProjectStorage implements ProjectStorage {
  final Map<String, ElectricalProject> projects = <String, ElectricalProject>{};

  @override
  Future<void> delete(String id) async => projects.remove(id);

  @override
  Future<List<ProjectSummary>> list() async {
    final values = projects.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values.map(ProjectSummary.fromProject).toList(growable: false);
  }

  @override
  Future<ElectricalProject?> load(String id) async => projects[id];

  @override
  Future<void> save(ElectricalProject project) async {
    project.validate();
    projects[project.id] = project;
  }
}

class ProjectRepository {
  ProjectRepository(this.storage, {IdFactory? idFactory})
      : _ids = idFactory ?? IdFactory();

  final ProjectStorage storage;
  final IdFactory _ids;

  Future<List<ProjectSummary>> listProjects() => storage.list();

  Future<ElectricalProject?> loadProject(String id) => storage.load(id);

  Future<void> saveProject(ElectricalProject project) => storage.save(project);

  Future<void> deleteProject(String id) => storage.delete(id);

  Future<ElectricalProject> createProject({
    required String name,
    String description = '',
    double width = 1200,
    double height = 900,
  }) async {
    final now = DateTime.now().toUtc();
    final project = ElectricalProject.empty(
      id: _ids.create('project'),
      name: name.trim(),
      description: description.trim(),
      now: now,
      boardWidth: width,
      boardHeight: height,
    );
    await storage.save(project);
    return project;
  }

  Future<ElectricalProject> renameProject(String id, String name) async {
    final project = await storage.load(id);
    if (project == null) throw StateError('Project not found.');
    if (name.trim().isEmpty) throw ArgumentError('Project name is empty.');
    final updated = project.copyWith(
      name: name.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    await storage.save(updated);
    return updated;
  }

  Future<ElectricalProject> duplicateProject(String id) async {
    final project = await storage.load(id);
    if (project == null) throw StateError('Project not found.');
    final now = DateTime.now().toUtc();
    final source = project.toJson();
    source['id'] = _ids.create('project');
    source['name'] = 'نسخة من ${project.name}';
    source['createdAt'] = now.toIso8601String();
    source['updatedAt'] = now.toIso8601String();
    final duplicate = ElectricalProject.fromJson(source);
    await storage.save(duplicate);
    return duplicate;
  }

  String exportProject(ElectricalProject project) {
    final payload = jsonEncode(project.toJson());
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'format': 'elec-lab-project',
      'checksum': sha256.convert(utf8.encode(payload)).toString(),
      'project': project.toJson(),
    });
  }

  Future<ElectricalProject> importProject(String document) async {
    final decoded = jsonDecode(document);
    if (decoded is! Map || decoded['format'] != 'elec-lab-project') {
      throw const FormatException('Not an ELEC LAB project file.');
    }
    final payload = decoded['project'];
    if (payload is! Map) {
      throw const FormatException('Missing project payload.');
    }
    final canonical = jsonEncode(payload);
    final expected = sha256.convert(utf8.encode(canonical)).toString();
    if (expected != decoded['checksum']) {
      throw const FormatException('Project checksum does not match.');
    }
    final project = ElectricalProject.fromJson(
      Map<String, dynamic>.from(payload),
    );
    final existing = await storage.load(project.id);
    final imported = existing == null ? project : _withNewIdentity(project);
    await storage.save(imported);
    return imported;
  }

  Future<String> createBackup() async {
    final summaries = await storage.list();
    final projects = <Map<String, dynamic>>[];
    for (final summary in summaries) {
      final project = await storage.load(summary.id);
      if (project != null) projects.add(project.toJson());
    }
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'format': 'elec-lab-backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'projects': projects,
    });
  }

  Future<int> restoreBackup(String document) async {
    final decoded = jsonDecode(document);
    if (decoded is! Map ||
        decoded['format'] != 'elec-lab-backup' ||
        decoded['version'] != 1 ||
        decoded['projects'] is! List) {
      throw const FormatException('Invalid ELEC LAB backup.');
    }
    final projects = <ElectricalProject>[];
    for (final item in decoded['projects'] as List) {
      if (item is! Map) throw const FormatException('Invalid backup project.');
      projects.add(
        ElectricalProject.fromJson(Map<String, dynamic>.from(item)),
      );
    }
    for (final project in projects) {
      await storage.save(project);
    }
    return projects.length;
  }

  ElectricalProject _withNewIdentity(ElectricalProject project) {
    final now = DateTime.now().toUtc();
    final json = project.toJson();
    json['id'] = _ids.create('project');
    json['name'] = 'مستورد — ${project.name}';
    json['createdAt'] = now.toIso8601String();
    json['updatedAt'] = now.toIso8601String();
    return ElectricalProject.fromJson(json);
  }
}
