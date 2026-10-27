import 'package:flutter/material.dart';

import '../models/component_catalog.dart';
import '../models/supply_bay.dart';
import '../models/terminal.dart';
import '../state/editor_controller.dart';

class SupplyPanel extends StatelessWidget {
  const SupplyPanel({
    required this.controller,
    required this.onShowDetails,
    super.key,
  });

  final EditorController controller;
  final ValueChanged<String> onShowDetails;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            children: <Widget>[
              Text(
                'مصادر التغذية • Alimentation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'مصادر ثابتة داخل بيانات المشروع. فعّل ما تحتاجه، ثم اضبط الجهد والتردد من الخصائص.',
              ),
              const SizedBox(height: 12),
              for (final id in const <String>[
                SupplyBay.threePhaseId,
                SupplyBay.singlePhaseId,
                SupplyBay.dcId,
              ])
                _sourceTile(context, id),
              const SizedBox(height: 8),
              const Text(
                'يمكن استعمال مصدر قدرة ومصدر تحكم مختلفين. لا تفعّل مصادر متعارضة على نفس العقدة.',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sourceTile(BuildContext context, String id) {
    final component = controller.project.componentById(id);
    if (component == null) return const SizedBox.shrink();
    final spec = ComponentCatalog.specOf(component.kind);
    final enabled = component.flag('enabled');
    final values = switch (component.kind) {
      ComponentKind.threePhaseSupply =>
        '${component.number('lineVoltage').toStringAsFixed(0)} V L-L • ${component.number('frequency').toStringAsFixed(0)} Hz • L1 L2 L3 N PE',
      ComponentKind.acSupply =>
        '${component.number('voltage').toStringAsFixed(0)} V • ${component.number('frequency').toStringAsFixed(0)} Hz • L N',
      _ => '${component.number('voltage').toStringAsFixed(0)} V DC • + / −',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: <Widget>[
            SwitchListTile(
              value: enabled,
              onChanged: (value) => controller.setSupplyEnabled(id, value),
              secondary: Icon(
                Icons.bolt,
                color: enabled ? const Color(0xff37d99a) : Colors.grey,
              ),
              title: Text('${component.label} • ${spec.nameFr}'),
              subtitle: Text(values, textDirection: TextDirection.ltr),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: () => onShowDetails(id),
                  icon: const Icon(Icons.tune),
                  label: const Text('الجهد والتردد والأطراف'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
