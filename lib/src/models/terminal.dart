import 'geometry.dart';

enum ComponentKind {
  dcSupply,
  acSupply,
  threePhaseSupply,
  circuitBreaker,
  differentialBreaker,
  motorBreaker,
  contactor,
  thermalRelay,
  auxiliaryRelay,
  pushButtonNO,
  pushButtonNC,
  emergencyStop,
  selectorSwitch,
  rotarySwitch,
  timer,
  timerOffDelay,
  sensor,
  limitSwitch,
  indicator,
  motor3Phase,
  motor1Phase,
  transformer,
  terminalBlock,
  voltmeter,
  ammeter,
  digitalCounter,
  fuse,
}

enum ComponentCategory {
  sources,
  protection,
  contactors,
  control,
  timers,
  sensors,
  motors,
  signals,
  measurement,
  terminals,
}

enum TerminalKind { power, coil, auxiliary, measurement, neutral, earth }

class TerminalDefinition {
  const TerminalDefinition({
    required this.id,
    required this.label,
    required this.position,
    required this.kind,
    this.phase,
  });

  final String id;
  final String label;
  final BoardPoint position;
  final TerminalKind kind;
  final String? phase;
}

class TerminalRef {
  const TerminalRef({required this.componentId, required this.terminalId});

  final String componentId;
  final String terminalId;

  String get key => '$componentId::$terminalId';

  Map<String, String> toJson() => <String, String>{
        'componentId': componentId,
        'terminalId': terminalId,
      };

  factory TerminalRef.fromJson(Map<String, dynamic> json) {
    final componentId = json['componentId'];
    final terminalId = json['terminalId'];
    if (componentId is! String ||
        componentId.isEmpty ||
        terminalId is! String ||
        terminalId.isEmpty) {
      throw const FormatException('Invalid terminal reference.');
    }
    return TerminalRef(componentId: componentId, terminalId: terminalId);
  }

  @override
  bool operator ==(Object other) =>
      other is TerminalRef &&
      other.componentId == componentId &&
      other.terminalId == terminalId;

  @override
  int get hashCode => Object.hash(componentId, terminalId);

  @override
  String toString() => key;
}
