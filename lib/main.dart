import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/state/settings_controller.dart';
import 'src/storage/project_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final documents = await getApplicationDocumentsDirectory();
  final repository = ProjectRepository(
    LocalProjectStorage(
      Directory('${documents.path}${Platform.pathSeparator}projects'),
    ),
  );
  runApp(
    ElecLabApp(
      repository: repository,
      settings: SettingsController(preferences),
    ),
  );
}
