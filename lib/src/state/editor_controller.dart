import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/component.dart';
import '../models/component_catalog.dart';
import '../models/connection_validator.dart';
import '../models/din_geometry.dart';
import '../models/geometry.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/supply_bay.dart';
import '../models/terminal.dart';
import '../models/wire.dart';
import '../simulation/electrical_simulator.dart';
import '../simulation/simulation_result.dart';
import 'id_factory.dart';

enum EditorTool { select, wire }

class EditorController extends ChangeNotifier {
  EditorController({
    required ElectricalProject project,
    Future<void> Function(ElectricalProject project)? onSave,
    ElectricalSimulator? simulator,
    IdFactory? idFactory,
    DateTime Function()? clock,
  })  : _project = project,
        _onSave = onSave,
        simulator = simulator ?? ElectricalSimulator(),
        _ids = idFactory ?? IdFactory(),
        _clock = clock ?? DateTime.now {
    final installed = SupplyBay.install(_project);
    if (!identical(installed, _project)) {
      _project = installed;
      _scheduleSave();
    }
  }

  ElectricalProject _project;
  final Future<void> Function(ElectricalProject project)? _onSave;
  final ElectricalSimulator simulator;
  final IdFactory _ids;
  final DateTime Function() _clock;
  final List<ElectricalProject> _undo = <ElectricalProject>[];
  final List<ElectricalProject> _redo = <ElectricalProject>[];
  Timer? _saveTimer;
  Timer? _simulationTimer;
  bool _disposed = false;
  ElectricalProject? _interactionSnapshot;

  ElectricalProject get project => _project;
  EditorTool tool = EditorTool.select;
  TerminalRef? pendingWireStart;
  String? selectedComponentId;
  String? selectedWireId;
  bool showGrid = true;
  bool industrialSurface = true;
  bool snapToGrid = true;
  double gridSize = 20;
  double zoom = 1;
  BoardPoint viewportOffset = BoardPoint.zero;
  bool isRunning = false;
  bool isSaving = false;
  String? lastError;
  SimulationResult? result;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;
  int get redoCount => _redo.length;

  CircuitComponent? get selectedComponent => selectedComponentId == null
      ? null
      : _project.componentById(selectedComponentId!);

  CircuitWire? get selectedWire =>
      selectedWireId == null ? null : _project.wireById(selectedWireId!);

  void selectComponent(String? id) {
    selectedComponentId = id;
    selectedWireId = null;
    pendingWireStart = null;
    tool = EditorTool.select;
    notifyListeners();
  }

  void selectWire(String? id) {
    selectedWireId = id;
    selectedComponentId = null;
    pendingWireStart = null;
    tool = EditorTool.select;
    notifyListeners();
  }

  void setViewport({double? scale, BoardPoint? offset}) {
    if (scale != null) zoom = scale.clamp(0.08, 3.0).toDouble();
    if (offset != null) viewportOffset = offset;
    notifyListeners();
  }

  void setGrid({bool? visible, bool? snap, double? size}) {
    showGrid = visible ?? showGrid;
    snapToGrid = snap ?? snapToGrid;
    if (size != null) gridSize = size.clamp(5, 100).toDouble();
    notifyListeners();
  }

  void setIndustrialSurface(bool value) {
    industrialSurface = value;
    notifyListeners();
  }

  BoardPoint snap(BoardPoint point) {
    if (!snapToGrid) return point;
    return BoardPoint(
      (point.x / gridSize).round() * gridSize,
      (point.y / gridSize).round() * gridSize,
    );
  }

  String addComponent(ComponentKind kind, BoardPoint requestedPosition) {
    final spec = ComponentCatalog.specOf(kind);
    final id = _ids.create('c');
    final draft = CircuitComponent(
      id: id,
      kind: kind,
      label: _nextLabel(kind),
      position: requestedPosition,
      layerId: _defaultLayer(kind),
      properties: <String, Object>{
        ...spec.defaultProperties,
        if (SupplyBay.isSupplyKind(kind)) 'enabled': false,
      },
    );
    var requested = snap(requestedPosition);
    if (snapToGrid) {
      requested = DinGeometry.snapWithHeight(
        requested,
        draft,
        spec.size.height,
      );
    }
    final component = draft.copyWith(
      position: _clampPosition(
        requested,
        spec.size.width,
        spec.size.height,
      ),
    );
    _commit(
      _project.copyWith(
        components: <CircuitComponent>[..._project.components, component],
      ),
    );
    selectedComponentId = id;
    selectedWireId = null;
    notifyListeners();
    return id;
  }

  void beginInteraction() {
    _interactionSnapshot ??= _project;
  }

  void endInteraction() {
    final snapshot = _interactionSnapshot;
    _interactionSnapshot = null;
    if (snapshot == null || identical(snapshot, _project)) return;
    _undo.add(snapshot);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    _scheduleSave();
    notifyListeners();
  }

  void moveComponent(
    String id,
    BoardPoint requestedPosition, {
    bool transient = false,
  }) {
    final component = _project.componentById(id);
    if (component == null ||
        SupplyBay.isFixed(component) ||
        _isLocked(component.layerId)) {
      return;
    }
    final spec = ComponentCatalog.specOf(component.kind);
    var requested = snap(requestedPosition);
    if (snapToGrid) {
      requested = DinGeometry.snapWithHeight(
        requested,
        component,
        spec.size.height * component.scale,
      );
    }
    final position = _clampPosition(
      requested,
      spec.size.width * component.scale,
      spec.size.height * component.scale,
    );
    final updated = component.copyWith(position: position);
    if (transient) {
      _previewComponent(updated);
    } else {
      _replaceComponent(updated);
    }
  }

  void rotateComponent(String id) {
    final component = _project.componentById(id);
    if (component == null ||
        SupplyBay.isFixed(component) ||
        _isLocked(component.layerId)) {
      return;
    }
    _replaceComponent(component.copyWith(rotation: (component.rotation + 1) % 4));
  }

  void resizeComponent(String id, double scale) {
    final component = _project.componentById(id);
    if (component == null ||
        SupplyBay.isFixed(component) ||
        _isLocked(component.layerId)) {
      return;
    }
    final nextScale = scale.clamp(0.6, 1.8).toDouble();
    final spec = ComponentCatalog.specOf(component.kind);
    _replaceComponent(
      component.copyWith(
        scale: nextScale,
        position: _clampPosition(
          component.position,
          spec.size.width * nextScale,
          spec.size.height * nextScale,
        ),
      ),
    );
  }

  void renameComponent(String id, String label) {
    final component = _project.componentById(id);
    if (component == null || label.trim().isEmpty) return;
    _replaceComponent(component.copyWith(label: label.trim()));
  }

  void updateComponentProperties(String id, Map<String, Object> properties) {
    final component = _project.componentById(id);
    if (component == null) return;
    final nextGroup = (properties['interlockGroup'] ??
            component.properties['interlockGroup'] ??
            '')
        .toString()
        .trim();
    final nextRole = (properties['interlockRole'] ??
            component.properties['interlockRole'] ??
            '')
        .toString()
        .trim();
    if (nextGroup != component.text('interlockGroup').trim() ||
        nextRole != component.text('interlockRole').trim()) {
      lastError =
          'استعمل محرر زوج التعشيق لحفظ الكونتاكتورين معاً دون مجموعة ناقصة.';
      notifyListeners();
      return;
    }
    _replaceComponent(
      component.copyWith(properties: Map<String, Object>.from(properties)),
    );
  }

  /// Assigns both sides of a mechanical interlock in one undoable commit.
  /// Any old partners are detached in the same commit, so no dangling group
  /// can be saved while moving a contactor from one pair to another.
  String? configureInterlockPair(
    String componentId,
    String peerId,
    String group,
    String role,
  ) {
    final component = _project.componentById(componentId);
    final peer = _project.componentById(peerId);
    final normalizedGroup = group.trim();
    final normalizedRole = role.trim();
    if (component == null || peer == null || componentId == peerId) {
      return _interlockError('اختر كونتاكتورين مختلفين.');
    }
    const supported = <ComponentKind>{
      ComponentKind.contactor,
      ComponentKind.contactor4P,
    };
    if (!supported.contains(component.kind) || !supported.contains(peer.kind)) {
      return _interlockError('التعشيق النجمي/المثلثي متاح للكونتاكتورات فقط.');
    }
    if (normalizedGroup.isEmpty ||
        !const <String>{'star', 'delta'}.contains(normalizedRole)) {
      return _interlockError(
        'أدخل مجموعة غير فارغة ودور star أو delta قبل الحفظ.',
      );
    }
    final affected = <String>{componentId, peerId};
    for (final anchor in <CircuitComponent>[component, peer]) {
      final oldGroup = anchor.text('interlockGroup').trim();
      if (oldGroup.isEmpty) continue;
      final members = _project.components
          .where((item) => item.text('interlockGroup').trim() == oldGroup)
          .toList(growable: false);
      if (members.length != 2) {
        return _interlockError('المجموعة القديمة $oldGroup غير مكتملة.');
      }
      affected.addAll(members.map((item) => item.id));
    }
    final occupied = _project.components.any(
      (item) =>
          item.text('interlockGroup').trim() == normalizedGroup &&
          !affected.contains(item.id),
    );
    if (occupied) {
      return _interlockError('المجموعة $normalizedGroup مستعملة من زوج آخر.');
    }
    final next = _project.copyWith(
      components: _project.components.map((item) {
        if (!affected.contains(item.id)) return item;
        final assignedRole = item.id == componentId
            ? normalizedRole
            : item.id == peerId
                ? normalizedRole == 'star'
                    ? 'delta'
                    : 'star'
                : '';
        return item.copyWith(
          properties: <String, Object>{
            ...item.properties,
            'interlockGroup': assignedRole.isEmpty ? '' : normalizedGroup,
            'interlockRole': assignedRole,
          },
        );
      }).toList(growable: false),
    );
    lastError = null;
    _commit(next);
    return null;
  }

  String? clearInterlockPair(String componentId) {
    final component = _project.componentById(componentId);
    if (component == null) return _interlockError('الجهاز غير موجود.');
    final group = component.text('interlockGroup').trim();
    final affected = <String>{componentId};
    if (group.isNotEmpty) {
      final members = _project.components
          .where((item) => item.text('interlockGroup').trim() == group)
          .toList(growable: false);
      if (members.length != 2) {
        return _interlockError('لا يمكن فك مجموعة غير مكتملة؛ راجع المشروع.');
      }
      affected.addAll(members.map((item) => item.id));
    }
    lastError = null;
    _commit(
      _project.copyWith(
        components: _project.components.map((item) {
          if (!affected.contains(item.id)) return item;
          return item.copyWith(
            properties: <String, Object>{
              ...item.properties,
              'interlockGroup': '',
              'interlockRole': '',
            },
          );
        }).toList(growable: false),
      ),
    );
    return null;
  }

  String? _interlockError(String message) {
    lastError = message;
    notifyListeners();
    return message;
  }

  void injectFault(String id, String fault) {
    const supported = <String>{'none', 'open', 'short', 'coilOpen'};
    if (!supported.contains(fault)) {
      throw ArgumentError.value(fault, 'fault', 'Unsupported fault');
    }
    final component = _project.componentById(id);
    if (component == null) return;
    updateComponentProperties(
      id,
      <String, Object>{...component.properties, 'fault': fault},
    );
  }

  String? duplicateComponent(String id) {
    final component = _project.componentById(id);
    if (component == null || SupplyBay.isFixed(component)) return null;
    final newId = _ids.create('c');
    final spec = ComponentCatalog.specOf(component.kind);
    var requested = snap(component.position + const BoardPoint(30, 30));
    if (snapToGrid) {
      requested = DinGeometry.snapWithHeight(
        requested,
        component,
        spec.size.height * component.scale,
      );
    }
    final duplicateProperties = Map<String, Object>.from(component.properties);
    if (duplicateProperties.containsKey('interlockGroup')) {
      duplicateProperties['interlockGroup'] = '';
      duplicateProperties['interlockRole'] = '';
    }
    final duplicate = CircuitComponent(
      id: newId,
      kind: component.kind,
      label: _nextLabel(component.kind),
      position: _clampPosition(
        requested,
        spec.size.width * component.scale,
        spec.size.height * component.scale,
      ),
      layerId: component.layerId,
      rotation: component.rotation,
      scale: component.scale,
      properties: duplicateProperties,
    );
    _commit(
      _project.copyWith(
        components: <CircuitComponent>[..._project.components, duplicate],
      ),
    );
    selectedComponentId = newId;
    notifyListeners();
    return newId;
  }

  void deleteComponent(String id) {
    final component = _project.componentById(id);
    if (component == null || SupplyBay.isFixed(component)) return;
    final interlockGroup = component.text('interlockGroup').trim();
    _commit(
      _project.copyWith(
        components: _project.components
            .where((item) => item.id != id)
            .map((item) {
              if (interlockGroup.isEmpty ||
                  item.text('interlockGroup').trim() != interlockGroup) {
                return item;
              }
              return item.copyWith(
                properties: <String, Object>{
                  ...item.properties,
                  'interlockGroup': '',
                  'interlockRole': '',
                },
              );
            })
            .toList(growable: false),
        wires: _project.wires
            .where(
              (wire) =>
                  wire.from.componentId != id && wire.to.componentId != id,
            )
            .toList(growable: false),
      ),
    );
    if (selectedComponentId == id) selectedComponentId = null;
    notifyListeners();
  }

  void beginWire(TerminalRef ref) {
    final component = _project.componentById(ref.componentId);
    if (component == null || _isLocked(component.layerId)) return;
    ComponentCatalog.specOf(component.kind).terminal(ref.terminalId);
    pendingWireStart = ref;
    tool = EditorTool.wire;
    selectedComponentId = null;
    selectedWireId = null;
    lastError = null;
    notifyListeners();
  }

  void cancelWire() {
    pendingWireStart = null;
    tool = EditorTool.select;
    notifyListeners();
  }

  String? completeWire(TerminalRef to) {
    final from = pendingWireStart;
    if (from == null) {
      beginWire(to);
      return null;
    }
    final issue = ConnectionValidator.validate(_project, from, to);
    if (issue != null) {
      lastError = issue.messageAr;
      notifyListeners();
      return null;
    }
    final fromComponent = _project.componentById(from.componentId)!;
    final toComponent = _project.componentById(to.componentId)!;
    final fromTerminal = ComponentCatalog.specOf(
      fromComponent.kind,
    ).terminal(from.terminalId);
    final toTerminal = ComponentCatalog.specOf(
      toComponent.kind,
    ).terminal(to.terminalId);
    final isControl =
        fromTerminal.kind == TerminalKind.coil ||
        fromTerminal.kind == TerminalKind.auxiliary ||
        toTerminal.kind == TerminalKind.coil ||
        toTerminal.kind == TerminalKind.auxiliary;
    final controlLayerId = _project.layerById('control')?.id;
    final id = _ids.create('w');
    final wire = CircuitWire(
      id: id,
      from: from,
      to: to,
      layerId: isControl
          ? controlLayerId ?? toComponent.layerId
          : fromComponent.layerId,
      colorValue: isControl && fromTerminal.kind == TerminalKind.power
          ? 0xff1e88e5
          : _defaultWireColor(fromTerminal.kind),
    );
    _commit(_project.copyWith(wires: <CircuitWire>[..._project.wires, wire]));
    pendingWireStart = null;
    tool = EditorTool.select;
    selectedWireId = id;
    selectedComponentId = null;
    lastError = null;
    notifyListeners();
    return id;
  }

  void updateWire(CircuitWire updated) {
    final existing = _project.wireById(updated.id);
    if (existing == null || _isLocked(existing.layerId)) return;
    final issue = ConnectionValidator.validate(
      _project,
      updated.from,
      updated.to,
      ignoreWireId: updated.id,
    );
    if (issue != null) {
      lastError = issue.messageAr;
      notifyListeners();
      return;
    }
    _commit(
      _project.copyWith(
        wires: _project.wires
            .map((wire) => wire.id == updated.id ? updated : wire)
            .toList(growable: false),
      ),
    );
  }

  void addWireWaypoint(String id, BoardPoint point) {
    final wire = _project.wireById(id);
    if (wire == null) return;
    updateWire(
      wire.copyWith(waypoints: <BoardPoint>[...wire.waypoints, snap(point)]),
    );
  }

  void moveWireWaypoint(
    String id,
    int index,
    BoardPoint point, {
    bool transient = false,
  }) {
    final wire = _project.wireById(id);
    if (wire == null || index < 0 || index >= wire.waypoints.length) return;
    final points = List<BoardPoint>.from(wire.waypoints);
    points[index] = snap(point);
    final updated = wire.copyWith(waypoints: points);
    if (transient) {
      _previewWire(updated);
    } else {
      updateWire(updated);
    }
  }

  void removeWireWaypoint(String id, int index) {
    final wire = _project.wireById(id);
    if (wire == null || index < 0 || index >= wire.waypoints.length) return;
    final points = List<BoardPoint>.from(wire.waypoints)..removeAt(index);
    updateWire(wire.copyWith(waypoints: points));
  }

  void autoRouteWire(String id) {
    final wire = _project.wireById(id);
    if (wire != null) updateWire(wire.copyWith(waypoints: <BoardPoint>[]));
  }

  void deleteWire(String id) {
    if (!_project.wires.any((wire) => wire.id == id)) return;
    _commit(
      _project.copyWith(
        wires: _project.wires
            .where((wire) => wire.id != id)
            .toList(growable: false),
      ),
    );
    if (selectedWireId == id) selectedWireId = null;
    notifyListeners();
  }

  String addLayer(String name) {
    if (name.trim().isEmpty) throw ArgumentError('Layer name is empty.');
    final id = _ids.create('layer');
    final colors = <int>[0xff26a69a, 0xffab47bc, 0xffffa726, 0xff78909c];
    final layer = CircuitLayer(
      id: id,
      name: name.trim(),
      colorValue: colors[_project.layers.length % colors.length],
    );
    _commit(_project.copyWith(layers: <CircuitLayer>[..._project.layers, layer]));
    return id;
  }

  void renameLayer(String id, String name) {
    if (name.trim().isEmpty) return;
    _commit(
      _project.copyWith(
        layers: _project.layers
            .map((layer) => layer.id == id ? layer.copyWith(name: name.trim()) : layer)
            .toList(growable: false),
      ),
    );
  }

  void setLayerVisibility(String id, bool visible) {
    _commit(
      _project.copyWith(
        layers: _project.layers
            .map((layer) => layer.id == id ? layer.copyWith(visible: visible) : layer)
            .toList(growable: false),
      ),
    );
  }

  void setLayerLocked(String id, bool locked) {
    _commit(
      _project.copyWith(
        layers: _project.layers
            .map((layer) => layer.id == id ? layer.copyWith(locked: locked) : layer)
            .toList(growable: false),
      ),
    );
  }

  bool deleteLayer(String id) {
    final used = _project.components.any((item) => item.layerId == id) ||
        _project.wires.any((item) => item.layerId == id);
    if (used || _project.layers.length == 1) {
      lastError = 'لا يمكن حذف طبقة مستعملة أو الطبقة الوحيدة.';
      notifyListeners();
      return false;
    }
    _commit(
      _project.copyWith(
        layers: _project.layers
            .where((layer) => layer.id != id)
            .toList(growable: false),
      ),
    );
    return true;
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_project);
    _project = _undo.removeLast();
    _clearInvalidSelection();
    _afterHistoryChange();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_project);
    _project = _redo.removeLast();
    _clearInvalidSelection();
    _afterHistoryChange();
  }

  void startSimulation() {
    if (isRunning) return;
    isRunning = true;
    lastError = null;
    simulateOnce();
    if (!isRunning) return;
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => simulateOnce(),
    );
    notifyListeners();
  }

  void simulateOnce({double deltaSeconds = 0.1}) {
    try {
      result = simulator.step(_project, deltaSeconds: deltaSeconds);
      lastError = null;
    } on Object catch (error) {
      result = null;
      lastError = 'خطأ في المحاكاة: $error';
      stopSimulation();
    }
    if (!_disposed) notifyListeners();
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (!isRunning && result == null) return;
    isRunning = false;
    if (result != null) {
      _project = _project.copyWith(lastSimulation: result!.toJson());
      _scheduleSave();
    }
    if (!_disposed) notifyListeners();
  }

  void resetSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    isRunning = false;
    simulator.reset();
    result = null;
    _project = _project.copyWith(clearLastSimulation: true);
    _scheduleSave();
    notifyListeners();
  }

  void setMomentaryPressed(String id, bool pressed) {
    if (!isRunning) return;
    final component = _project.componentById(id);
    if (component == null ||
        (component.kind != ComponentKind.pushButtonNO &&
            component.kind != ComponentKind.pushButtonNC)) {
      return;
    }
    _project = _project.copyWith(
      components: _project.components
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    properties: <String, Object>{
                      ...item.properties,
                      'pressed': pressed,
                    },
                  )
                : item,
          )
          .toList(growable: false),
    );
    simulateOnce();
  }

  void toggleOperationalState(String id) {
    if (!isRunning) return;
    final component = _project.componentById(id);
    if (component == null) return;
    if (component.kind == ComponentKind.rotarySwitch ||
        component.kind == ComponentKind.twoWaySwitch) {
      final position = component.number('position').round();
      final next = component.kind == ComponentKind.twoWaySwitch
          ? position % 2 + 1
          : (position + 1) % 3;
      _updateOperationalProperties(
        id,
        <String, Object>{'position': next},
      );
      simulateOnce();
      return;
    }
    final key = switch (component.kind) {
      ComponentKind.selectorSwitch ||
      ComponentKind.emergencyStop ||
      ComponentKind.lightSwitch => 'closed',
      ComponentKind.intermediateSwitch => 'crossed',
      ComponentKind.sensor ||
      ComponentKind.limitSwitch ||
      ComponentKind.motionSensor ||
      ComponentKind.lightSensor ||
      ComponentKind.floatSwitch ||
      ComponentKind.pressureSwitch ||
      ComponentKind.flowSwitch ||
      ComponentKind.proximitySensor ||
      ComponentKind.capacitiveSensor ||
      ComponentKind.photoelectricSensor => 'active',
      _ => null,
    };
    if (key == null) return;
    _updateOperationalProperties(id, <String, Object>{key: !component.flag(key)});
    simulateOnce();
  }

  void setSupplyEnabled(String id, bool enabled) {
    final component = _project.componentById(id);
    if (component == null || !SupplyBay.isSupplyKind(component.kind)) return;
    updateComponentProperties(
      id,
      <String, Object>{...component.properties, 'enabled': enabled},
    );
    if (isRunning) simulateOnce();
  }

  void _updateOperationalProperties(
    String id,
    Map<String, Object> changes,
  ) {
    _project = _project.copyWith(
      components: _project.components
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    properties: <String, Object>{...item.properties, ...changes},
                  )
                : item,
          )
          .toList(growable: false),
    );
  }

  void resetProtection(String id) {
    simulator.resetProtection(id);
    simulateOnce();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final save = _onSave;
    if (save == null || _disposed) return;
    isSaving = true;
    try {
      await save(_project);
      lastError = null;
    } on Object catch (error) {
      lastError = 'تعذر الحفظ المحلي: $error';
    } finally {
      isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _previewComponent(CircuitComponent component) {
    _project = _project.copyWith(
      updatedAt: _clock().toUtc(),
      components: _project.components
          .map((item) => item.id == component.id ? component : item)
          .toList(growable: false),
      clearLastSimulation: true,
    );
    result = null;
    _scheduleSave();
    notifyListeners();
  }

  void _previewWire(CircuitWire updated) {
    _project = _project.copyWith(
      updatedAt: _clock().toUtc(),
      wires: _project.wires
          .map((wire) => wire.id == updated.id ? updated : wire)
          .toList(growable: false),
      clearLastSimulation: true,
    );
    result = null;
    _scheduleSave();
    notifyListeners();
  }

  void _replaceComponent(CircuitComponent component) {
    _commit(
      _project.copyWith(
        components: _project.components
            .map((item) => item.id == component.id ? component : item)
            .toList(growable: false),
      ),
    );
  }

  void _commit(ElectricalProject next) {
    final updated = next.copyWith(
      updatedAt: _clock().toUtc(),
      clearLastSimulation: true,
    );
    updated.validate();
    _undo.add(_project);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    _project = updated;
    result = null;
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    if (_onSave == null || _disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(flush());
    });
  }

  void _afterHistoryChange() {
    result = null;
    simulator.reset();
    _scheduleSave();
    notifyListeners();
  }

  void _clearInvalidSelection() {
    if (_project.componentById(selectedComponentId ?? '') == null) {
      selectedComponentId = null;
    }
    if (_project.wireById(selectedWireId ?? '') == null) selectedWireId = null;
    pendingWireStart = null;
    tool = EditorTool.select;
  }

  bool _isLocked(String layerId) =>
      _project.layerById(layerId)?.locked ?? false;

  BoardPoint _clampPosition(BoardPoint point, double width, double height) {
    return BoardPoint(
      point.x.clamp(0.0, mathMax(0, _project.boardWidth - width)).toDouble(),
      point.y.clamp(0.0, mathMax(0, _project.boardHeight - height)).toDouble(),
    );
  }

  static double mathMax(double a, double b) => a > b ? a : b;

  String _defaultLayer(ComponentKind kind) {
    final category = ComponentCatalog.specOf(kind).category;
    final preferred = switch (category) {
      ComponentCategory.control ||
      ComponentCategory.contactors ||
      ComponentCategory.timers ||
      ComponentCategory.sensors => 'control',
      ComponentCategory.signals ||
      ComponentCategory.measurement => 'signals',
      _ => 'power',
    };
    return _project.layerById(preferred)?.id ?? _project.layers.first.id;
  }

  String _nextLabel(ComponentKind kind) {
    final prefix = switch (kind) {
      ComponentKind.dcSupply ||
      ComponentKind.acSupply ||
      ComponentKind.threePhaseSupply => 'G',
      ComponentKind.circuitBreaker ||
      ComponentKind.differentialBreaker ||
      ComponentKind.motorBreaker => 'Q',
      ComponentKind.contactor => 'K',
      ComponentKind.thermalRelay => 'F',
      ComponentKind.auxiliaryRelay => 'KA',
      ComponentKind.pushButtonNO ||
      ComponentKind.pushButtonNC ||
      ComponentKind.emergencyStop => 'S',
      ComponentKind.selectorSwitch || ComponentKind.rotarySwitch => 'SA',
      ComponentKind.timer || ComponentKind.timerOffDelay => 'KT',
      ComponentKind.sensor || ComponentKind.limitSwitch => 'B',
      ComponentKind.indicator => 'H',
      ComponentKind.motor3Phase || ComponentKind.motor1Phase => 'M',
      ComponentKind.transformer => 'T',
      ComponentKind.terminalBlock => 'X',
      ComponentKind.voltmeter => 'V',
      ComponentKind.ammeter => 'A',
      ComponentKind.digitalCounter => 'P',
      ComponentKind.fuse => 'FU',
      _ => switch (ComponentCatalog.specOf(kind).category) {
        ComponentCategory.sources => 'T',
        ComponentCategory.protection => 'Q',
        ComponentCategory.contactors => 'K',
        ComponentCategory.control => 'S',
        ComponentCategory.timers => 'KT',
        ComponentCategory.sensors => 'B',
        ComponentCategory.motors => 'M',
        ComponentCategory.signals => 'H',
        ComponentCategory.measurement => 'P',
        ComponentCategory.terminals => 'X',
      },
    };
    final count = _project.components.where((item) => item.kind == kind).length + 1;
    return '$prefix$count';
  }

  int _defaultWireColor(TerminalKind kind) => switch (kind) {
        TerminalKind.earth => 0xff43a047,
        TerminalKind.coil || TerminalKind.auxiliary => 0xff1e88e5,
        TerminalKind.measurement => 0xfffdd835,
        TerminalKind.neutral => 0xff3949ab,
        TerminalKind.power => 0xffe53935,
      };

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _saveTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
