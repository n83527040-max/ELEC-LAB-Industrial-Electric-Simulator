class DeviceRuntime {
  const DeviceRuntime({
    this.energized = false,
    this.tripped = false,
    this.blown = false,
    this.timerElapsed = 0,
    this.thermalStress = 0,
    this.overloadTime = 0,
    this.timerOutput = false,
    this.energyKwh = 0,
    this.latched = false,
    this.wasEnergized = false,
  });

  final bool energized;
  final bool tripped;
  final bool blown;
  final double timerElapsed;
  final double thermalStress;
  final double overloadTime;
  final bool timerOutput;
  final double energyKwh;
  final bool latched;
  final bool wasEnergized;

  DeviceRuntime copyWith({
    bool? energized,
    bool? tripped,
    bool? blown,
    double? timerElapsed,
    double? thermalStress,
    double? overloadTime,
    bool? timerOutput,
    double? energyKwh,
    bool? latched,
    bool? wasEnergized,
  }) {
    return DeviceRuntime(
      energized: energized ?? this.energized,
      tripped: tripped ?? this.tripped,
      blown: blown ?? this.blown,
      timerElapsed: timerElapsed ?? this.timerElapsed,
      thermalStress: thermalStress ?? this.thermalStress,
      overloadTime: overloadTime ?? this.overloadTime,
      timerOutput: timerOutput ?? this.timerOutput,
      energyKwh: energyKwh ?? this.energyKwh,
      latched: latched ?? this.latched,
      wasEnergized: wasEnergized ?? this.wasEnergized,
    );
  }
}

class SimulationRuntime {
  SimulationRuntime({this.time = 0, Map<String, DeviceRuntime>? devices})
      : devices = devices ?? <String, DeviceRuntime>{};

  double time;
  final Map<String, DeviceRuntime> devices;

  DeviceRuntime operator [](String id) => devices[id] ?? const DeviceRuntime();

  void update(String id, DeviceRuntime state) => devices[id] = state;

  void resetProtection(String id) {
    update(
      id,
      this[id].copyWith(
        tripped: false,
        blown: false,
        thermalStress: 0,
        overloadTime: 0,
      ),
    );
  }

  void reset() {
    time = 0;
    devices.clear();
  }
}
