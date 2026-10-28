import 'dart:math' as math;

import 'package:elec_lab/src/models/project.dart';
import 'package:elec_lab/src/models/supply_bay.dart';
import 'package:elec_lab/src/state/editor_controller.dart';
import 'package:elec_lab/src/ui/circuit_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'fixed board fits phone, rejects background drag and Fit restores it',
      (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditorController(
      project: ElectricalProject.empty(
        id: 'fixed_board',
        name: 'Fixed board',
        now: testNow,
      ),
    );
    addTearDown(controller.dispose);
    final boardKey = GlobalKey<CircuitBoardState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitBoard(
            key: boardKey,
            controller: controller,
            onShowDetails: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expected = math.min((360 - 24) / 1200, (700 - 24) / 900);
    expect(controller.zoom, closeTo(expected, 1e-9));
    final fittedOffset = controller.viewportOffset;
    final fittedWidth = controller.project.boardWidth * controller.zoom;
    final fittedHeight = controller.project.boardHeight * controller.zoom;
    expect(fittedOffset.x, greaterThanOrEqualTo(0));
    expect(fittedOffset.y, greaterThanOrEqualTo(0));
    expect(fittedOffset.x + fittedWidth, lessThanOrEqualTo(360));
    expect(fittedOffset.y + fittedHeight, lessThanOrEqualTo(700));
    final supplies = controller.project.components
        .where(SupplyBay.isFixed)
        .map((component) => component.position)
        .toList();

    await tester.drag(find.byType(InteractiveViewer), const Offset(110, 90));
    await tester.pumpAndSettle();
    expect(controller.viewportOffset, fittedOffset);
    expect(controller.zoom, closeTo(expected, 1e-9));

    boardKey.currentState!.zoomBy(.2);
    await tester.pump();
    expect(controller.zoom, greaterThan(expected));
    boardKey.currentState!.fitToContent();
    await tester.pump();
    expect(controller.zoom, closeTo(expected, 1e-9));
    expect(controller.viewportOffset, fittedOffset);
    expect(
      controller.project.components
          .where(SupplyBay.isFixed)
          .map((component) => component.position)
          .toList(),
      supplies,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'orientation refits the complete board without losing fixed supplies',
      (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditorController(
      project: ElectricalProject.empty(
        id: 'orientation_board',
        name: 'Orientation board',
        now: testNow,
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitBoard(controller: controller, onShowDetails: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(700, 360);
    await tester.pump();
    await tester.pumpAndSettle();
    final expected = math.min((700 - 24) / 1200, (360 - 24) / 900);
    expect(controller.zoom, closeTo(expected, 1e-9));
    expect(controller.viewportOffset.y, greaterThanOrEqualTo(0));
    expect(
        controller.project.components.where(SupplyBay.isFixed), hasLength(3));
    expect(tester.takeException(), isNull);
  });
}
