import 'package:flutter/material.dart';

import '../models/component.dart';
import '../models/terminal.dart';
import 'glb_mesh_loader.dart';
import 'mesh_model.dart';
import 'mesh_view.dart';
import 'procedural_meshes.dart';

/// Displays the actual bundled GLB. A missing or invalid asset produces an
/// explicit error chip; it never silently substitutes a screenshot or a box.
class ComponentMeshView extends StatelessWidget {
  const ComponentMeshView({
    required this.component,
    super.key,
    this.detail = MeshDetail.preview,
    this.fixedScale,
    this.fitPadding = 0.8,
    this.showShadow = false,
    this.interactive = false,
  });

  final CircuitComponent component;
  final MeshDetail detail;
  final double? fixedScale;
  final double fitPadding;
  final bool showShadow;
  final bool interactive;

  @override
  Widget build(BuildContext context) => _AssetMeshFutureView(
        future: DeviceMeshRepository.forComponent(component, detail: detail),
        kind: component.kind,
        detail: detail,
        fixedScale: fixedScale,
        fitPadding: fitPadding,
        showShadow: showShadow,
        interactive: interactive,
      );
}

class KindMeshView extends StatelessWidget {
  const KindMeshView({
    required this.kind,
    super.key,
    this.detail = MeshDetail.preview,
    this.fitPadding = 0.8,
    this.showShadow = false,
    this.color = '',
  });

  final ComponentKind kind;
  final MeshDetail detail;
  final double fitPadding;
  final bool showShadow;
  final String color;

  @override
  Widget build(BuildContext context) => _AssetMeshFutureView(
        future: DeviceMeshRepository.forKind(
          kind,
          detail: detail,
          color: color,
        ),
        kind: kind,
        detail: detail,
        fitPadding: fitPadding,
        showShadow: showShadow,
      );
}

class _AssetMeshFutureView extends StatelessWidget {
  const _AssetMeshFutureView({
    required this.future,
    required this.kind,
    required this.detail,
    this.fixedScale,
    this.fitPadding = 0.8,
    this.showShadow = false,
    this.interactive = false,
  });

  final Future<DeviceMesh> future;
  final ComponentKind kind;
  final MeshDetail detail;
  final double? fixedScale;
  final double fitPadding;
  final bool showShadow;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceMesh>(
      future: future,
      builder: (context, snapshot) {
        final mesh = snapshot.data;
        if (mesh != null) {
          if (interactive) return InteractiveMeshViewer(mesh: mesh);
          return DeviceMeshView(
            key: ValueKey<String>('glb-${kind.name}-${detail.name}'),
            mesh: mesh,
            fixedScale: fixedScale,
            fitPadding: fitPadding,
            showShadow: showShadow,
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Tooltip(
              message: 'تعذر تحميل GLB: ${snapshot.error}',
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.error_outline, color: Colors.orange),
                  Text('GLB', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        }
        if (fixedScale != null) return const SizedBox.expand();
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
        );
      },
    );
  }
}
