import 'package:flutter/material.dart';

import '../models/component_catalog.dart';
import '../models/terminal.dart';
import '../state/editor_controller.dart';
import '../three_d/asset_mesh_view.dart';
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
  final Map<String, String> _strings = <String, String>{};
  String _interlockGroup = '';
  String _interlockRole = 'star';
  String? _interlockPeerId;
  bool _interlockDirty = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final component =
            widget.controller.project.componentById(widget.componentId);
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
                            Text(spec.nameAr,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
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
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
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
                            child: ComponentMeshView(
                              component: component,
                              detail: MeshDetail.detailed,
                              interactive: true,
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
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        spacing: 18,
                        runSpacing: 6,
                        children: <Widget>[
                          Text('${reading.voltage.toStringAsFixed(2)} V'),
                          Text('${reading.current.toStringAsFixed(3)} A'),
                          Text('${reading.activePower.toStringAsFixed(2)} W'),
                          if (reading.residualCurrent > 0)
                            Text(
                                'ΔI ${(reading.residualCurrent * 1000).toStringAsFixed(1)} mA'),
                          if (reading.energyKwh > 0)
                            Text('${reading.energyKwh.toStringAsFixed(6)} kWh'),
                          if (reading.secondaryCurrent > 0)
                            Text(
                                'Is ${reading.secondaryCurrent.toStringAsFixed(3)} A'),
                          if (reading.frequency > 0)
                            Text('${reading.frequency.toStringAsFixed(2)} Hz'),
                          if (reading.connectionMode.isNotEmpty)
                            Text(switch (reading.connectionMode) {
                              'star' => 'Étoile / نجمة',
                              'delta' => 'Triangle / مثلث',
                              _ => 'Open circuit',
                            }),
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
    final supportsReset = const <ComponentKind>{
      ComponentKind.circuitBreaker,
      ComponentKind.differentialBreaker,
      ComponentKind.motorBreaker,
      ComponentKind.thermalRelay,
      ComponentKind.fuse,
      ComponentKind.mcb2P,
      ComponentKind.mcb3P,
      ComponentKind.mcb4P,
      ComponentKind.rccb2P,
      ComponentKind.mccb3P,
    }.contains(component.kind);
    final editable = component.properties.entries.where(
      (entry) => !const <String>{
        'pressed',
        'color',
        'fault',
        'position',
        'supplyBay',
        'interlockGroup',
        'interlockRole',
      }.contains(entry.key),
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
                onChanged: (changed) =>
                    widget.controller.updateComponentProperties(
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _propertyName(entry.key),
                    suffixText: entry.key,
                  ),
                  validator: (text) => _validateNumber(entry.key, text),
                  onSaved: (text) => _numbers[entry.key] = double.parse(text!),
                ),
              );
            }
            if (value is String) {
              _strings[entry.key] = value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  initialValue: value,
                  decoration: InputDecoration(
                    labelText: _propertyName(entry.key),
                    suffixText: entry.key,
                  ),
                  onSaved: (text) => _strings[entry.key] = text?.trim() ?? '',
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          if (component.kind == ComponentKind.contactor ||
              component.kind == ComponentKind.contactor4P)
            _interlockEditor(componentId),
          if (component.kind == ComponentKind.indicator)
            DropdownButtonFormField<String>(
              initialValue: component.text('color').isEmpty
                  ? 'red'
                  : component.text('color'),
              decoration: const InputDecoration(labelText: 'لون المصباح'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'red', child: Text('أحمر')),
                DropdownMenuItem(value: 'green', child: Text('أخضر')),
                DropdownMenuItem(value: 'yellow', child: Text('أصفر')),
              ],
              onChanged: (value) => widget.controller.updateComponentProperties(
                componentId,
                <String, Object>{
                  ...component.properties,
                  'color': value ?? 'red'
                },
              ),
            ),
          if (component.kind == ComponentKind.rotarySwitch ||
              component.kind == ComponentKind.twoWaySwitch)
            DropdownButtonFormField<int>(
              initialValue: component.number('position').round(),
              decoration:
                  const InputDecoration(labelText: 'وضعية المفتاح الدوار'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem(value: 0, child: Text('0 — فصل')),
                DropdownMenuItem(value: 1, child: Text('1 — COM إلى 1')),
                DropdownMenuItem(value: 2, child: Text('2 — COM إلى 2')),
              ],
              onChanged: (value) => widget.controller.updateComponentProperties(
                componentId,
                <String, Object>{
                  ...component.properties,
                  'position': value ?? 0
                },
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              _formKey.currentState!.save();
              final properties = <String, Object>{...component.properties};
              _numbers.forEach((key, value) => properties[key] = value);
              _strings.forEach((key, value) => properties[key] = value);
              widget.controller
                  .updateComponentProperties(componentId, properties);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تطبيق الخصائص.')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('تطبيق الخصائص'),
          ),
          const SizedBox(height: 20),
          if (component.properties.containsKey('fault')) ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: component.text('fault').isEmpty
                  ? 'none'
                  : component.text('fault'),
              decoration: const InputDecoration(labelText: 'حقن عطل افتراضي'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'none', child: Text('لا يوجد عطل')),
                DropdownMenuItem(
                    value: 'open', child: Text('انقطاع Open circuit')),
                DropdownMenuItem(
                    value: 'short', child: Text('قصر Short circuit')),
                DropdownMenuItem(
                    value: 'coilOpen', child: Text('انقطاع الملف Coil open')),
              ],
              onChanged: (value) =>
                  widget.controller.injectFault(componentId, value!),
            ),
            const SizedBox(height: 12),
            const Text(
              'الأعطال افتراضية داخل المحاكي فقط. لا تجرّب القصر على معدات حقيقية.',
              style: TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 12),
          ],
          if (supportsReset)
            OutlinedButton.icon(
              onPressed: () => widget.controller.resetProtection(componentId),
              icon: const Icon(Icons.restart_alt),
              label: const Text('إعادة ضبط الحماية / استبدال الفيوز'),
            ),
        ],
      ),
    );
  }

  Widget _interlockEditor(String componentId) {
    final project = widget.controller.project;
    final component = project.componentById(componentId)!;
    if (!_interlockDirty) {
      _interlockGroup = component.text('interlockGroup').trim();
      final savedRole = component.text('interlockRole').trim();
      _interlockRole = savedRole == 'delta' ? 'delta' : 'star';
      _interlockPeerId = null;
      if (_interlockGroup.isNotEmpty) {
        for (final candidate in project.components) {
          if (candidate.id != componentId &&
              candidate.text('interlockGroup').trim() == _interlockGroup) {
            _interlockPeerId = candidate.id;
            break;
          }
        }
      }
    }
    final candidates = project.components
        .where(
          (candidate) =>
              candidate.id != componentId &&
              (candidate.kind == ComponentKind.contactor ||
                  candidate.kind == ComponentKind.contactor4P),
        )
        .toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'التعشيق الميكانيكي Étoile / Triangle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'يُحفظ زوج واحد فقط: جهاز star وجهاز delta. اتركه بلا ربط للعمل المستقل.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey<String>(
                '$componentId-${component.text('interlockGroup')}',
              ),
              initialValue: _interlockGroup,
              decoration: const InputDecoration(
                labelText: 'اسم المجموعة',
                hintText: 'مثال: m1_star_delta',
              ),
              onChanged: (value) {
                _interlockGroup = value;
                _interlockDirty = true;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('peer-${_interlockPeerId ?? 'none'}'),
              initialValue: _interlockPeerId,
              decoration:
                  const InputDecoration(labelText: 'الكونتاكتور المقابل'),
              items: candidates
                  .map(
                    (candidate) => DropdownMenuItem<String>(
                      value: candidate.id,
                      child: Text(candidate.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: candidates.isEmpty
                  ? null
                  : (value) => setState(() {
                        _interlockPeerId = value;
                        _interlockDirty = true;
                      }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _interlockRole,
              decoration: const InputDecoration(labelText: 'دور هذا الجهاز'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'star', child: Text('Étoile / نجمة')),
                DropdownMenuItem(
                    value: 'delta', child: Text('Triangle / مثلث')),
              ],
              onChanged: (value) => setState(() {
                _interlockRole = value ?? 'star';
                _interlockDirty = true;
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () {
                    final error = widget.controller.configureInterlockPair(
                      componentId,
                      _interlockPeerId ?? '',
                      _interlockGroup,
                      _interlockRole,
                    );
                    if (error == null) {
                      setState(() => _interlockDirty = false);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error ?? 'تم ربط زوج التعشيق والتحقق من الدورين.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('ربط الزوج'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final error =
                        widget.controller.clearInterlockPair(componentId);
                    if (error == null) {
                      setState(() => _interlockDirty = false);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(error ?? 'تم فك التعشيق للطرفين.')),
                    );
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('فك التعشيق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _terminalsTab(String componentId) {
    final component = widget.controller.project.componentById(componentId)!;
    final spec = ComponentCatalog.specOf(component.kind);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
            'هذه الأطراف هي نفسها المستعملة في اللوحة والمجسم ومحرك MNA.'),
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

  static String? _validateNumber(String key, String? text) {
    final parsed = double.tryParse(text ?? '');
    if (parsed == null || !parsed.isFinite) {
      return 'أدخل رقماً صالحاً';
    }
    if (parsed < 0 &&
        !const <String>{'temperature', 'setpoint'}.contains(key)) {
      return 'أدخل قيمة غير سالبة';
    }
    final limits = const <String, List<double>>{
      'frequency': <double>[40, 70],
      'residualThreshold': <double>[0.001, 1],
      'powerFactor': <double>[0.2, 1],
      'delaySeconds': <double>[0.05, 3600],
      'tripTime': <double>[0.2, 3600],
      'internalResistance': <double>[0.001, 100],
      'primaryResistance': <double>[0.001, 100],
      'secondaryResistance': <double>[0.001, 100],
      'ratedCurrent': <double>[0.001, 1000],
      'nominalCurrent': <double>[0.01, 1000],
      'coilResistance': <double>[0.1, 1000000],
      'powerWatts': <double>[0.01, 10000],
      'maxVoltage': <double>[1, 1000],
      'maxCurrent': <double>[0.001, 1000],
      'pickupRatio': <double>[0.1, 1],
      'dropoutRatio': <double>[0.05, 1],
      'turnsRatio': <double>[0.000001, 1],
      'burdenResistance': <double>[0.01, 10000],
      'crossSectionMm2': <double>[0.05, 1000],
      'lengthMeters': <double>[0.01, 10000],
      'resistivity': <double>[0.001, 1],
      'hysteresis': <double>[0.05, 100],
    }[key];
    if (limits != null && (parsed < limits[0] || parsed > limits[1])) {
      return 'القيمة المدعومة بين ${limits[0]} و${limits[1]}';
    }
    const voltages = <String>{
      'voltage',
      'lineVoltage',
      'nominalVoltage',
      'ratedVoltage',
      'coilVoltage',
      'primaryVoltage',
      'secondaryVoltage',
      'minVoltage',
      'maxSecondaryVoltage',
    };
    if (voltages.contains(key) && (parsed < 0.1 || parsed > 1000)) {
      return 'الجهد المدعوم بين 0.1 و1000 V';
    }
    return null;
  }

  static String _propertyName(String key) => switch (key) {
        'voltage' => 'الجهد RMS/DC',
        'lineVoltage' => 'الجهد بين الأطوار',
        'frequency' => 'التردد Hz',
        'internalResistance' => 'المقاومة الداخلية Ω',
        'residualThreshold' => 'عتبة تيار التسرب A',
        'primaryVoltage' => 'جهد الملف الابتدائي V',
        'secondaryVoltage' => 'جهد الملف الثانوي V',
        'primaryResistance' => 'مقاومة الملف الابتدائي Ω',
        'secondaryResistance' => 'مقاومة الملف الثانوي Ω',
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
        'powerWatts' => 'القدرة المقننة W',
        'maxVoltage' => 'أقصى جهد للقياس V',
        'maxCurrent' => 'أقصى تيار للقياس A',
        'maxSecondaryVoltage' => 'أقصى جهد ثانوي V',
        'minVoltage' => 'أدنى جهد بين الأطوار V',
        'turnsRatio' => 'نسبة تحويل التيار Np/Ns',
        'burdenResistance' => 'مقاومة عبء CT Ω',
        'temperature' => 'الحرارة الحالية °C',
        'setpoint' => 'نقطة الضبط °C',
        'hysteresis' => 'التهيستيريسس °C',
        'heating' => 'وضع تسخين (إيقافه تبريد)',
        'crossed' => 'التوصيل متقاطع',
        'lengthMeters' => 'طول الكابل m',
        'crossSectionMm2' => 'مقطع الكابل mm²',
        'resistivity' => 'المقاومة النوعية Ω·mm²/m',
        'interlockGroup' => 'مجموعة التعشيق الميكانيكي (فارغ = بلا تعشيق)',
        'interlockRole' => 'الدور: star أو delta (فارغ = مستقل)',
        _ => key,
      };
}
