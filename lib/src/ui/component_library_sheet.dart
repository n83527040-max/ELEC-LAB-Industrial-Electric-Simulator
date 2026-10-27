import 'package:flutter/material.dart';

import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/geometry.dart';
import '../models/terminal.dart';
import '../three_d/mesh_view.dart';
import '../three_d/procedural_meshes.dart';

class ComponentLibrarySheet extends StatefulWidget {
  const ComponentLibrarySheet({super.key});

  @override
  State<ComponentLibrarySheet> createState() => _ComponentLibrarySheetState();
}

class _ComponentLibrarySheetState extends State<ComponentLibrarySheet> {
  String _query = '';
  ComponentCategory? _category;

  @override
  Widget build(BuildContext context) {
    final items = ComponentCatalog.search(_query, _category);
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'إضافة عنصر',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'ابحث: Contacteur, MCB, Moteur…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: const Text('الكل'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                ...ComponentCategory.values.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(ComponentCatalog.categoryName(category)),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('لا توجد عناصر مطابقة.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
                      childAspectRatio: 0.86,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _ComponentCard(spec: items[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.spec});

  final ComponentSpec spec;

  @override
  Widget build(BuildContext context) {
    final example = CircuitComponent(
      id: 'preview',
      kind: spec.kind,
      label: spec.nameFr,
      position: BoardPoint.zero,
      layerId: 'power',
      properties: spec.defaultProperties,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, spec.kind),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: <Widget>[
              Expanded(child: DeviceMeshView(mesh: ProceduralMeshes.forComponent(example))),
              const SizedBox(height: 4),
              Text(
                spec.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                spec.nameFr,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
              const Icon(Icons.add_circle_outline, size: 18, color: Color(0xff087ff5)),
            ],
          ),
        ),
      ),
    );
  }
}
