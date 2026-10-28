import 'dart:math' as math;

import '../models/board_geometry.dart';
import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/project.dart';
import '../models/terminal.dart';
import 'complex_number.dart';
import 'linear_solver.dart';
import 'simulation_result.dart';
import 'simulation_runtime.dart';

/// Deterministic DC / sinusoidal steady-state circuit simulator.
///
/// The solver uses modified nodal analysis (MNA). Contactors are iterated to a
/// fixed point so auxiliary contacts and self-holding circuits affect the next
/// electrical solution. Protection and ON-delay timers use [step]'s explicit
/// delta time; they are not driven by widget animations.
class ElectricalSimulator {
  ElectricalSimulator({SimulationRuntime? runtime})
      : runtime = runtime ?? SimulationRuntime();

  final SimulationRuntime runtime;

  SimulationResult step(
    ElectricalProject project, {
    double deltaSeconds = 0.1,
  }) {
    final dt = deltaSeconds.clamp(0.001, 1.0).toDouble();
    runtime.time += dt;
    project.validate();

    var network = _settle(project);
    if (!network.solved) return _failedResult(project, network);

    var readings = _read(project, network);
    final diagnostics = <SimulationDiagnostic>[];
    final dynamicsChanged = _advanceDynamics(
      project,
      network,
      readings,
      dt,
      diagnostics,
    );
    if (dynamicsChanged) {
      network = _settle(project);
      if (!network.solved) return _failedResult(project, network);
      readings = _read(project, network);
    }
    diagnostics.addAll(_diagnose(project, network, readings));
    return SimulationResult(
      time: runtime.time,
      success: true,
      devices: readings,
      wireCurrents: _wireCurrents(network),
      diagnostics: diagnostics,
    );
  }

  void reset() => runtime.reset();

  void resetProtection(String componentId) =>
      runtime.resetProtection(componentId);

  _Network _settle(ElectricalProject project) {
    _Network? last;
    for (var iteration = 0; iteration < 12; iteration++) {
      final network = _Network.build(project, runtime);
      last = network;
      if (!network.solve()) return network;
      var changed = false;
      for (final component in project.components) {
        final state = runtime[component.id];
        if (component.kind == ComponentKind.phaseRelay) {
          final desired = _phaseRelayHealthy(network, component);
          if (desired != state.energized) {
            runtime.update(
              component.id,
              state.copyWith(energized: desired),
            );
            changed = true;
          }
          continue;
        }
        if (!_hasCoil(component.kind)) continue;
        final voltage = _coilVoltage(network, component);
        final rated = _coilRatedVoltage(component);
        final pickup = rated * _number(component, 'pickupRatio', 0.8);
        final dropout = rated * _number(component, 'dropoutRatio', 0.35);
        final coilFault = component.text('fault') == 'coilOpen' ||
            component.text('fault') == 'open';
        final desired = !coilFault &&
            (state.energized ? voltage >= dropout : voltage >= pickup);
        if (desired != state.energized) {
          runtime.update(
            component.id,
            state.copyWith(energized: desired),
          );
          changed = true;
        }
      }
      if (!changed) {
        network.converged = true;
        return network;
      }
    }
    return last!..converged = false;
  }

  bool _advanceDynamics(
    ElectricalProject project,
    _Network network,
    Map<String, DeviceReading> readings,
    double dt,
    List<SimulationDiagnostic> diagnostics,
  ) {
    var changed = false;
    for (final component in project.components) {
      final state = runtime[component.id];
      final reading = readings[component.id];
      switch (component.kind) {
        case ComponentKind.timer:
          final elapsed = state.energized ? state.timerElapsed + dt : 0.0;
          final delay = math.max(0.05, component.number('delaySeconds'));
          final wasClosed = state.timerElapsed >= delay;
          final isClosed = elapsed >= delay;
          runtime.update(component.id, state.copyWith(timerElapsed: elapsed));
          if (wasClosed != isClosed) changed = true;
        case ComponentKind.timerOffDelay:
        case ComponentKind.staircaseTimer:
          final delay = math.max(0.05, component.number('delaySeconds'));
          if (state.energized) {
            if (!state.timerOutput || state.timerElapsed != 0) {
              runtime.update(
                component.id,
                state.copyWith(timerElapsed: 0, timerOutput: true),
              );
              if (!state.timerOutput) changed = true;
            }
          } else if (state.timerOutput) {
            final elapsed = state.timerElapsed + dt;
            final output = elapsed < delay;
            runtime.update(
              component.id,
              state.copyWith(timerElapsed: elapsed, timerOutput: output),
            );
            if (!output) changed = true;
          }
        case ComponentKind.circuitBreaker:
        case ComponentKind.mcb2P:
        case ComponentKind.mcb3P:
        case ComponentKind.mcb4P:
        case ComponentKind.mccb3P:
          if (state.tripped || !component.flag('closed')) break;
          final current = reading?.current ?? 0;
          final rated = math.max(0.1, component.number('ratedCurrent'));
          var overload = state.overloadTime;
          var tripped = false;
          if (current > rated * 6) {
            tripped = true;
          } else if (current > rated * 1.2) {
            overload += dt * math.pow(current / rated, 2).toDouble();
            tripped = overload >= 2.0;
          } else {
            overload = math.max(0, overload - dt * 0.5);
          }
          if (tripped) {
            runtime.update(
              component.id,
              state.copyWith(tripped: true, overloadTime: overload),
            );
            diagnostics.add(
              SimulationDiagnostic(
                code: 'breaker_trip',
                componentId: component.id,
                severity: DiagnosticSeverity.error,
                messageAr:
                    'فصل ${component.label} (Disjoncteur): تيار ${current.toStringAsFixed(2)}A تجاوز حد الحماية.',
              ),
            );
            changed = true;
          } else if (overload != state.overloadTime) {
            runtime.update(
              component.id,
              state.copyWith(overloadTime: overload),
            );
          }
        case ComponentKind.differentialBreaker:
        case ComponentKind.rccb2P:
          if (state.tripped || !component.flag('closed')) break;
          final current = reading?.current ?? 0;
          final residual = reading?.residualCurrent ?? 0;
          final isRcbo = component.kind == ComponentKind.differentialBreaker;
          final rated = isRcbo
              ? math.max(0.1, component.number('ratedCurrent'))
              : double.infinity;
          final threshold = math.max(
            0.001,
            component.number('residualThreshold'),
          );
          var overload = state.overloadTime;
          if (isRcbo && current > rated * 1.2) {
            overload += dt * math.pow(current / rated, 2).toDouble();
          } else {
            overload = math.max(0, overload - dt * 0.5);
          }
          final residualTrip = residual > threshold;
          final overcurrentTrip =
              isRcbo && (current > rated * 6 || overload >= 2);
          if (residualTrip || overcurrentTrip) {
            runtime.update(
              component.id,
              state.copyWith(tripped: true, overloadTime: overload),
            );
            diagnostics.add(
              SimulationDiagnostic(
                code: residualTrip ? 'differential_trip' : 'breaker_trip',
                componentId: component.id,
                severity: DiagnosticSeverity.error,
                messageAr: residualTrip
                    ? 'فصل ${component.label}: تيار التسرب ${(residual * 1000).toStringAsFixed(1)}mA تجاوز ${(threshold * 1000).toStringAsFixed(1)}mA.'
                    : 'فصل ${component.label} بسبب تجاوز التيار المقنن.',
              ),
            );
            changed = true;
          } else if (overload != state.overloadTime) {
            runtime.update(
              component.id,
              state.copyWith(overloadTime: overload),
            );
          }
        case ComponentKind.thermalRelay:
        case ComponentKind.motorBreaker:
          if (state.tripped ||
              (component.kind == ComponentKind.motorBreaker &&
                  !component.flag('closed'))) {
            break;
          }
          final current = reading?.current ?? 0;
          final rated = math.max(0.1, component.number('ratedCurrent'));
          final tripTime = math.max(0.2, component.number('tripTime'));
          var stress = state.thermalStress;
          if (current > rated) {
            stress +=
                dt * (math.pow(current / rated, 2).toDouble() - 1) / tripTime;
          } else {
            stress -= dt / (tripTime * 2);
          }
          stress = stress.clamp(0.0, 1.2).toDouble();
          final instantaneous = component.kind == ComponentKind.motorBreaker &&
              current > rated * 8;
          final tripped = stress >= 1.0 || instantaneous;
          runtime.update(
            component.id,
            state.copyWith(thermalStress: stress, tripped: tripped),
          );
          if (tripped) {
            final motorBreaker = component.kind == ComponentKind.motorBreaker;
            diagnostics.add(
              SimulationDiagnostic(
                code: motorBreaker ? 'motor_breaker_trip' : 'thermal_trip',
                componentId: component.id,
                severity: DiagnosticSeverity.error,
                messageAr: motorBreaker
                    ? 'فصل ${component.label} (Disjoncteur moteur) بسبب حمل زائد أو تيار قصر.'
                    : 'فصل ${component.label} (Relais thermique) بسبب حمل زائد مستمر. أعد ضبطه بعد تشخيص السبب.',
              ),
            );
            changed = true;
          }
        case ComponentKind.fuse:
          if (state.blown) break;
          final current = reading?.current ?? 0;
          final rated = math.max(0.001, component.number('ratedCurrent'));
          var overload = state.overloadTime;
          var blown = current > rated * 5;
          if (current > rated * 1.5) {
            overload += dt * math.pow(current / rated, 2).toDouble();
            blown = blown || overload >= 1.5;
          } else {
            overload = math.max(0, overload - dt * 0.2);
          }
          if (blown) {
            runtime.update(
              component.id,
              state.copyWith(blown: true, overloadTime: overload),
            );
            diagnostics.add(
              SimulationDiagnostic(
                code: 'fuse_blown',
                componentId: component.id,
                severity: DiagnosticSeverity.error,
                messageAr:
                    'انصهر ${component.label} (Fusible). استبدله افتراضياً بعد إزالة العطل.',
              ),
            );
            changed = true;
          } else if (overload != state.overloadTime) {
            runtime.update(
              component.id,
              state.copyWith(overloadTime: overload),
            );
          }
        case ComponentKind.impulseRelay:
          var latched = state.latched;
          if (state.energized && !state.wasEnergized) {
            latched = !latched;
            changed = true;
          }
          if (latched != state.latched ||
              state.wasEnergized != state.energized) {
            runtime.update(
              component.id,
              state.copyWith(
                latched: latched,
                wasEnergized: state.energized,
              ),
            );
          }
        case ComponentKind.thermostat:
          final temperature = component.number('temperature');
          final setpoint = component.number('setpoint');
          final hysteresis = math.max(0.05, component.number('hysteresis'));
          final heating = component.flag('heating');
          final desired = heating
              ? (state.latched
                  ? temperature < setpoint
                  : temperature <= setpoint - hysteresis)
              : (state.latched
                  ? temperature > setpoint
                  : temperature >= setpoint + hysteresis);
          if (desired != state.latched) {
            runtime.update(component.id, state.copyWith(latched: desired));
            changed = true;
          }
        case ComponentKind.digitalCounter:
          if (reading != null && reading.measurementValid) {
            final energy = state.energyKwh +
                math.max(0, reading.activePower) * dt / 3600000;
            runtime.update(
              component.id,
              state.copyWith(energyKwh: energy),
            );
            changed = changed || energy != state.energyKwh;
          }
        default:
          break;
      }
    }
    return changed;
  }

  Map<String, DeviceReading> _read(
    ElectricalProject project,
    _Network network,
  ) {
    final result = <String, DeviceReading>{};
    for (final component in project.components) {
      final state = runtime[component.id];
      final branches = network.branches[component.id] ?? const <_Branch>[];
      final main = branches.where((item) => item.role == 'main').toList();
      final coil = branches.where((item) => item.role == 'coil').toList();
      final measurement =
          branches.where((item) => item.role == 'measurement').toList();
      final motor = branches.where((item) => item.role == 'motor').toList();
      double maximumCurrent(List<_Branch> items) => items.fold<double>(
            0,
            (value, item) => math.max(value, network.current(item).magnitude),
          );
      var voltage = 0.0;
      var current = maximumCurrent(main);
      var power = branches.fold<double>(
        0,
        (value, item) => value + network.realPower(item),
      );
      var active = false;
      var validMeasurement = true;
      var direction = 0;
      var timerRemaining = 0.0;
      var residualCurrent = 0.0;
      var secondaryCurrent = 0.0;
      var frequency = 0.0;
      var connectionMode = '';

      if (coil.isNotEmpty) {
        voltage = network.voltage(coil.first.a, coil.first.b).magnitude;
        current = network.current(coil.first).magnitude;
      } else if (main.isNotEmpty) {
        voltage = network.voltage(main.first.a, main.first.b).magnitude;
      }

      switch (component.kind) {
        case ComponentKind.dcSupply:
        case ComponentKind.acSupply:
          active = component.flag('enabled');
          final source = network.sources
              .where((item) => item.ownerId == component.id)
              .firstOrNull;
          if (source != null) {
            voltage = network
                .voltage(
                  _key(
                      component.id,
                      component.kind == ComponentKind.dcSupply
                          ? 'positive'
                          : 'line'),
                  _key(
                    component.id,
                    component.kind == ComponentKind.dcSupply
                        ? 'negative'
                        : 'neutral',
                  ),
                )
                .magnitude;
            current = network.sourceCurrent(source).magnitude;
            power = voltage * current;
          }
        case ComponentKind.threePhaseSupply:
          active = component.flag('enabled');
          final sources = network.sources
              .where((item) => item.ownerId == component.id)
              .toList();
          current = sources.fold<double>(
            0,
            (value, item) =>
                math.max(value, network.sourceCurrent(item).magnitude),
          );
          voltage = network
              .voltage(_key(component.id, 'l1'), _key(component.id, 'l2'))
              .magnitude;
          power = sources.fold<double>(0, (value, item) {
            final v = network.voltage(item.a, item.b);
            final i = network.sourceCurrent(item);
            return value + v.real * i.real + v.imaginary * i.imaginary;
          });
        case ComponentKind.differentialBreaker:
        case ComponentKind.rccb2P:
          var sum = ComplexNumber.zero;
          for (final branch in main) {
            sum = sum + network.current(branch);
          }
          residualCurrent = sum.magnitude;
        case ComponentKind.contactor:
        case ComponentKind.contactor4P:
        case ComponentKind.auxiliaryRelay:
        case ComponentKind.phaseRelay:
          active = state.energized;
          if (component.kind == ComponentKind.phaseRelay) {
            final l1 = network.nodeVoltage(_key(component.id, 'l1'));
            final l2 = network.nodeVoltage(_key(component.id, 'l2'));
            final l3 = network.nodeVoltage(_key(component.id, 'l3'));
            voltage = ((l1 - l2).magnitude +
                    (l2 - l3).magnitude +
                    (l3 - l1).magnitude) /
                3;
          }
        case ComponentKind.impulseRelay:
          active = state.latched;
        case ComponentKind.timer:
          final delay = math.max(0.05, component.number('delaySeconds'));
          timerRemaining = math.max(0, delay - state.timerElapsed);
          active = state.energized && state.timerElapsed >= delay;
        case ComponentKind.timerOffDelay:
        case ComponentKind.staircaseTimer:
          final delay = math.max(0.05, component.number('delaySeconds'));
          timerRemaining = !state.energized && state.timerOutput
              ? math.max(0, delay - state.timerElapsed)
              : 0;
          active = state.timerOutput;
        case ComponentKind.indicator:
        case ComponentKind.ledLamp:
        case ComponentKind.bell:
        case ComponentKind.buzzer:
          final rated = math.max(0.1, component.number('ratedVoltage'));
          active = voltage >= rated * 0.5 && voltage <= rated * 1.5;
        case ComponentKind.motor3Phase:
        case ComponentKind.pump:
        case ComponentKind.heater3Phase:
          final u = network.nodeVoltage(_key(component.id, 'u'));
          final v = network.nodeVoltage(_key(component.id, 'v'));
          final w = network.nodeVoltage(_key(component.id, 'w'));
          final neutral = network.nodeVoltage('${component.id}::__neutral');
          final up = (u - neutral).magnitude;
          final vp = (v - neutral).magnitude;
          final wp = (w - neutral).magnitude;
          final average = (up + vp + wp) / 3;
          final maximum = math.max(up, math.max(vp, wp));
          final minimum = math.min(up, math.min(vp, wp));
          final expected = component.number('nominalVoltage') / math.sqrt(3);
          final balanced = average > 0 && (maximum - minimum) / average < 0.25;
          active = balanced && minimum >= expected * 0.55;
          voltage =
              ((u - v).magnitude + (v - w).magnitude + (w - u).magnitude) / 3;
          current = maximumCurrent(motor);
          if (active && up > 1 && vp > 1) {
            final phaseDifference =
                _wrapAngle((v - neutral).angle - (u - neutral).angle);
            direction = math.sin(phaseDifference) < 0 ? 1 : -1;
          }
        case ComponentKind.motor6Terminal:
          final windingVoltages = motor
              .map((branch) => network.voltage(branch.a, branch.b).magnitude)
              .toList(growable: false);
          final u = network.nodeVoltage(_key(component.id, 'u1'));
          final v = network.nodeVoltage(_key(component.id, 'v1'));
          final w = network.nodeVoltage(_key(component.id, 'w1'));
          voltage =
              ((u - v).magnitude + (v - w).magnitude + (w - u).magnitude) / 3;
          if (windingVoltages.length == 3) {
            final average = windingVoltages.fold<double>(
                  0,
                  (sum, value) => sum + value,
                ) /
                3;
            final maximum = windingVoltages.fold<double>(
              0,
              (value, item) => math.max(value, item),
            );
            final minimum = windingVoltages.fold<double>(
              double.infinity,
              (value, item) => math.min(value, item),
            );
            final nominal = math.max(1, component.number('nominalVoltage'));
            final balanced =
                average > 0 && (maximum - minimum) / average < 0.25;
            active = balanced &&
                minimum >= nominal * 0.45 &&
                average <= nominal * 1.35;
            connectionMode = !active
                ? 'open'
                : average < nominal * 0.75
                    ? 'star'
                    : 'delta';
            final windingCurrent = maximumCurrent(motor);
            current =
                windingCurrent * (connectionMode == 'delta' ? math.sqrt(3) : 1);
            if (active && u.magnitude > 1 && v.magnitude > 1) {
              final phaseDifference = _wrapAngle(v.angle - u.angle);
              direction = math.sin(phaseDifference) < 0 ? 1 : -1;
            }
          }
        case ComponentKind.motor1Phase:
        case ComponentKind.fan:
        case ComponentKind.solenoidValve:
          if (motor.isNotEmpty) {
            voltage = network.voltage(motor.first.a, motor.first.b).magnitude;
            current = maximumCurrent(motor);
            final nominal = math.max(1, component.number('nominalVoltage'));
            active = voltage >= nominal * 0.55 && voltage <= nominal * 1.5;
          }
        case ComponentKind.transformer:
        case ComponentKind.bellTransformer:
        case ComponentKind.voltageTransformer:
          final primary =
              branches.where((item) => item.role == 'primary').firstOrNull;
          final secondary =
              branches.where((item) => item.role == 'secondary').firstOrNull;
          if (primary != null && secondary != null) {
            final primaryVoltage = network.voltage(
              _key(component.id, 'primaryLine'),
              _key(component.id, 'primaryNeutral'),
            );
            final secondaryVoltage = network.voltage(
              _key(component.id, 'secondaryLine'),
              _key(component.id, 'secondaryNeutral'),
            );
            final primaryCurrent = network.current(primary);
            voltage = secondaryVoltage.magnitude;
            current = network.current(secondary).magnitude;
            power = primaryVoltage.real * primaryCurrent.real +
                primaryVoltage.imaginary * primaryCurrent.imaginary;
            active = primaryVoltage.magnitude > 1 && voltage > 1;
          }
        case ComponentKind.currentTransformer:
          final primary =
              branches.where((item) => item.role == 'primary').firstOrNull;
          final secondary = branches
              .where((item) => item.role == 'secondaryWinding')
              .firstOrNull;
          if (primary != null && secondary != null) {
            current = network.current(primary).magnitude;
            secondaryCurrent = network.current(secondary).magnitude;
            voltage = network
                .voltage(
                  _key(component.id, 's1'),
                  _key(component.id, 's2'),
                )
                .magnitude;
            final ratio = math.max(0.000001, component.number('turnsRatio'));
            active = current > 0.000001;
            validMeasurement =
                voltage <= component.number('maxSecondaryVoltage') * 1.1 &&
                    (!active || secondaryCurrent >= current * ratio * 0.5);
          }
        case ComponentKind.voltmeter:
        case ComponentKind.frequencyMeter:
          if (measurement.isNotEmpty) {
            voltage = network
                .voltage(measurement.first.a, measurement.first.b)
                .magnitude;
            current = network.current(measurement.first).magnitude;
            validMeasurement = current < 0.1 &&
                voltage <= component.number('maxVoltage') * 1.1 &&
                network.validVoltmeterConnection(
                  measurement.first.a,
                  measurement.first.b,
                  component.id,
                );
            if (component.kind == ComponentKind.frequencyMeter &&
                validMeasurement &&
                voltage > 1) {
              frequency = network._supplyFrequency();
            }
          }
        case ComponentKind.ammeter:
          if (measurement.isNotEmpty) {
            voltage = network
                .voltage(measurement.first.a, measurement.first.b)
                .magnitude;
            current = network.current(measurement.first).magnitude;
            validMeasurement = current <=
                    component.number('maxCurrent') * 1.1 &&
                voltage < math.max(1.0, component.number('maxCurrent') * 0.02);
          }
        case ComponentKind.digitalCounter:
        case ComponentKind.wattmeter:
          final voltageBranch = branches
              .where((item) => item.role == 'voltageMeasurement')
              .firstOrNull;
          final currentBranch = branches
              .where((item) => item.role == 'currentMeasurement')
              .firstOrNull;
          if (voltageBranch != null && currentBranch != null) {
            final measuredVoltage = network.voltage(
              voltageBranch.a,
              voltageBranch.b,
            );
            final measuredCurrent = network.current(currentBranch);
            voltage = measuredVoltage.magnitude;
            current = measuredCurrent.magnitude;
            power = measuredVoltage.real * measuredCurrent.real +
                measuredVoltage.imaginary * measuredCurrent.imaginary;
            validMeasurement =
                voltage <= component.number('maxVoltage') * 1.1 &&
                    current <= component.number('maxCurrent') * 1.1 &&
                    network.current(voltageBranch).magnitude < 0.1 &&
                    network.validVoltmeterConnection(
                      voltageBranch.a,
                      voltageBranch.b,
                      component.id,
                    );
            active = validMeasurement && current > 0.000001;
          }
        case ComponentKind.pushButtonNO:
        case ComponentKind.pushButtonNC:
          active = component.flag('pressed');
        case ComponentKind.emergencyStop:
          active = !component.flag('closed');
        case ComponentKind.selectorSwitch:
        case ComponentKind.lightSwitch:
          active = component.flag('closed');
        case ComponentKind.intermediateSwitch:
          active = component.flag('crossed');
        case ComponentKind.thermostat:
          active = state.latched;
        case ComponentKind.rotarySwitch:
          active = component.number('position').round() != 0;
        case ComponentKind.twoWaySwitch:
          active = component.number('position').round() == 2;
        case ComponentKind.sensor:
        case ComponentKind.limitSwitch:
        case ComponentKind.motionSensor:
        case ComponentKind.lightSensor:
        case ComponentKind.floatSwitch:
        case ComponentKind.pressureSwitch:
        case ComponentKind.flowSwitch:
        case ComponentKind.proximitySensor:
        case ComponentKind.capacitiveSensor:
        case ComponentKind.photoelectricSensor:
          active = component.flag('active');
        default:
          break;
      }
      if (!power.isFinite) power = 0;
      result[component.id] = DeviceReading(
        componentId: component.id,
        voltage: voltage,
        current: current,
        activePower: power.abs() < 1e-8 ? 0 : power,
        energized: state.energized,
        active: active,
        tripped: state.tripped,
        blown: state.blown,
        direction: direction,
        timerRemaining: timerRemaining,
        measurementValid: validMeasurement,
        residualCurrent: residualCurrent,
        energyKwh: state.energyKwh,
        secondaryCurrent: secondaryCurrent,
        frequency: frequency,
        connectionMode: connectionMode,
      );
    }
    return result;
  }

  List<SimulationDiagnostic> _diagnose(
    ElectricalProject project,
    _Network network,
    Map<String, DeviceReading> readings,
  ) {
    final diagnostics = <SimulationDiagnostic>[];
    if (!network.converged) {
      diagnostics.add(
        const SimulationDiagnostic(
          code: 'not_converged',
          severity: DiagnosticSeverity.error,
          messageAr:
              'لم تستقر حالة الملفات؛ راجع التعشيق أو نقاط NC المتعارضة.',
        ),
      );
    }
    for (final component in project.components) {
      if (_interlockGroup(component).isNotEmpty &&
          !_hasValidInterlockPair(component, project.components)) {
        diagnostics.add(
          SimulationDiagnostic(
            code: 'interlock_config',
            componentId: component.id,
            severity: DiagnosticSeverity.error,
            messageAr:
                'مجموعة التعشيق في ${component.label} غير مكتملة: يلزم جهازان فقط بدورَي star وdelta. أبقيت نقاط القدرة مفتوحة.',
          ),
        );
      }
    }
    for (final star in project.components) {
      if (_interlockRole(star) != 'star' ||
          !_hasValidInterlockPair(star, project.components) ||
          !runtime[star.id].energized) {
        continue;
      }
      final group = _interlockGroup(star);
      if (group.isEmpty) continue;
      for (final delta in project.components) {
        if (delta.id == star.id ||
            _interlockGroup(delta) != group ||
            _interlockRole(delta) != 'delta' ||
            !runtime[delta.id].energized) {
          continue;
        }
        diagnostics.add(
          SimulationDiagnostic(
            code: 'interlock_conflict',
            componentId: star.id,
            severity: DiagnosticSeverity.error,
            messageAr:
                'تعارض التشابك: ملفا ${star.label} (Étoile) و${delta.label} (Triangle) مُغذّيان معاً. فُصلت نقاط القدرة ميكانيكياً لمنع القصر؛ راجع NC 21/22 والمؤقت.',
          ),
        );
      }
    }
    final supplies = project.components.where(
      (item) =>
          item.kind == ComponentKind.dcSupply ||
          item.kind == ComponentKind.acSupply ||
          item.kind == ComponentKind.threePhaseSupply,
    );
    if (supplies.isEmpty) {
      diagnostics.add(
        const SimulationDiagnostic(
          code: 'no_supply',
          severity: DiagnosticSeverity.warning,
          messageAr:
              'لا يوجد مصدر تغذية. فعّل مصدراً من منطقة Alimentation أعلى اللوحة.',
        ),
      );
    } else if (!supplies.any((item) => item.flag('enabled'))) {
      diagnostics.add(
        const SimulationDiagnostic(
          code: 'supply_disabled',
          severity: DiagnosticSeverity.warning,
          messageAr:
              'مصادر التغذية غير مفعلة. اختر 3~ أو 1~ أو DC من منطقة Alimentation.',
        ),
      );
    }
    if (project.wires.isEmpty && project.components.isNotEmpty) {
      diagnostics.add(
        const SimulationDiagnostic(
          code: 'no_wires',
          severity: DiagnosticSeverity.info,
          messageAr: 'الأجهزة غير موصولة. اضغط على طرف ثم اختر طرف النهاية.',
        ),
      );
    }
    for (final component in project.components) {
      final fault = component.text('fault');
      if (fault.isNotEmpty && fault != 'none') {
        diagnostics.add(
          SimulationDiagnostic(
            code: 'injected_$fault',
            componentId: component.id,
            severity: DiagnosticSeverity.warning,
            messageAr: 'عطل افتراضي $fault مفعّل على ${component.label}.',
          ),
        );
      }
      final reading = readings[component.id]!;
      if (reading.tripped) {
        diagnostics.add(
          SimulationDiagnostic(
            code: 'protection_open',
            componentId: component.id,
            severity: DiagnosticSeverity.warning,
            messageAr:
                '${component.label} في وضع الفصل/التعطيل. تحقق من الحمل ثم أعد الضبط.',
          ),
        );
      }
      if (reading.blown) {
        diagnostics.add(
          SimulationDiagnostic(
            code: 'fuse_open',
            componentId: component.id,
            severity: DiagnosticSeverity.warning,
            messageAr: '${component.label} منصهر ويحتاج إلى استبدال افتراضي.',
          ),
        );
      }
      if (_hasCoil(component.kind) && reading.energized) {
        final rated = _coilRatedVoltage(component);
        if (reading.voltage > rated * 1.25) {
          diagnostics.add(
            SimulationDiagnostic(
              code: 'coil_overvoltage',
              componentId: component.id,
              severity: DiagnosticSeverity.error,
              messageAr:
                  'جهد ملف ${component.label} أعلى من ${rated.toStringAsFixed(0)}V.',
            ),
          );
        }
      }
      if (component.kind == ComponentKind.indicator ||
          component.kind == ComponentKind.ledLamp ||
          component.kind == ComponentKind.bell ||
          component.kind == ComponentKind.buzzer) {
        final rated = component.number('ratedVoltage');
        if (reading.voltage > rated * 1.5) {
          diagnostics.add(
            SimulationDiagnostic(
              code: 'lamp_overvoltage',
              componentId: component.id,
              severity: DiagnosticSeverity.error,
              messageAr:
                  '${component.label}: الجهد أعلى بكثير من التصنيف؛ المصباح معطّل افتراضياً.',
            ),
          );
        }
      }
      final isRotatingMachine = component.kind == ComponentKind.motor3Phase ||
          component.kind == ComponentKind.motor6Terminal ||
          component.kind == ComponentKind.pump;
      if (isRotatingMachine && !reading.active) {
        final hasVoltage = reading.voltage > 10;
        if (hasVoltage) {
          diagnostics.add(
            SimulationDiagnostic(
              code: 'motor_phase_problem',
              componentId: component.id,
              severity: DiagnosticSeverity.error,
              messageAr:
                  'المحرك لا يعمل: تحقق من فقدان طور أو عدم توازن الجهد أو التوصيلات.',
            ),
          );
        }
      } else if (isRotatingMachine && reading.active) {
        final mode = switch (reading.connectionMode) {
          'star' => ' Étoile',
          'delta' => ' Triangle',
          _ => '',
        };
        diagnostics.add(
          SimulationDiagnostic(
            code: 'motor_running',
            componentId: component.id,
            severity: DiagnosticSeverity.success,
            messageAr:
                'المحرك يعمل$mode؛ الاتجاه ${reading.direction >= 0 ? 'أمامي' : 'عكسي'} والتيار ${reading.current.toStringAsFixed(2)}A.',
          ),
        );
      }
      if (component.kind == ComponentKind.phaseRelay) {
        if (!reading.energized && reading.voltage > 10) {
          diagnostics.add(
            SimulationDiagnostic(
              code: 'phase_relay_fault',
              componentId: component.id,
              severity: DiagnosticSeverity.error,
              messageAr:
                  'Relais de phases: طور مفقود أو تسلسل الأطوار معكوس؛ افحص L1/L2/L3.',
            ),
          );
        } else if (reading.energized) {
          diagnostics.add(
            SimulationDiagnostic(
              code: 'phase_sequence_ok',
              componentId: component.id,
              severity: DiagnosticSeverity.success,
              messageAr: 'جهود الأطوار وتسلسلها صحيحة في نطاق النموذج.',
            ),
          );
        }
      }
      if (!reading.measurementValid) {
        final isVolt = component.kind == ComponentKind.voltmeter ||
            component.kind == ComponentKind.frequencyMeter;
        diagnostics.add(
          SimulationDiagnostic(
            code: 'invalid_measurement',
            componentId: component.id,
            severity: DiagnosticSeverity.error,
            messageAr: component.kind == ComponentKind.currentTransformer
                ? 'CT: جهد الثانوي تجاوز الحد أو العبء غير صالح؛ راجع S1/S2 وقيمة Burden.'
                : component.kind == ComponentKind.digitalCounter ||
                        component.kind == ComponentKind.wattmeter
                    ? 'Mesure: راجع توصيل الجهد على التوازي والتيار على التسلسل ومدى القياس.'
                    : isVolt
                        ? 'Voltmètre في وضع قياس غير صالح؛ وصله على التوازي مع نقطتين من الدائرة.'
                        : 'Ampèremètre في وضع غير صالح أو تجاوز المدى؛ وصله على التسلسل وليس على التوازي.',
          ),
        );
      }
    }
    if (diagnostics.isEmpty) {
      diagnostics.add(
        const SimulationDiagnostic(
          code: 'solved',
          severity: DiagnosticSeverity.success,
          messageAr: 'تم حل الدائرة دون أخطاء كهربائية في النطاق المدعوم.',
        ),
      );
    }
    return diagnostics;
  }

  SimulationResult _failedResult(
    ElectricalProject project,
    _Network network,
  ) {
    final readings = <String, DeviceReading>{
      for (final component in project.components)
        component.id: DeviceReading(
          componentId: component.id,
          tripped: runtime[component.id].tripped,
          blown: runtime[component.id].blown,
          energized: runtime[component.id].energized,
        ),
    };
    return SimulationResult(
      time: runtime.time,
      success: false,
      devices: readings,
      wireCurrents: <String, double>{},
      diagnostics: <SimulationDiagnostic>[
        SimulationDiagnostic(
          code: network.singular ? 'singular_network' : 'solver_failure',
          severity: DiagnosticSeverity.error,
          messageAr:
              'تعذر حل الشبكة: قد توجد مصادر جهد متعارضة على التوازي أو عقدة غير محددة. راجع التوصيلات.',
        ),
      ],
    );
  }

  Map<String, double> _wireCurrents(_Network network) => <String, double>{
        for (final branch in network.wireBranches)
          branch.ownerId: network.current(branch).magnitude,
      };

  bool _phaseRelayHealthy(
    _Network network,
    CircuitComponent component,
  ) {
    final l1 = network.nodeVoltage(_key(component.id, 'l1'));
    final l2 = network.nodeVoltage(_key(component.id, 'l2'));
    final l3 = network.nodeVoltage(_key(component.id, 'l3'));
    final v12 = l1 - l2;
    final v23 = l2 - l3;
    final v31 = l3 - l1;
    final minimum = component.number('minVoltage');
    final present = v12.magnitude >= minimum &&
        v23.magnitude >= minimum &&
        v31.magnitude >= minimum;
    if (!present) return false;
    final sequence = _wrapAngle(v23.angle - v12.angle);
    return math.sin(sequence) < 0;
  }

  double _coilVoltage(_Network network, CircuitComponent component) {
    final branches =
        network.branches[component.id]?.where((item) => item.role == 'coil');
    if (branches == null || branches.isEmpty) return 0;
    return network.voltage(branches.first.a, branches.first.b).magnitude;
  }

  static bool _hasCoil(ComponentKind kind) =>
      kind == ComponentKind.contactor ||
      kind == ComponentKind.contactor4P ||
      kind == ComponentKind.auxiliaryRelay ||
      kind == ComponentKind.impulseRelay ||
      kind == ComponentKind.staircaseTimer ||
      kind == ComponentKind.timer ||
      kind == ComponentKind.timerOffDelay;

  static double _coilRatedVoltage(CircuitComponent component) =>
      component.number('coilVoltage');

  static double _number(
    CircuitComponent component,
    String key,
    double fallback,
  ) {
    final value = component.properties[key];
    return value is num ? value.toDouble() : fallback;
  }

  static double _wrapAngle(double angle) {
    var value = angle;
    while (value > math.pi) {
      value -= 2 * math.pi;
    }
    while (value < -math.pi) {
      value += 2 * math.pi;
    }
    return value;
  }

  static String _key(String componentId, String terminalId) =>
      '$componentId::$terminalId';
}

// Interlock assignment belongs to each placed instance, never to ComponentKind.
// Two contactors of the same model therefore cannot inherit a false conflict.
String _interlockGroup(CircuitComponent component) =>
    component.text('interlockGroup').trim();

String _interlockRole(CircuitComponent component) =>
    component.text('interlockRole').trim();

bool _hasValidInterlockPair(
  CircuitComponent component,
  List<CircuitComponent> components,
) {
  final group = _interlockGroup(component);
  final role = _interlockRole(component);
  if (group.isEmpty || !const <String>{'star', 'delta'}.contains(role)) {
    return false;
  }
  final members = components
      .where((item) => _interlockGroup(item) == group)
      .toList(growable: false);
  return members.length == 2 &&
      members.every(
        (item) =>
            item.kind == ComponentKind.contactor ||
            item.kind == ComponentKind.contactor4P,
      ) &&
      members.map(_interlockRole).toSet().containsAll(
        const <String>{'star', 'delta'},
      );
}

class _Branch {
  const _Branch(this.ownerId, this.a, this.b, this.impedance, this.role);

  final String ownerId;
  final String a;
  final String b;
  final ComplexNumber impedance;
  final String role;
}

class _VoltageBranch {
  const _VoltageBranch(this.ownerId, this.a, this.b, this.index);

  final String ownerId;
  final String a;
  final String b;
  final int index;
}

class _Network {
  _Network._(
    this.project,
    this.runtime,
    this.ground,
    this.nodes,
    this.matrix,
    this.rhs,
  );

  final ElectricalProject project;
  final SimulationRuntime runtime;
  final String ground;
  final Map<String, int> nodes;
  final List<List<ComplexNumber>> matrix;
  final List<ComplexNumber> rhs;
  final Map<String, List<_Branch>> branches = <String, List<_Branch>>{};
  final List<_Branch> wireBranches = <_Branch>[];
  final List<_VoltageBranch> sources = <_VoltageBranch>[];
  final Map<String, ComplexNumber> _voltages = <String, ComplexNumber>{};
  List<ComplexNumber> _solution = <ComplexNumber>[];
  bool solved = false;
  bool singular = false;
  bool converged = false;
  final List<List<_AdjacencyEdge>> _adjacency = <List<_AdjacencyEdge>>[];
  final Map<String, int> _adjacencyIndex = <String, int>{};

  factory _Network.build(
    ElectricalProject project,
    SimulationRuntime runtime,
  ) {
    final allNodes = <String>{};
    for (final component in project.components) {
      for (final terminal
          in ComponentCatalog.specOf(component.kind).terminals) {
        allNodes.add('${component.id}::${terminal.id}');
      }
      if (component.kind == ComponentKind.motor3Phase ||
          component.kind == ComponentKind.pump ||
          component.kind == ComponentKind.heater3Phase) {
        allNodes.add('${component.id}::__neutral');
      }
      if (component.kind == ComponentKind.transformer ||
          component.kind == ComponentKind.bellTransformer ||
          component.kind == ComponentKind.voltageTransformer) {
        allNodes.add('${component.id}::__primary');
        allNodes.add('${component.id}::__secondary');
      }
      if (component.kind == ComponentKind.currentTransformer) {
        allNodes.add('${component.id}::__ct_primary');
        allNodes.add('${component.id}::__ct_secondary');
      }
      if (component.kind == ComponentKind.dcSupply ||
          component.kind == ComponentKind.acSupply) {
        allNodes.add('${component.id}::__source');
      } else if (component.kind == ComponentKind.threePhaseSupply) {
        for (final phase in const <String>['l1', 'l2', 'l3']) {
          allNodes.add('${component.id}::__source_$phase');
        }
      }
    }
    if (allNodes.isEmpty) allNodes.add('__empty_ground');
    String ground = allNodes.first;
    for (final component in project.components) {
      if (component.kind == ComponentKind.dcSupply) {
        ground = '${component.id}::negative';
        break;
      } else if (component.kind == ComponentKind.acSupply ||
          component.kind == ComponentKind.threePhaseSupply) {
        ground = '${component.id}::neutral';
        break;
      }
    }
    final orderedNodes = allNodes.toList()..sort();
    final indices = <String, int>{};
    var index = 0;
    for (final node in orderedNodes) {
      if (node != ground) indices[node] = index++;
    }
    final matrix = List<List<ComplexNumber>>.generate(
      index,
      (_) => List<ComplexNumber>.filled(
        index,
        ComplexNumber.zero,
        growable: true,
      ),
    );
    final rhs = List<ComplexNumber>.filled(
      index,
      ComplexNumber.zero,
      growable: true,
    );
    final network = _Network._(project, runtime, ground, indices, matrix, rhs);
    for (final node in orderedNodes) {
      if (node != ground) network._addLeakage(node);
    }
    network._stampComponents();
    network._stampWires();
    network._buildAdjacency();
    return network;
  }

  bool _powerContactsClosed(CircuitComponent component) {
    final state = runtime[component.id];
    if (!state.energized) return false;
    final group = _interlockGroup(component);
    final role = _interlockRole(component);
    if (group.isEmpty) return true;
    if (!_hasValidInterlockPair(component, project.components)) return false;
    for (final peer in project.components) {
      if (peer.id == component.id || _interlockGroup(peer) != group) {
        continue;
      }
      final peerRole = _interlockRole(peer);
      final opposite = (role == 'star' && peerRole == 'delta') ||
          (role == 'delta' && peerRole == 'star');
      if (opposite && runtime[peer.id].energized) return false;
    }
    return true;
  }

  void _stampComponents() {
    for (final component in project.components) {
      final fault = component.text('fault');
      final openFault = fault == 'open' || fault == 'coilOpen';
      final shortFault = fault == 'short';
      final state = runtime[component.id];
      String key(String terminal) => '${component.id}::$terminal';
      void resistor(
        String a,
        String b,
        double resistance,
        String role,
      ) {
        final safe = math.max(0.0001, resistance);
        final branch = _Branch(
          component.id,
          key(a),
          key(b),
          ComplexNumber(safe),
          role,
        );
        _addBranch(branch);
      }

      void contact(
        String a,
        String b,
        bool closed, {
        String role = 'main',
      }) {
        if (openFault) return;
        if (closed || shortFault) {
          resistor(a, b, shortFault ? 0.001 : 0.01, role);
        }
      }

      void coil() {
        if (openFault) return;
        final resistance = shortFault
            ? 0.001
            : math.max(0.1, component.number('coilResistance'));
        resistor('a1', 'a2', resistance, 'coil');
      }

      switch (component.kind) {
        case ComponentKind.dcSupply:
          if (component.flag('enabled')) {
            final internal = '${component.id}::__source';
            _addBranch(
              _Branch(
                component.id,
                key('positive'),
                internal,
                ComplexNumber(
                  math.max(0.001, component.number('internalResistance')),
                ),
                'sourceResistance',
              ),
            );
            _addVoltageSource(
              component.id,
              internal,
              key('negative'),
              ComplexNumber(component.number('voltage')),
            );
          }
        case ComponentKind.acSupply:
          if (component.flag('enabled')) {
            final internal = '${component.id}::__source';
            _addBranch(
              _Branch(
                component.id,
                key('line'),
                internal,
                ComplexNumber(
                  math.max(0.001, component.number('internalResistance')),
                ),
                'sourceResistance',
              ),
            );
            _addVoltageSource(
              component.id,
              internal,
              key('neutral'),
              ComplexNumber(component.number('voltage')),
            );
          }
        case ComponentKind.threePhaseSupply:
          if (component.flag('enabled')) {
            final phaseVoltage = component.number('lineVoltage') / math.sqrt(3);
            final phases = <String, double>{
              'l1': 0,
              'l2': -2 * math.pi / 3,
              'l3': 2 * math.pi / 3,
            };
            phases.forEach((phase, angle) {
              final internal = '${component.id}::__source_$phase';
              _addBranch(
                _Branch(
                  component.id,
                  key(phase),
                  internal,
                  ComplexNumber(
                    math.max(0.001, component.number('internalResistance')),
                  ),
                  'sourceResistance',
                ),
              );
              _addVoltageSource(
                component.id,
                internal,
                key('neutral'),
                ComplexNumber.polar(phaseVoltage, angle),
              );
            });
          }
          _addBranch(
            _Branch(
              component.id,
              key('neutral'),
              key('pe'),
              const ComplexNumber(0.01),
              'earthBond',
            ),
          );
        case ComponentKind.circuitBreaker:
          contact('line', 'load', component.flag('closed') && !state.tripped);
        case ComponentKind.mcb2P:
          final closed2P = component.flag('closed') && !state.tripped;
          contact('lineIn', 'lineOut', closed2P);
          contact('neutralIn', 'neutralOut', closed2P);
        case ComponentKind.mcb3P:
        case ComponentKind.mcb4P:
        case ComponentKind.mccb3P:
        case ComponentKind.isolator3P:
          final closedMulti = component.flag('closed') &&
              (component.kind == ComponentKind.isolator3P || !state.tripped);
          contact('l1', 't1', closedMulti);
          contact('l2', 't2', closedMulti);
          contact('l3', 't3', closedMulti);
          if (component.kind == ComponentKind.mcb4P) {
            contact('neutralIn', 'neutralOut', closedMulti);
          }
        case ComponentKind.differentialBreaker:
        case ComponentKind.rccb2P:
          final closed = component.flag('closed') && !state.tripped;
          contact('lineIn', 'lineOut', closed);
          contact('neutralIn', 'neutralOut', closed);
        case ComponentKind.motorBreaker:
          final closed = component.flag('closed') && !state.tripped;
          contact('l1', 't1', closed);
          contact('l2', 't2', closed);
          contact('l3', 't3', closed);
          contact('nc95', 'nc96', closed, role: 'auxiliary');
        case ComponentKind.contactor:
        case ComponentKind.contactor4P:
          final powerClosed = _powerContactsClosed(component);
          contact('l1', 't1', powerClosed);
          contact('l2', 't2', powerClosed);
          contact('l3', 't3', powerClosed);
          if (component.kind == ComponentKind.contactor4P) {
            contact('neutralIn', 'neutralOut', powerClosed);
          }
          contact('aux13', 'aux14', state.energized, role: 'auxiliary');
          contact('aux21', 'aux22', !state.energized, role: 'auxiliary');
          coil();
        case ComponentKind.thermalRelay:
          contact('l1', 't1', !state.tripped);
          contact('l2', 't2', !state.tripped);
          contact('l3', 't3', !state.tripped);
          contact('nc95', 'nc96', !state.tripped, role: 'auxiliary');
        case ComponentKind.auxiliaryRelay:
          contact('common', 'no', state.energized, role: 'auxiliary');
          contact('common', 'nc', !state.energized, role: 'auxiliary');
          coil();
        case ComponentKind.impulseRelay:
          contact('common', 'no', state.latched, role: 'auxiliary');
          contact('common', 'nc', !state.latched, role: 'auxiliary');
          coil();
        case ComponentKind.phaseRelay:
          contact('common', 'no', state.energized, role: 'auxiliary');
          contact('common', 'nc', !state.energized, role: 'auxiliary');
        case ComponentKind.pushButtonNO:
          contact('input', 'output', component.flag('pressed'),
              role: 'auxiliary');
        case ComponentKind.pushButtonNC:
          contact('input', 'output', !component.flag('pressed'),
              role: 'auxiliary');
        case ComponentKind.emergencyStop:
          contact('input', 'output', component.flag('closed'),
              role: 'auxiliary');
        case ComponentKind.selectorSwitch:
        case ComponentKind.lightSwitch:
          contact('input', 'output', component.flag('closed'),
              role: 'auxiliary');
        case ComponentKind.thermostat:
          contact('input', 'output', state.latched, role: 'auxiliary');
        case ComponentKind.twoWaySwitch:
          final twoWayPosition = component.number('position').round();
          contact('common', 'out1', twoWayPosition == 1, role: 'auxiliary');
          contact('common', 'out2', twoWayPosition == 2, role: 'auxiliary');
        case ComponentKind.intermediateSwitch:
          final crossed = component.flag('crossed');
          contact('in1', crossed ? 'out2' : 'out1', true, role: 'auxiliary');
          contact('in2', crossed ? 'out1' : 'out2', true, role: 'auxiliary');
        case ComponentKind.rotarySwitch:
          final position = component.number('position').round();
          contact('common', 'out1', position == 1, role: 'auxiliary');
          contact('common', 'out2', position == 2, role: 'auxiliary');
        case ComponentKind.sensor:
        case ComponentKind.limitSwitch:
        case ComponentKind.motionSensor:
        case ComponentKind.lightSensor:
        case ComponentKind.floatSwitch:
        case ComponentKind.pressureSwitch:
        case ComponentKind.flowSwitch:
          contact('input', 'output', component.flag('active'),
              role: 'auxiliary');
        case ComponentKind.proximitySensor:
        case ComponentKind.capacitiveSensor:
        case ComponentKind.photoelectricSensor:
          if (!openFault) {
            final rated = math.max(1, component.number('ratedVoltage'));
            final watts = math.max(0.01, component.number('powerWatts'));
            resistor('positive', 'negative', rated * rated / watts, 'main');
            resistor(
              'output',
              component.flag('active') ? 'positive' : 'negative',
              shortFault ? 0.001 : 10,
              'auxiliary',
            );
          }
        case ComponentKind.timer:
          final onDelayClosed = state.energized &&
              state.timerElapsed >=
                  math.max(0.05, component.number('delaySeconds'));
          contact('t15', 't18', onDelayClosed, role: 'auxiliary');
          contact('t15', 't16', !onDelayClosed, role: 'auxiliary');
          coil();
        case ComponentKind.timerOffDelay:
        case ComponentKind.staircaseTimer:
          contact('t15', 't18', state.timerOutput, role: 'auxiliary');
          contact('t15', 't16', !state.timerOutput, role: 'auxiliary');
          coil();
        case ComponentKind.indicator:
        case ComponentKind.bell:
        case ComponentKind.buzzer:
          if (!openFault) {
            final rated = math.max(0.1, component.number('ratedVoltage'));
            final watts = math.max(0.01, component.number('powerWatts'));
            resistor(
                'x1', 'x2', shortFault ? 0.001 : rated * rated / watts, 'main');
          }
        case ComponentKind.ledLamp:
          if (!openFault) {
            final rated = math.max(0.1, component.number('ratedVoltage'));
            final watts = math.max(0.01, component.number('powerWatts'));
            resistor(
              'line',
              'neutral',
              shortFault ? 0.001 : rated * rated / watts,
              'main',
            );
          }
        case ComponentKind.motor3Phase:
        case ComponentKind.pump:
        case ComponentKind.heater3Phase:
          final nominalPhase =
              component.number('nominalVoltage') / math.sqrt(3);
          final nominalCurrent =
              math.max(0.05, component.number('nominalCurrent'));
          final pf = component.number('powerFactor').clamp(0.2, 1.0).toDouble();
          final impedanceMagnitude = nominalPhase / nominalCurrent;
          final resistance = impedanceMagnitude * pf;
          final frequency = _supplyFrequency();
          final reactance = impedanceMagnitude * math.sqrt(1 - pf * pf);
          final impedance = frequency == 0
              ? ComplexNumber(resistance)
              : ComplexNumber(resistance, reactance);
          final neutral = '${component.id}::__neutral';
          for (final phase in const <String>['u', 'v', 'w']) {
            if (openFault && phase == 'u') continue;
            final branch = _Branch(
              component.id,
              key(phase),
              neutral,
              shortFault && phase == 'u'
                  ? const ComplexNumber(0.001)
                  : impedance,
              'motor',
            );
            _addBranch(branch);
          }
        case ComponentKind.motor6Terminal:
          final nominalWinding =
              math.max(1, component.number('nominalVoltage'));
          final nominalLineCurrent = math.max(
            0.05,
            component.number('nominalCurrent'),
          );
          final pf6 =
              component.number('powerFactor').clamp(0.2, 1.0).toDouble();
          final magnitude6 = math.sqrt(3) * nominalWinding / nominalLineCurrent;
          final resistance6 = magnitude6 * pf6;
          final reactance6 = magnitude6 * math.sqrt(1 - pf6 * pf6);
          final impedance6 = _supplyFrequency() == 0
              ? ComplexNumber(resistance6)
              : ComplexNumber(resistance6, reactance6);
          final windings = <List<String>>[
            <String>['u1', 'u2'],
            <String>['v1', 'v2'],
            <String>['w1', 'w2'],
          ];
          for (final winding in windings) {
            if (openFault && winding.first == 'u1') continue;
            _addBranch(
              _Branch(
                component.id,
                key(winding.first),
                key(winding.last),
                shortFault && winding.first == 'u1'
                    ? const ComplexNumber(0.001)
                    : impedance6,
                'motor',
              ),
            );
          }
        case ComponentKind.motor1Phase:
        case ComponentKind.fan:
        case ComponentKind.solenoidValve:
          if (!openFault) {
            final nominal = math.max(1, component.number('nominalVoltage'));
            final nominalCurrent = math.max(
              0.05,
              component.number('nominalCurrent'),
            );
            final pf =
                component.number('powerFactor').clamp(0.2, 1.0).toDouble();
            final magnitude = nominal / nominalCurrent;
            final resistance = magnitude * pf;
            final reactance = magnitude * math.sqrt(1 - pf * pf);
            final impedance = _supplyFrequency() == 0
                ? ComplexNumber(resistance)
                : ComplexNumber(resistance, reactance);
            _addBranch(
              _Branch(
                component.id,
                key('u'),
                key('v'),
                shortFault ? const ComplexNumber(0.001) : impedance,
                'motor',
              ),
            );
          }
        case ComponentKind.transformer:
        case ComponentKind.bellTransformer:
        case ComponentKind.voltageTransformer:
          if (!openFault) {
            resistor(
              'primaryLine',
              '__primary',
              component.number('primaryResistance'),
              'primary',
            );
            resistor(
              'secondaryLine',
              '__secondary',
              component.number('secondaryResistance'),
              'secondary',
            );
            final primaryVoltage = math.max(
              0.001,
              component.number('primaryVoltage'),
            );
            final secondaryVoltage = math.max(
              0.001,
              component.number('secondaryVoltage'),
            );
            _addIdealTransformer(
              key('__primary'),
              key('primaryNeutral'),
              key('__secondary'),
              key('secondaryNeutral'),
              primaryVoltage / secondaryVoltage,
            );
            if (shortFault) {
              resistor('secondaryLine', 'secondaryNeutral', 0.001, 'secondary');
            }
          }
        case ComponentKind.currentTransformer:
          if (!openFault) {
            resistor(
              'p1',
              '__ct_primary',
              component.number('primaryResistance'),
              'primary',
            );
            resistor(
              's1',
              '__ct_secondary',
              component.number('secondaryResistance'),
              'secondaryWinding',
            );
            _addIdealCurrentTransformer(
              key('__ct_primary'),
              key('p2'),
              key('__ct_secondary'),
              key('s2'),
              math.max(0.000001, component.number('turnsRatio')),
            );
            resistor(
              's1',
              's2',
              component.number('burdenResistance'),
              'burden',
            );
            if (shortFault) resistor('p1', 'p2', 0.001, 'main');
          }
        case ComponentKind.socketOutlet:
          contact('lineIn', 'lineOut', true);
          contact('neutralIn', 'neutralOut', true);
          contact('earthIn', 'earthOut', true);
        case ComponentKind.industrialSocket:
          contact('l1In', 'l1Out', true);
          contact('l2In', 'l2Out', true);
          contact('l3In', 'l3Out', true);
          contact('neutralIn', 'neutralOut', true);
          contact('earthIn', 'earthOut', true);
        case ComponentKind.terminalBlock:
          contact('a', 'b', true);
        case ComponentKind.neutralBar:
        case ComponentKind.earthBar:
        case ComponentKind.distributionBlock:
          contact('a', 'b', true);
          contact('a', 'c', true);
          contact('a', 'd', true);
          contact('a', 'return', true);
        case ComponentKind.cableSegment:
          if (!openFault) {
            final resistance = shortFault
                ? 0.001
                : component.number('resistivity') *
                    math.max(0.01, component.number('lengthMeters')) /
                    math.max(0.05, component.number('crossSectionMm2'));
            resistor('a', 'b', resistance, 'main');
          }
        case ComponentKind.voltmeter:
        case ComponentKind.frequencyMeter:
          resistor('positive', 'negative', 1000000, 'measurement');
        case ComponentKind.ammeter:
          resistor('positive', 'negative', 0.01, 'measurement');
        case ComponentKind.digitalCounter:
        case ComponentKind.wattmeter:
          resistor('voltageL', 'voltageN', 1000000, 'voltageMeasurement');
          resistor('currentIn', 'currentOut', 0.01, 'currentMeasurement');
        case ComponentKind.fuse:
          contact('line', 'load', !state.blown);
      }
    }
  }

  void _stampWires() {
    for (final wire in project.wires) {
      final from = '${wire.from.componentId}::${wire.from.terminalId}';
      final to = '${wire.to.componentId}::${wire.to.terminalId}';
      final points = WireRouter.route(project, wire);
      var length = 0.0;
      for (var index = 0; index < points.length - 1; index++) {
        length += points[index].distanceTo(points[index + 1]);
      }
      final metres = math.max(0.1, length / 100);
      final resistance = math.max(
        0.0005,
        0.0175 * metres / math.max(0.05, wire.crossSectionMm2),
      );
      final branch = _Branch(
        wire.id,
        from,
        to,
        ComplexNumber(resistance),
        'wire',
      );
      _addBranch(branch);
      wireBranches.add(branch);
    }
  }

  double _supplyFrequency() {
    var dcEnabled = false;
    for (final component in project.components) {
      if (!component.flag('enabled')) continue;
      if (component.kind == ComponentKind.acSupply ||
          component.kind == ComponentKind.threePhaseSupply) {
        return math.max(0, component.number('frequency'));
      }
      if (component.kind == ComponentKind.dcSupply) dcEnabled = true;
    }
    return dcEnabled ? 0 : 50;
  }

  void _addBranch(_Branch branch) {
    branches.putIfAbsent(branch.ownerId, () => <_Branch>[]).add(branch);
    _stampAdmittance(branch.a, branch.b, ComplexNumber.one / branch.impedance);
  }

  void _stampAdmittance(String a, String b, ComplexNumber y) {
    final ai = nodes[a];
    final bi = nodes[b];
    if (ai != null) matrix[ai][ai] = matrix[ai][ai] + y;
    if (bi != null) matrix[bi][bi] = matrix[bi][bi] + y;
    if (ai != null && bi != null) {
      matrix[ai][bi] = matrix[ai][bi] - y;
      matrix[bi][ai] = matrix[bi][ai] - y;
    }
  }

  void _addLeakage(String node) {
    final index = nodes[node]!;
    matrix[index][index] = matrix[index][index] + const ComplexNumber(1e-9);
  }

  void _addVoltageSource(
    String ownerId,
    String a,
    String b,
    ComplexNumber voltage,
  ) {
    final oldSize = rhs.length;
    for (final row in matrix) {
      row.add(ComplexNumber.zero);
    }
    matrix.add(
      List<ComplexNumber>.filled(
        oldSize + 1,
        ComplexNumber.zero,
        growable: true,
      ),
    );
    rhs.add(voltage);
    final branchIndex = oldSize;
    final ai = nodes[a];
    final bi = nodes[b];
    if (ai != null) {
      matrix[ai][branchIndex] = ComplexNumber.one;
      matrix[branchIndex][ai] = ComplexNumber.one;
    }
    if (bi != null) {
      matrix[bi][branchIndex] = const ComplexNumber(-1);
      matrix[branchIndex][bi] = const ComplexNumber(-1);
    }
    sources.add(_VoltageBranch(ownerId, a, b, branchIndex));
  }

  /// Stamps an ideal transformer with one shared branch current:
  /// Vp = ratio × Vs and Is = -ratio × Ip. Winding resistances are stamped
  /// separately, so secondary loading changes both primary current and losses.
  void _addIdealTransformer(
    String primaryA,
    String primaryB,
    String secondaryA,
    String secondaryB,
    double ratio,
  ) {
    final oldSize = rhs.length;
    for (final row in matrix) {
      row.add(ComplexNumber.zero);
    }
    matrix.add(
      List<ComplexNumber>.filled(
        oldSize + 1,
        ComplexNumber.zero,
        growable: true,
      ),
    );
    rhs.add(ComplexNumber.zero);
    final branchIndex = oldSize;
    void stamp(String node, double kcl, double equation) {
      final index = nodes[node];
      if (index == null) return;
      matrix[index][branchIndex] =
          matrix[index][branchIndex] + ComplexNumber(kcl);
      matrix[branchIndex][index] =
          matrix[branchIndex][index] + ComplexNumber(equation);
    }

    stamp(primaryA, 1, 1);
    stamp(primaryB, -1, -1);
    stamp(secondaryA, -ratio, -ratio);
    stamp(secondaryB, ratio, ratio);
  }

  /// Ideal current transformer: primary voltage is zero and secondary current
  /// is -ratio × primary current. Winding resistance and the secondary burden
  /// are stamped separately, so secondary voltage is solved rather than drawn.
  void _addIdealCurrentTransformer(
    String primaryA,
    String primaryB,
    String secondaryA,
    String secondaryB,
    double ratio,
  ) {
    final oldSize = rhs.length;
    for (final row in matrix) {
      row.add(ComplexNumber.zero);
    }
    matrix.add(
      List<ComplexNumber>.filled(
        oldSize + 1,
        ComplexNumber.zero,
        growable: true,
      ),
    );
    rhs.add(ComplexNumber.zero);
    final branchIndex = oldSize;
    void stamp(String node, double kcl, double equation) {
      final index = nodes[node];
      if (index == null) return;
      matrix[index][branchIndex] =
          matrix[index][branchIndex] + ComplexNumber(kcl);
      matrix[branchIndex][index] =
          matrix[branchIndex][index] + ComplexNumber(equation);
    }

    stamp(primaryA, 1, 1);
    stamp(primaryB, -1, -1);
    stamp(secondaryA, -ratio, 0);
    stamp(secondaryB, ratio, 0);
  }

  bool solve() {
    if (rhs.isEmpty) {
      _solution = <ComplexNumber>[];
      for (final node in <String>{ground, ...nodes.keys}) {
        _voltages[node] = ComplexNumber.zero;
      }
      solved = true;
      return true;
    }
    final solution = LinearSolver.solve(matrix, rhs);
    if (solution == null) {
      singular = true;
      solved = false;
      return false;
    }
    _solution = solution;
    _voltages[ground] = ComplexNumber.zero;
    nodes.forEach((node, index) => _voltages[node] = solution[index]);
    solved = true;
    return true;
  }

  ComplexNumber nodeVoltage(String node) => node == ground
      ? ComplexNumber.zero
      : _voltages[node] ?? ComplexNumber.zero;

  ComplexNumber voltage(String a, String b) => nodeVoltage(a) - nodeVoltage(b);

  ComplexNumber current(_Branch branch) =>
      voltage(branch.a, branch.b) / branch.impedance;

  double realPower(_Branch branch) {
    final v = voltage(branch.a, branch.b);
    final i = current(branch);
    return v.real * i.real + v.imaginary * i.imaginary;
  }

  ComplexNumber sourceCurrent(_VoltageBranch source) =>
      source.index < _solution.length
          ? _solution[source.index]
          : ComplexNumber.zero;

  void _buildAdjacency() {
    final all = <String>{ground, ...nodes.keys}.toList()..sort();
    _adjacencyIndex
      ..clear()
      ..addAll(<String, int>{
        for (var i = 0; i < all.length; i++) all[i]: i,
      });
    _adjacency.clear();
    _adjacency.addAll(
      List<List<_AdjacencyEdge>>.generate(
        all.length,
        (_) => <_AdjacencyEdge>[],
      ),
    );
    void connect(
      String a,
      String b,
      String owner, {
      bool isSource = false,
      bool isLoad = false,
    }) {
      final ai = _adjacencyIndex[a];
      final bi = _adjacencyIndex[b];
      if (ai == null || bi == null) return;
      _adjacency[ai].add(_AdjacencyEdge(b, owner, isSource, isLoad));
      _adjacency[bi].add(_AdjacencyEdge(a, owner, isSource, isLoad));
    }

    for (final ownerBranches in branches.values) {
      for (final branch in ownerBranches) {
        if (branch.impedance.magnitude < 1e7) {
          final isSource = branch.role == 'sourceResistance';
          final isLoad = !isSource &&
              branch.role != 'measurement' &&
              branch.role != 'wire' &&
              branch.impedance.magnitude >= 0.1;
          connect(
            branch.a,
            branch.b,
            branch.ownerId,
            isSource: isSource,
            isLoad: isLoad,
          );
        }
      }
    }
    for (final source in sources) {
      connect(source.a, source.b, source.ownerId, isSource: true);
    }
  }

  /// A voltmeter is valid across a load/network (a source-free alternate
  /// path), or directly across a source (a load-free path). If every alternate
  /// path contains both a source and a load, the meter is in series with them.
  bool validVoltmeterConnection(
    String start,
    String end,
    String excludedOwner,
  ) {
    return _hasAlternatePath(
          start,
          end,
          excludedOwner,
          avoidSources: true,
        ) ||
        _hasAlternatePath(
          start,
          end,
          excludedOwner,
          avoidLoads: true,
        );
  }

  bool _hasAlternatePath(
    String start,
    String end,
    String excludedOwner, {
    bool avoidSources = false,
    bool avoidLoads = false,
  }) {
    final visited = <String>{start};
    final queue = <String>[start];
    while (queue.isNotEmpty) {
      final currentNode = queue.removeAt(0);
      if (currentNode == end) return true;
      final index = _adjacencyIndex[currentNode];
      if (index == null || index >= _adjacency.length) continue;
      for (final edge in _adjacency[index]) {
        if (edge.owner == excludedOwner ||
            (avoidSources && edge.isSource) ||
            (avoidLoads && edge.isLoad) ||
            visited.contains(edge.node)) {
          continue;
        }
        visited.add(edge.node);
        queue.add(edge.node);
      }
    }
    return false;
  }
}

class _AdjacencyEdge {
  const _AdjacencyEdge(this.node, this.owner, this.isSource, this.isLoad);

  final String node;
  final String owner;
  final bool isSource;
  final bool isLoad;
}
