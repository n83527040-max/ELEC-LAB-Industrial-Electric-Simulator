import 'package:flutter/material.dart';

import '../models/board_geometry.dart';
import '../models/geometry.dart';
import '../models/wire.dart';
import '../models/wire_sizing.dart';
import '../state/editor_controller.dart';

class WireSettingsSheet extends StatefulWidget {
  const WireSettingsSheet({required this.controller, super.key});

  final EditorController controller;

  @override
  State<WireSettingsSheet> createState() => _WireSettingsSheetState();
}

class _WireSettingsSheetState extends State<WireSettingsSheet> {
  final TextEditingController _current = TextEditingController();
  ConductorMaterial _material = ConductorMaterial.copper;
  CableUsage _usage = CableUsage.power;
  bool _grouped = false;
  double _temperature = 30;
  WireSizingSuggestion? _suggestion;

  @override
  void dispose() {
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final wire = controller.selectedWire;
    if (wire == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('اختر سلكاً.')),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentWire = controller.selectedWire ?? wire;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('خصائص السلك', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              const Text('اللون (تمييز بصري قابل للضبط)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: <int>[
                  0xffe53935,
                  0xff1e88e5,
                  0xff202020,
                  0xfffdd835,
                  0xff43a047,
                  0xffeeeeee,
                ].map((color) => _colorChoice(context, currentWire, color)).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'اللون لا يحدد وظيفة السلك؛ القواعد تختلف حسب المعيار والسياق.',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<double>(
                initialValue: currentWire.crossSectionMm2,
                decoration: const InputDecoration(labelText: 'المقطع mm²'),
                items: const <double>[0.5, 0.75, 1, 1.5, 2.5, 4, 6, 10, 16, 25]
                    .map(
                      (section) => DropdownMenuItem<double>(
                        value: section,
                        child: Text('$section mm²', textDirection: TextDirection.ltr),
                      ),
                    )
                    .toList(),
                onChanged: (value) => controller.updateWire(
                  currentWire.copyWith(crossSectionMm2: value),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<WireConductorType>(
                initialValue: currentWire.conductorType,
                decoration: const InputDecoration(labelText: 'نوع الموصل'),
                items: const <DropdownMenuItem<WireConductorType>>[
                  DropdownMenuItem(value: WireConductorType.solid, child: Text('صلب Solid')),
                  DropdownMenuItem(value: WireConductorType.stranded, child: Text('مرن Stranded')),
                  DropdownMenuItem(value: WireConductorType.shielded, child: Text('مغلف Shielded')),
                ],
                onChanged: (value) => controller.updateWire(
                  currentWire.copyWith(conductorType: value),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: currentWire.insulationVoltage,
                decoration: const InputDecoration(labelText: 'تصنيف العزل المدخل'),
                items: const <int>[300, 450, 750, 1000]
                    .map(
                      (voltage) => DropdownMenuItem<int>(
                        value: voltage,
                        child: Text('$voltage V', textDirection: TextDirection.ltr),
                      ),
                    )
                    .toList(),
                onChanged: (value) => controller.updateWire(
                  currentWire.copyWith(insulationVoltage: value),
                ),
              ),
              const SizedBox(height: 16),
              const Text('نمط المسار'),
              const SizedBox(height: 8),
              SegmentedButton<WireRouteStyle>(
                segments: const <ButtonSegment<WireRouteStyle>>[
                  ButtonSegment(value: WireRouteStyle.straight, label: Text('مستقيم')),
                  ButtonSegment(value: WireRouteStyle.orthogonal, label: Text('زاوية 90°')),
                  ButtonSegment(value: WireRouteStyle.curved, label: Text('منحني')),
                ],
                selected: <WireRouteStyle>{currentWire.routeStyle},
                onSelectionChanged: (value) => controller.updateWire(
                  currentWire.copyWith(routeStyle: value.first),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _addMidpoint(currentWire),
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('إضافة نقطة انحناء'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => controller.autoRouteWire(currentWire.id),
                    icon: const Icon(Icons.alt_route),
                    label: const Text('ترتيب تلقائي'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      controller.deleteWire(currentWire.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف السلك'),
                  ),
                ],
              ),
              const Divider(height: 28),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('اقتراح تعليمي للمقطع'),
                subtitle: const Text('يتطلب التيار والمادة والظروف'),
                children: <Widget>[
                  TextField(
                    controller: _current,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'التيار المتوقع A'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ConductorMaterial>(
                    initialValue: _material,
                    decoration: const InputDecoration(labelText: 'مادة الموصل'),
                    items: const <DropdownMenuItem<ConductorMaterial>>[
                      DropdownMenuItem(value: ConductorMaterial.copper, child: Text('نحاس Cu')),
                      DropdownMenuItem(value: ConductorMaterial.aluminum, child: Text('ألمنيوم Al')),
                    ],
                    onChanged: (value) => setState(() => _material = value!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('داخل قناة مع كابلات مجمعة'),
                    value: _grouped,
                    onChanged: (value) => setState(() => _grouped = value),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الاستعمال'),
                    trailing: DropdownButton<CableUsage>(
                      value: _usage,
                      items: const <DropdownMenuItem<CableUsage>>[
                        DropdownMenuItem(value: CableUsage.control, child: Text('تحكم')),
                        DropdownMenuItem(value: CableUsage.power, child: Text('قدرة')),
                      ],
                      onChanged: (value) => setState(() => _usage = value!),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('حرارة المحيط'),
                    trailing: SizedBox(
                      width: 110,
                      child: Slider(
                        value: _temperature,
                        min: 0,
                        max: 60,
                        divisions: 12,
                        label: '$_temperature°C',
                        onChanged: (value) => setState(() => _temperature = value),
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final current = double.tryParse(_current.text);
                      setState(() {
                        _suggestion = current == null
                            ? null
                            : EducationalWireSizing.suggest(
                                WireSizingInput(
                                  expectedCurrent: current,
                                  material: _material,
                                  usage: _usage,
                                  ambientTemperature: _temperature,
                                  groupedInConduit: _grouped,
                                ),
                              );
                      });
                    },
                    icon: const Icon(Icons.rule),
                    label: const Text('احسب اقتراحاً'),
                  ),
                  if (_suggestion != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'المقطع المقترح: ${_suggestion!.sectionMm2} mm² • تيار التصميم ${_suggestion!.designCurrent.toStringAsFixed(1)}A',
                    ),
                    TextButton(
                      onPressed: () => controller.updateWire(
                        currentWire.copyWith(
                          crossSectionMm2: _suggestion!.sectionMm2,
                        ),
                      ),
                      child: const Text('تطبيق المقطع'),
                    ),
                    Text(
                      _suggestion!.disclaimerAr,
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ] else if (_current.text.isNotEmpty)
                    const Text('لا يوجد اقتراح؛ تحقق من المدخلات أو استشر مرجعاً مؤهلاً.'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _colorChoice(BuildContext context, CircuitWire wire, int color) {
    return InkWell(
      onTap: () => widget.controller.updateWire(wire.copyWith(colorValue: color)),
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(color),
          border: Border.all(
            color: wire.colorValue == color ? const Color(0xff00a6ff) : Colors.grey,
            width: wire.colorValue == color ? 3 : 1,
          ),
        ),
      ),
    );
  }

  void _addMidpoint(CircuitWire wire) {
    final points = WireRouter.route(widget.controller.project, wire);
    if (points.length < 2) return;
    final middle = points[points.length ~/ 2];
    final before = points[(points.length ~/ 2) - 1];
    widget.controller.addWireWaypoint(
      wire.id,
      BoardPoint((middle.x + before.x) / 2, (middle.y + before.y) / 2),
    );
  }
}
