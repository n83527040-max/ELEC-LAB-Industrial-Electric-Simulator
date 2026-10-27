import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/component_catalog.dart';
import '../models/project.dart';
import '../three_d/mesh_view.dart';
import '../three_d/procedural_meshes.dart';
import '../ui/board_painter.dart';

class SchematicExportPainter extends CustomPainter {
  const SchematicExportPainter({required this.project});

  final ElectricalProject project;

  @override
  void paint(Canvas canvas, Size size) {
    final visibleLayers = project.layers
        .where((layer) => layer.visible)
        .map((layer) => layer.id)
        .toSet();
    BoardPainter(
      project: project,
      showGrid: true,
      gridSize: 20,
      visibleLayers: visibleLayers,
    ).paint(canvas, size);
    for (final component in project.components) {
      if (!visibleLayers.contains(component.layerId)) continue;
      final spec = ComponentCatalog.specOf(component.kind);
      canvas.save();
      canvas.translate(
        component.position.x + spec.size.width * component.scale / 2,
        component.position.y + spec.size.height * component.scale / 2,
      );
      canvas.rotate(component.rotation * math.pi / 2);
      canvas.scale(component.scale);
      canvas.translate(-spec.size.width / 2, -spec.size.height / 2);
      final mesh = ProceduralMeshes.forComponent(component);
      MeshPainter(mesh: mesh).paint(canvas, spec.size);
      for (final terminal in spec.terminals) {
        final text = TextPainter(
          text: TextSpan(
            text: terminal.label,
            style: const TextStyle(
              color: Color(0xff07111f),
              fontSize: 6,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(terminal.position.x + 4, terminal.position.y - 4),
        );
      }
      canvas.restore();
      final label = TextPainter(
        text: TextSpan(
          text: '${component.label} • ${spec.nameFr}',
          style: const TextStyle(
            color: Color(0xff07111f),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          component.position.x,
          component.position.y + spec.size.height * component.scale + 3,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(SchematicExportPainter oldDelegate) =>
      oldDelegate.project != project;
}

abstract final class ProjectExporter {
  static Future<Uint8List> renderPng(
    ElectricalProject project, {
    int maxDimension = 1800,
  }) async {
    final scale = maxDimension / math.max(project.boardWidth, project.boardHeight);
    final width = (project.boardWidth * scale).round();
    final height = (project.boardHeight * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    SchematicExportPainter(project: project).paint(
      canvas,
      Size(project.boardWidth, project.boardHeight),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (bytes == null) throw StateError('PNG encoding failed.');
    return bytes.buffer.asUint8List();
  }

  static Future<Uint8List> renderPdf(ElectricalProject project) async {
    final png = await renderPng(project);
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final document = pw.Document(
      title: 'ELEC LAB — ${project.name}',
      author: 'ELEC LAB Industrial Electric Simulator',
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (context) => pw.Column(
          children: <pw.Widget>[
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                'ELEC LAB — ${project.name}',
                style: pw.TextStyle(font: font, fontSize: 18),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Image(
                pw.MemoryImage(png),
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                'مخطط تعليمي للمحاكاة فقط؛ ليس اعتماداً لتنفيذ دائرة كهربائية حقيقية.',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }
}
