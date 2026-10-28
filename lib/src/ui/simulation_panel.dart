import 'package:flutter/material.dart';

import '../learning/challenges.dart';
import '../models/component_catalog.dart';
import '../models/terminal.dart';
import '../simulation/simulation_result.dart';
import '../state/editor_controller.dart';

class SimulationPanel extends StatelessWidget {
  const SimulationPanel({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final result = controller.result;
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'نتائج المحاكاة والتشخيص',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (result != null)
                      Text('t = ${result.time.toStringAsFixed(1)} s', textDirection: TextDirection.ltr),
                  ],
                ),
              ),
              if (result == null)
                const Expanded(
                  child: Center(child: Text('شغّل المحاكاة لعرض القياسات والأخطاء.')),
                )
              else ...<Widget>[
                Material(
                  color: result.success
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: Icon(result.success ? Icons.check_circle : Icons.error),
                    title: Text(result.success ? 'تم حل الشبكة' : 'فشل حل الشبكة'),
                    subtitle: Text('${controller.project.wires.length} أسلاك • ${result.devices.length} أجهزة'),
                    trailing: IconButton(
                      onPressed: controller.resetSimulation,
                      icon: const Icon(Icons.restart_alt),
                      tooltip: 'تصفير الزمن والحمايات',
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      ...result.diagnostics.map(
                        (diagnostic) => _DiagnosticTile(diagnostic: diagnostic),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'أجهزة القياس والأحمال',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...controller.project.components
                          .where((component) => _showReading(component.kind))
                          .map((component) {
                        final reading = result[component.id];
                        if (reading == null) return const SizedBox.shrink();
                        return ListTile(
                          leading: Icon(
                            reading.measurementValid
                                ? Icons.monitor_outlined
                                : Icons.warning_amber,
                            color: reading.measurementValid ? null : Colors.red,
                          ),
                          title: Text('${component.label} • ${ComponentCatalog.specOf(component.kind).nameFr}'),
                          subtitle: Text(_readingText(component.kind, reading)),
                          trailing: reading.active
                              ? const Icon(Icons.play_circle, color: Colors.green)
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static bool _showReading(ComponentKind kind) =>
      kind == ComponentKind.voltmeter ||
      kind == ComponentKind.ammeter ||
      kind == ComponentKind.digitalCounter ||
      kind == ComponentKind.wattmeter ||
      kind == ComponentKind.frequencyMeter ||
      kind == ComponentKind.currentTransformer ||
      kind == ComponentKind.differentialBreaker ||
      kind == ComponentKind.rccb2P ||
      kind == ComponentKind.motor3Phase ||
      kind == ComponentKind.motor6Terminal ||
      kind == ComponentKind.motor1Phase ||
      kind == ComponentKind.fan ||
      kind == ComponentKind.pump ||
      kind == ComponentKind.solenoidValve ||
      kind == ComponentKind.transformer ||
      kind == ComponentKind.bellTransformer ||
      kind == ComponentKind.voltageTransformer ||
      kind == ComponentKind.indicator ||
      kind == ComponentKind.ledLamp ||
      kind == ComponentKind.bell ||
      kind == ComponentKind.buzzer ||
      kind == ComponentKind.timer ||
      kind == ComponentKind.staircaseTimer ||
      kind == ComponentKind.timerOffDelay;

  static String _readingText(ComponentKind kind, DeviceReading reading) {
    return switch (kind) {
      ComponentKind.voltmeter =>
        '${reading.voltage.toStringAsFixed(2)} V ${reading.measurementValid ? '' : '• قياس غير صالح'}',
      ComponentKind.frequencyMeter =>
        '${reading.frequency.toStringAsFixed(2)} Hz • ${reading.voltage.toStringAsFixed(1)} V ${reading.measurementValid ? '' : '• قياس غير صالح'}',
      ComponentKind.currentTransformer =>
        'Ip ${reading.current.toStringAsFixed(2)} A • Is ${reading.secondaryCurrent.toStringAsFixed(3)} A • Vs ${reading.voltage.toStringAsFixed(2)} V ${reading.measurementValid ? '' : '• مراجعة العبء'}',
      ComponentKind.wattmeter =>
        '${reading.activePower.toStringAsFixed(2)} W • ${reading.voltage.toStringAsFixed(1)} V • ${reading.current.toStringAsFixed(2)} A ${reading.measurementValid ? '' : '• قياس غير صالح'}',
      ComponentKind.ammeter =>
        '${reading.current.toStringAsFixed(3)} A ${reading.measurementValid ? '' : '• قياس غير صالح'}',
      ComponentKind.digitalCounter =>
        '${reading.voltage.toStringAsFixed(1)} V • ${reading.current.toStringAsFixed(2)} A • ${reading.energyKwh.toStringAsFixed(6)} kWh ${reading.measurementValid ? '' : '• قياس غير صالح'}',
      ComponentKind.differentialBreaker ||
      ComponentKind.rccb2P =>
        'ΔI ${(reading.residualCurrent * 1000).toStringAsFixed(1)} mA • ${reading.current.toStringAsFixed(2)} A',
      ComponentKind.transformer ||
      ComponentKind.bellTransformer ||
      ComponentKind.voltageTransformer =>
        'ثانوي ${reading.voltage.toStringAsFixed(2)} V • ${reading.current.toStringAsFixed(3)} A • مدخل ${reading.activePower.toStringAsFixed(2)} W',
      ComponentKind.motor3Phase ||
      ComponentKind.pump =>
        '${reading.voltage.toStringAsFixed(1)} V • ${reading.current.toStringAsFixed(2)} A • ${reading.direction == 0 ? 'متوقف' : reading.direction > 0 ? 'أمامي' : 'عكسي'}',
      ComponentKind.motor6Terminal =>
        '${reading.connectionMode == 'star' ? 'Étoile' : reading.connectionMode == 'delta' ? 'Triangle' : 'Open'} • ${reading.voltage.toStringAsFixed(1)} V • ${reading.current.toStringAsFixed(2)} A',
      ComponentKind.motor1Phase ||
      ComponentKind.fan ||
      ComponentKind.solenoidValve =>
        '${reading.voltage.toStringAsFixed(1)} V • ${reading.current.toStringAsFixed(2)} A • ${reading.active ? 'يدور' : 'متوقف'}',
      ComponentKind.timer ||
      ComponentKind.staircaseTimer ||
      ComponentKind.timerOffDelay =>
        reading.active ? 'النقطة مغلقة • المتبقي ${reading.timerRemaining.toStringAsFixed(1)} s' : 'المتبقي ${reading.timerRemaining.toStringAsFixed(1)} s',
      _ => '${reading.voltage.toStringAsFixed(1)} V • ${reading.activePower.toStringAsFixed(2)} W',
    };
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.diagnostic});

  final SimulationDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final color = switch (diagnostic.severity) {
      DiagnosticSeverity.error => Colors.red,
      DiagnosticSeverity.warning => Colors.orange,
      DiagnosticSeverity.success => Colors.green,
      DiagnosticSeverity.info => Colors.blue,
    };
    return ExpansionTile(
      leading: Icon(
        diagnostic.severity == DiagnosticSeverity.error
            ? Icons.error_outline
            : diagnostic.severity == DiagnosticSeverity.success
                ? Icons.check_circle_outline
                : Icons.info_outline,
        color: color,
      ),
      title: Text(diagnostic.messageAr),
      children: DiagnosticAdvisor.hintsFor(diagnostic)
          .map(
            (hint) => ListTile(
              dense: true,
              leading: const Icon(Icons.lightbulb_outline, size: 18),
              title: Text(hint),
            ),
          )
          .toList(),
    );
  }
}
