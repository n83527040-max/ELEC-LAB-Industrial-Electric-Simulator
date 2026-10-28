import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/component_catalog.dart';
import '../models/project.dart';
import '../models/supply_bay.dart';
import '../three_d/glb_mesh_loader.dart';
import '../three_d/mesh_model.dart';
import '../three_d/mesh_view.dart';
import '../three_d/procedural_meshes.dart';
import '../ui/board_painter.dart';

class SchematicExportPainter extends CustomPainter {
  const SchematicExportPainter({required this.project, required this.meshes});

  final ElectricalProject project;
  final Map<String, DeviceMesh> meshes;

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
      if (!SupplyBay.isFixed(component) &&
          !visibleLayers.contains(component.layerId)) {
        continue;
      }
      final spec = ComponentCatalog.specOf(component.kind);
      final annotationColor = SupplyBay.isFixed(component)
          ? const Color(0xffe6f6ff)
          : const Color(0xff07111f);
      canvas.save();
      canvas.translate(
        component.position.x + spec.size.width * component.scale / 2,
        component.position.y + spec.size.height * component.scale / 2,
      );
      canvas.rotate(component.rotation * math.pi / 2);
      canvas.scale(component.scale);
      canvas.translate(-spec.size.width / 2, -spec.size.height / 2);
      final mesh = meshes[component.id];
      if (mesh == null) {
        canvas.restore();
        continue;
      }
      MeshPainter(
        mesh: mesh,
        rotationX: 0,
        rotationY: 0,
        fixedScale: 48,
      ).paint(canvas, spec.size);
      for (final terminal in spec.terminals) {
        final text = TextPainter(
          text: TextSpan(
            text: terminal.label,
            style: TextStyle(
              color: annotationColor,
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
          style: TextStyle(
            color: annotationColor,
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
      oldDelegate.project != project || oldDelegate.meshes != meshes;
}

class ProjectThumbnail extends StatefulWidget {
  const ProjectThumbnail({required this.project, super.key});

  final ElectricalProject project;

  @override
  State<ProjectThumbnail> createState() => _ProjectThumbnailState();
}

class _ProjectThumbnailState extends State<ProjectThumbnail> {
  late Future<Map<String, DeviceMesh>> _meshes;

  @override
  void initState() {
    super.initState();
    _meshes = ProjectExporter.loadMeshes(widget.project);
  }

  @override
  void didUpdateWidget(ProjectThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.project, widget.project)) {
      _meshes = ProjectExporter.loadMeshes(widget.project);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, DeviceMesh>>(
      future: _meshes,
      builder: (context, snapshot) {
        final meshes = snapshot.data;
        final ready = meshes != null &&
            widget.project.components.every(
              (component) => meshes.containsKey(component.id),
            );
        if (!ready) {
          return ColoredBox(
            color: const Color(0xff14273b),
            child: Center(
              child: snapshot.hasError
                  ? const Icon(Icons.error_outline, color: Colors.orange)
                  : const Icon(
                      Icons.electrical_services,
                      size: 24,
                      color: Colors.white38,
                    ),
            ),
          );
        }
        return CustomPaint(
          painter:
              SchematicExportPainter(project: widget.project, meshes: meshes),
        );
      },
    );
  }
}

abstract final class ProjectExporter {
  static Future<Map<String, DeviceMesh>> loadMeshes(
    ElectricalProject project,
  ) async {
    final loaded = await Future.wait(
      project.components.map(
        (component) async => MapEntry(
          component.id,
          await DeviceMeshRepository.forComponent(
            component,
            detail: MeshDetail.board,
          ),
        ),
      ),
    );
    return <String, DeviceMesh>{
      for (final entry in loaded) entry.key: entry.value,
    };
  }

  static Future<Uint8List> renderPng(
    ElectricalProject project, {
    int maxDimension = 1800,
  }) async {
    final scale =
        maxDimension / math.max(project.boardWidth, project.boardHeight);
    final width = (project.boardWidth * scale).round();
    final height = (project.boardHeight * scale).round();
    final meshes = await loadMeshes(project);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    SchematicExportPainter(project: project, meshes: meshes).paint(
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
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
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
