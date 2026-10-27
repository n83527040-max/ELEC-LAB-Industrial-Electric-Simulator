enum DiagnosticSeverity { info, warning, error, success }

class SimulationDiagnostic {
  const SimulationDiagnostic({
    required this.code,
    required this.messageAr,
    this.componentId,
    this.severity = DiagnosticSeverity.info,
  });

  final String code;
  final String messageAr;
  final String? componentId;
  final DiagnosticSeverity severity;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'messageAr': messageAr,
        'componentId': componentId,
        'severity': severity.name,
      };
}

class DeviceReading {
  const DeviceReading({
    required this.componentId,
    this.voltage = 0,
    this.current = 0,
    this.activePower = 0,
    this.energized = false,
    this.active = false,
    this.tripped = false,
    this.blown = false,
    this.direction = 0,
    this.timerRemaining = 0,
    this.measurementValid = true,
    this.residualCurrent = 0,
    this.energyKwh = 0,
  });

  final String componentId;
  final double voltage;
  final double current;
  final double activePower;
  final bool energized;
  final bool active;
  final bool tripped;
  final bool blown;
  final int direction;
  final double timerRemaining;
  final bool measurementValid;
  final double residualCurrent;
  final double energyKwh;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'componentId': componentId,
        'voltage': voltage,
        'current': current,
        'activePower': activePower,
        'energized': energized,
        'active': active,
        'tripped': tripped,
        'blown': blown,
        'direction': direction,
        'timerRemaining': timerRemaining,
        'measurementValid': measurementValid,
        'residualCurrent': residualCurrent,
        'energyKwh': energyKwh,
      };
}

class SimulationResult {
  const SimulationResult({
    required this.time,
    required this.success,
    required this.devices,
    required this.wireCurrents,
    required this.diagnostics,
  });

  final double time;
  final bool success;
  final Map<String, DeviceReading> devices;
  final Map<String, double> wireCurrents;
  final List<SimulationDiagnostic> diagnostics;

  DeviceReading? operator [](String componentId) => devices[componentId];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time,
        'success': success,
        'devices': devices.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'wireCurrents': wireCurrents,
        'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
      };
}
