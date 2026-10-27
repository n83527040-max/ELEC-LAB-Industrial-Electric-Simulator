import 'package:elec_lab/src/app.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/project_templates.dart';
import 'package:elec_lab/src/state/settings_controller.dart';
import 'package:elec_lab/src/storage/project_repository.dart';
import 'package:elec_lab/src/ui/circuit_board.dart';
import 'package:elec_lab/src/ui/editor_screen.dart';
import 'package:elec_lab/src/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProjectRepository> repository() async => ProjectRepository(MemoryProjectStorage());

  Future<SettingsController> settings() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SettingsController(await SharedPreferences.getInstance());
  }

  testWidgets('home is RTL, offline and theme preference persists', (tester) async {
    final prefs = await settings();
    await tester.pumpWidget(
      ElecLabApp(repository: await repository(), settings: prefs),
    );
    await tester.pumpAndSettle();
    expect(find.text('مشروع جديد'), findsOneWidget);
    expect(find.textContaining('لا توجد مشاريع'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.byTooltip('تبديل الوضع الداكن والفاتح'));
    await tester.pumpAndSettle();
    expect(prefs.darkMode, isFalse);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });

  testWidgets('user can create a project and add a real component from library', (tester) async {
    await tester.pumpWidget(
      ElecLabApp(repository: await repository(), settings: await settings()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشروع جديد'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)).first,
      'دائرة الاختبار',
    );
    await tester.ensureVisible(find.text('إنشاء المشروع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء المشروع'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.byType(CircuitBoard), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-component')));
    await tester.pumpAndSettle();
    expect(find.text('مكتبة العناصر'), findsOneWidget);
    await tester.tap(find.text('مصدر تغذية DC'));
    await tester.pumpAndSettle();
    expect(find.text('G1'), findsWidgets);
    await tester.tap(find.byTooltip('حفظ ورجوع'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('دائرة الاختبار'), findsOneWidget);
  });

  testWidgets('small phone and landscape editor do not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ElecLabApp(repository: await repository(), settings: await settings()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'widget', name: 'واجهة', now: testNow),
      ProjectTemplateKind.selfHolding,
    );
    tester.view.physicalSize = const Size(800, 450);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: EditorScreen(
            project: project,
            repository: await repository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircuitBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play and stop drive the editor from simulation results', (tester) async {
    final project = ProjectTemplates.apply(
      ElectricalProject.empty(id: 'run', name: 'تشغيل', now: testNow),
      ProjectTemplateKind.dcLamp,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(project: project, repository: await repository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-simulation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('المحاكاة تعمل'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle-simulation')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
