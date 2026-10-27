import 'package:elec_lab/src/models/component.dart';
import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/terminal.dart';
import 'package:elec_lab/src/state/editor_controller.dart';
import 'package:elec_lab/src/ui/app_theme.dart';
import 'package:elec_lab/src/ui/circuit_board.dart';
import 'package:elec_lab/src/ui/component_library_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('component library fits a small phone and filters real devices', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: ComponentLibrarySheet()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('component-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const Key('component-search')), 'MCB');
    await tester.pump();
    expect(find.text('Disjoncteur MCB'), findsOneWidget);
    expect(find.text('Alimentation DC'), findsNothing);

    await tester.tap(find.byTooltip('مسح البحث'));
    await tester.pump();
    await tester.tap(find.text('مصادر التغذية'));
    await tester.pumpAndSettle();
    expect(find.text('Alimentation DC'), findsOneWidget);
    expect(find.text('Alimentation monophasée'), findsOneWidget);
    expect(find.text('Alimentation triphasée'), findsOneWidget);
    expect(find.text('Disjoncteur MCB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all library cards layout in landscape without clipping exceptions', (tester) async {
    tester.view.physicalSize = const Size(800, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: ComponentLibrarySheet()),
      ),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index++) {
      await tester.drag(find.byKey(const Key('component-grid')), const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('board terminals are hidden until selection and accept real taps', (tester) async {
    final component = device('k1', ComponentKind.contactor, x: 400, y: 300);
    final project = ElectricalProject.empty(
      id: 'terminals',
      name: 'Terminals',
      now: testNow,
    ).copyWith(components: <CircuitComponent>[component]);
    final controller = EditorController(project: project);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                CircuitBoard(controller: controller, onShowDetails: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A1'), findsNothing);

    await tester.tap(find.byType(BoardComponent));
    await tester.pumpAndSettle();
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('1/L1'), findsOneWidget);
    expect(controller.selectedComponentId, 'k1');

    await tester.tap(find.bySemanticsLabel('طرف A1 في K1'));
    await tester.pump();
    expect(controller.pendingWireStart?.componentId, 'k1');
    expect(controller.pendingWireStart?.terminalId, 'a1');

    controller.resizeComponent('k1', 1.4);
    controller.rotateComponent('k1');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('طرف A1 في K1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
