import 'package:flutter/material.dart';

import '../state/editor_controller.dart';

class LayersSheet extends StatelessWidget {
  const LayersSheet({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('الطبقات',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => _addLayer(context),
                    icon: const Icon(Icons.add),
                    tooltip: 'إضافة طبقة',
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: controller.project.layers.length,
                itemBuilder: (context, index) {
                  final layer = controller.project.layers[index];
                  final componentCount = controller.project.components
                      .where((item) => item.layerId == layer.id)
                      .length;
                  return ListTile(
                    leading:
                        CircleAvatar(backgroundColor: Color(layer.colorValue)),
                    title: Text(layer.name),
                    subtitle: Text('$componentCount عناصر'),
                    onTap: () => _renameLayer(context, layer.id, layer.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: () => controller.setLayerVisibility(
                            layer.id,
                            !layer.visible,
                          ),
                          icon: Icon(layer.visible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          tooltip: 'إظهار/إخفاء',
                        ),
                        IconButton(
                          onPressed: () => controller.setLayerLocked(
                              layer.id, !layer.locked),
                          icon:
                              Icon(layer.locked ? Icons.lock : Icons.lock_open),
                          tooltip: 'قفل/فك القفل',
                        ),
                        IconButton(
                          onPressed: () => controller.deleteLayer(layer.id),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'حذف الطبقة',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('اضغط على اسم الطبقة لإعادة تسميتها.'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addLayer(BuildContext context) async {
    final name = await _askName(context, 'طبقة جديدة', '');
    if (name != null) controller.addLayer(name);
  }

  Future<void> _renameLayer(
      BuildContext context, String id, String oldName) async {
    final name = await _askName(context, 'إعادة تسمية الطبقة', oldName);
    if (name != null) controller.renameLayer(id, name);
  }

  Future<String?> _askName(
      BuildContext context, String title, String initial) async {
    final text = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    text.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result;
  }
}
