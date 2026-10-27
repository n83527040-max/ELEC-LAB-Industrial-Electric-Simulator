import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/settings_controller.dart';
import 'storage/project_repository.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

class ElecLabApp extends StatelessWidget {
  const ElecLabApp({
    required this.repository,
    required this.settings,
    super.key,
  });

  final ProjectRepository repository;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'ELEC LAB — Industrial Electric Simulator',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[
          Locale('ar'),
          Locale('fr'),
          Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: settings.themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: HomeScreen(repository: repository, settings: settings),
      ),
    );
  }
}
