import 'package:flutter/material.dart';

import '../models/component_catalog.dart';
import '../models/terminal.dart';
import '../state/editor_controller.dart';
import '../three_d/mesh_view.dart';
import '../three_d/procedural_meshes.dart';

class ComponentDetailsSheet extends StatefulWidget {
  const ComponentDetailsSheet({
    required this.controller,
    required this.componentId,
    super.key,
  });

  final EditorController controller;
  final String componentId;

  @override
  State<ComponentDetailsSheet> createState() => _ComponentDetailsSheetState();
}

class _ComponentDetailsSheetState extends State<ComponentDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, double> _numbers = <String, double>{};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final component = widget.controller.project.componentById(widget.componentId);
        if (component == null) return const SizedBox.shrink();
        final spec = ComponentCatalog.specOf(component.kind);
        final reading = widget.controller.result?[component.id];
        return DefaultTabController(
          length: 3,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(spec.nameAr, style: Theme.of(context).textTheme.headlineSmall),
                            Text(
                              '${component.label} • ${spec.nameFr}',
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: const <Tab>[
                    Tab(text: 'مجسم 3D'),
                    Tab(text: 'الخصائص'),
                    Tab(text: 'التوصيل والقياس'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      Column(
                        children: <Widget>[
                          Expanded(
                            child: InteractiveMeshViewer(
                              mesh: ProceduralMeshes.forComponent(component),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(spec.description),
                          ),
                        ],
                      ),
                      _propertiesTab(component.id),
                      _terminalsTab(component.id),
                    ],
                  ),
                ),
                if (reading != null)
                  Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          Text('${reading.voltage.toStringAsFixed(2)} V'),
                          Text('${reading.current.toStringAsFixed(3)} A'),
                          Text('${reading.activePower.toStringAsFixed(2)} W'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _propertiesTab(String componentId) {
    final component = widget.controller.project.componentById(componentId)!;
    final editable = component.properties.entries.where(
      (entry) => !const <String>{'pressed', 'color', 'fault'}.contains(entry.key),
    );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          TextFormField(
            initialValue: component.label,
            decoration: const InputDecoration(labelText: 'مرجع الجهاز'),
            onSaved: (value) {
              if (value != null) {
                widget.controller.renameComponent(componentId, value);
              }
            },
          ),
          const SizedBox(height: 12),
          ...editable.map((entry) {
            final value = entry.value;
            if (value is bool) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_propertyName(entry.key)),
                subtitle: Text(entry.key, textDirection: TextDirection.ltr),
                value: value,
                onChanged: (changed) => widget.controller.updateComponentProperties(
                  componentId,
                  <String, Object>{...component.properties, entry.key: changed},
                ),
              );
            }
            if (value is num) {
              _numbers[entry.key] = value.toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  initialValue: value.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _propertyName(entry.key),
                    suffixText: entry.key,
                  ),
                  validator: (text) {
                    final parsed = double.tryParse(text ?? '');
                    if (parsed == null || !parsed.isFinite || parsed < 0) {
                      return 'أدخل رقماً صالحاً';
                    }
                    return null;
                  },
                  onSaved: (text) => _numbers[entry.key] = double.parse(text!),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              _formKey.currentState!.save();
              final properties = <String, Object>{...component.properties};
              _numbers.forEach((key, value) => properties[key] = value);
              widget.controller.updateComponentProperties(componentId, properties);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تطبيق الخصائص.')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('تطبيق الخصائص'),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: component.text('fault').isEmpty ? 'none' : component.text('fault'),
            decoration: const InputDecoration(labelText: 'حقن عطل افتراضي'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'none', child: Text('لا يوجد عطل')),
              DropdownMenuItem(value: 'open', child: Text('انقطاع Open circuit')),
              DropdownMenuItem(value: 'short', child: Text('قصر Short circuit')),
              DropdownMenuItem(value: 'coilOpen', child: Text('انقطاع الملف Coil open')),
            ],
            onChanged: (value) => widget.controller.injectFault(componentId, value!),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => widget.controller.resetProtection(componentId),
            icon: const Icon(Icons.restart_alt),
            label: const Text('إعادة ضبط الحماية / استبدال الفيوز'),
          ),
          const SizedBox(height: 12),
          const Text(
            'الأعطال افتراضية داخل المحاكي فقط. لا تجرّب القصر على معدات حقيقية.',
            style: TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _terminalsTab(String componentId) {
    final component = widget.controller.project.componentById(componentId)!;
    final spec = ComponentCatalog.specOf(component.kind);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('هذه الأطراف هي نفسها المستعملة في اللوحة والمجسم ومحرك MNA.'),
        const SizedBox(height: 12),
        ...spec.terminals.map(
          (terminal) => ListTile(
            leading: CircleAvatar(
              radius: 14,
              child: Text(
                terminal.label.characters.first,
                textDirection: TextDirection.ltr,
              ),
            ),
            title: Text(terminal.label, textDirection: TextDirection.ltr),
            subtitle: Text(_terminalKind(terminal.kind)),
            trailing: Text(
              '${widget.controller.project.wires.where((wire) => wire.from.componentId == componentId && wire.from.terminalId == terminal.id || wire.to.componentId == componentId && wire.to.terminalId == terminal.id).length} أسلاك',
            ),
          ),
        ),
        const Divider(),
        if (widget.controller.result?[componentId]?.measurementValid == false)
          const Text(
            'القياس غير صالح: راجع طريقة التوصيل ومدى الجهاز.',
            style: TextStyle(color: Colors.red),
          ),
      ],
    );
  }

  static String _terminalKind(TerminalKind kind) => switch (kind) {
        TerminalKind.power => 'قدرة Power',
        TerminalKind.coil => 'ملف Bobine',
        TerminalKind.auxiliary => 'نقطة مساعدة Contact auxiliaire',
        TerminalKind.measurement => 'قياس Mesure',
        TerminalKind.neutral => 'محايد/عودة Neutre',
        TerminalKind.earth => 'حماية أرضية PE',
      };

  static String _propertyName(String key) => switch (key) {
        'voltage' => 'الجهد RMS/DC',
        'lineVoltage' => 'الجهد بين الأطوار',
        'frequency' => 'التردد Hz',
        'internalResistance' => 'المقاومة الداخلية Ω',
        'enabled' => 'المصدر مفعل',
        'ratedCurrent' => 'التيار المقنن A',
        'closed' => 'الوضع مغلق',
        'coilVoltage' => 'جهد الملف المقنن V',
        'coilResistance' => 'مقاومة الملف Ω',
        'pickupRatio' => 'نسبة الالتقاط',
        'dropoutRatio' => 'نسبة السقوط',
        'tripTime' => 'زمن الحماية الحرارية s',
        'delaySeconds' => 'زمن التأخير s',
        'active' => 'الحساس منشط',
        'ratedVoltage' => 'الجهد المقنن V',
        'nominalVoltage' => 'جهد المحرك المقنن V',
        'nominalCurrent' => 'تيار المحرك المقنن A',
        'powerFactor' => 'معامل القدرة',
        'powerWatts' => 'قدرة المصباح W',
        'maxVoltage' => 'أقصى جهد للقياس V',
        'maxCurrent' => 'أقصى تيار للقياس A',
        _ => key,
      };
}
