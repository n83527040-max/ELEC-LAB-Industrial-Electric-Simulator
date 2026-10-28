import 'package:flutter/material.dart';

import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/terminal.dart';
import '../three_d/asset_mesh_view.dart';

class ComponentLibrarySheet extends StatefulWidget {
  const ComponentLibrarySheet({super.key});

  @override
  State<ComponentLibrarySheet> createState() => _ComponentLibrarySheetState();
}

class _ComponentLibrarySheetState extends State<ComponentLibrarySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  ComponentCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ComponentCatalog.search(_query, _category);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 18, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'مكتبة العناصر',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${items.length} جهاز',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق المكتبة',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: TextField(
                key: const Key('component-search'),
                controller: _searchController,
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو Contacteur, MCB…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                          tooltip: 'مسح البحث',
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: <Widget>[
                  _categoryChip(null, 'الكل'),
                  ...ComponentCategory.values.map(
                    (category) => _categoryChip(
                      category,
                      ComponentCatalog.categoryName(category),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('لا توجد عناصر مطابقة.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 920
                            ? 5
                            : width >= 680
                                ? 4
                                : width >= 470
                                    ? 3
                                    : 2;
                        return GridView.builder(
                          key: const Key('component-grid'),
                          cacheExtent: 160,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            childAspectRatio: width < 370 ? 0.76 : 0.82,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) => RepaintBoundary(
                            child: _ComponentCard(spec: items[index]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(ComponentCategory? category, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: _category == category,
        showCheckmark: false,
        onSelected: (_) => setState(() => _category = category),
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.spec});

  final ComponentSpec spec;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      key: Key('component-card-${spec.kind.name}'),
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, spec.kind),
        child: Semantics(
          button: true,
          label: 'إضافة ${spec.nameAr} ${spec.nameFr}',
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: dark
                            ? const <Color>[Color(0xff1a2a38), Color(0xff101a24)]
                            : const <Color>[Color(0xfff4f7f9), Color(0xffe4ebf0)],
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: KindMeshView(
                              kind: spec.kind,
                              fitPadding: 0.88,
                              showShadow: true,
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 3,
                          left: 3,
                          child: Icon(
                            Icons.add_circle,
                            size: 19,
                            color: Color(0xff159bff),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      spec.nameAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      spec.nameFr,
                      textDirection: TextDirection.ltr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
