import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../export/project_exporter.dart';
import '../models/component_catalog.dart';
import '../models/geometry.dart';
import '../models/project.dart';
import '../models/supply_bay.dart';
import '../models/terminal.dart';
import '../state/editor_controller.dart';
import '../storage/project_repository.dart';
import 'circuit_board.dart';
import 'component_details_sheet.dart';
import 'component_library_sheet.dart';
import 'layers_sheet.dart';
import 'learning_screen.dart';
import 'simulation_panel.dart';
import 'supply_panel.dart';
import 'wire_settings_sheet.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.project,
    required this.repository,
    super.key,
  });

  final ElectricalProject project;
  final ProjectRepository repository;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late final EditorController _controller;
  final GlobalKey<CircuitBoardState> _boardKey = GlobalKey<CircuitBoardState>();
  String? _observedWire;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      project: widget.project,
      onSave: widget.repository.saveProject,
    );
    _controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_controller.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final selected = _controller.selectedWireId;
    if (selected != _observedWire) {
      _observedWire = selected;
      if (selected != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.selectedWireId == selected) {
            _showWireSettings();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => unawaited(_close()),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'حفظ ورجوع',
            ),
            title: Column(
              children: <Widget>[
                Text(
                  _controller.project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _controller.isSaving
                      ? 'جارٍ الحفظ…'
                      : _controller.isRunning
                          ? 'المحاكاة تعمل • ${_controller.result?.time.toStringAsFixed(1) ?? '0'} s'
                          : 'محفوظ محلياً',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                key: const Key('toggle-simulation'),
                onPressed: _controller.isRunning
                    ? _controller.stopSimulation
                    : _controller.startSimulation,
                tooltip: _controller.isRunning ? 'إيقاف المحاكاة' : 'تشغيل المحاكاة',
                icon: Icon(
                  _controller.isRunning ? Icons.stop_circle : Icons.play_circle,
                  color: _controller.isRunning ? Colors.red : const Color(0xff00a6ff),
                  size: 30,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _handleMenu,
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem(
                    value: 'grid',
                    child: Text(_controller.showGrid ? 'إخفاء الشبكة' : 'إظهار الشبكة'),
                  ),
                  PopupMenuItem(
                    value: 'snap',
                    child: Text(_controller.snapToGrid ? 'تعطيل Snap' : 'تفعيل Snap'),
                  ),
                  PopupMenuItem(
                    value: 'surface',
                    child: Text(
                      _controller.industrialSurface
                          ? 'استعمال شبكة خفيفة'
                          : 'استعمال لوحة تركيب صناعية',
                    ),
                  ),
                  const PopupMenuItem(value: 'fit', child: Text('ملاءمة الدائرة للشاشة')),
                  const PopupMenuItem(value: 'results', child: Text('النتائج والتشخيص')),
                  const PopupMenuItem(value: 'png', child: Text('تصدير صورة PNG')),
                  const PopupMenuItem(value: 'pdf', child: Text('تصدير PDF')),
                  const PopupMenuItem(value: 'project', child: Text('مشاركة ملف المشروع')),
                  const PopupMenuItem(value: 'learning', child: Text('التحديات والمساعدة')),
                  const PopupMenuItem(value: 'scope', child: Text('نطاق المحاكاة والسلامة')),
                ],
              ),
            ],
          ),
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CircuitBoard(
                  key: _boardKey,
                  controller: _controller,
                  onShowDetails: (component) => _showDetails(component.id),
                ),
              ),
              if (_controller.pendingWireStart != null)
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: const Color(0xe6087ff5),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'تم تحديد الطرف الأول • اختر نقطة النهاية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: _controller.cancelWire,
                            child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_controller.lastError != null)
                Positioned(
                  top: _controller.pendingWireStart != null ? 62 : 10,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: const Color(0xe6b3261e),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _controller.lastError!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (_controller.selectedComponent == null)
                Positioned(
                  left: 10,
                  bottom: 82,
                  child: Card(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: () => _boardKey.currentState?.zoomBy(-0.15),
                          icon: const Icon(Icons.remove),
                          tooltip: 'تصغير',
                        ),
                        Text('${(_controller.zoom * 100).round()}%'),
                        IconButton(
                          onPressed: () => _boardKey.currentState?.zoomBy(0.15),
                          icon: const Icon(Icons.add),
                          tooltip: 'تكبير',
                        ),
                        IconButton(
                          onPressed: () => _boardKey.currentState?.fitToContent(),
                          icon: const Icon(Icons.fit_screen),
                          tooltip: 'ملاءمة الدائرة',
                        ),
                      ],
                    ),
                  ),
                ),
              if (_controller.selectedComponent != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 78,
                  child: _ComponentContextBar(controller: _controller),
                ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x88000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                height: 68,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      onPressed: _controller.canUndo ? _controller.undo : null,
                      icon: const Icon(Icons.undo),
                      tooltip: 'تراجع',
                    ),
                    IconButton(
                      onPressed: _controller.canRedo ? _controller.redo : null,
                      icon: const Icon(Icons.redo),
                      tooltip: 'إعادة',
                    ),
                    FloatingActionButton(
                      key: const Key('add-component'),
                      onPressed: _showLibrary,
                      mini: true,
                      tooltip: 'إضافة عنصر',
                      child: const Icon(Icons.add),
                    ),
                    IconButton(
                      key: const Key('supply-panel'),
                      onPressed: _showSupplies,
                      icon: const Icon(Icons.bolt),
                      tooltip: 'مصادر التغذية',
                    ),
                    IconButton(
                      onPressed: _showLayers,
                      icon: const Icon(Icons.layers),
                      tooltip: 'الطبقات',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _close() async {
    if (_busy) return;
    _controller.stopSimulation();
    await _controller.flush();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showLibrary() async {
    final kind = await showModalBottomSheet<ComponentKind>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ComponentLibrarySheet(),
    );
    if (kind == null) return;
    final spec = ComponentCatalog.specOf(kind);
    final center = _boardKey.currentState?.visibleCenter ??
        BoardPoint(
          _controller.project.boardWidth / 2,
          _controller.project.boardHeight / 2,
        );
    final requestedY = center.y - spec.size.height / 2;
    _controller.addComponent(
      kind,
      BoardPoint(
        center.x - spec.size.width / 2,
        requestedY < SupplyBay.reservedHeight + 20
            ? SupplyBay.reservedHeight + 20
            : requestedY,
      ),
    );
  }

  void _showSupplies() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SupplyPanel(
        controller: _controller,
        onShowDetails: (id) {
          Navigator.of(sheetContext).pop();
          _showDetails(id);
        },
      ),
    );
  }

  void _showLayers() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: LayersSheet(controller: _controller),
      ),
    );
  }

  void _showWireSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: WireSettingsSheet(controller: _controller),
      ),
    );
  }

  void _showDetails(String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ComponentDetailsSheet(controller: _controller, componentId: id),
    );
  }

  void _showResults() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SimulationPanel(controller: _controller),
    );
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'grid':
        _controller.setGrid(visible: !_controller.showGrid);
      case 'snap':
        _controller.setGrid(snap: !_controller.snapToGrid);
      case 'surface':
        _controller.setIndustrialSurface(!_controller.industrialSurface);
      case 'fit':
        _boardKey.currentState?.fitToContent();
      case 'results':
        _showResults();
      case 'png':
        unawaited(_export('png'));
      case 'pdf':
        unawaited(_export('pdf'));
      case 'project':
        unawaited(_export('project'));
      case 'learning':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => LearningScreen(
              project: _controller.project,
              result: _controller.result,
            ),
          ),
        );
      case 'scope':
        _showScope();
    }
  }

  Future<void> _export(String type) async {
    setState(() => _busy = true);
    try {
      await _controller.flush();
      final directory = await getTemporaryDirectory();
      late final File file;
      late final List<int> bytes;
      if (type == 'project') {
        file = File('${directory.path}/elec-lab-${_controller.project.id}.json');
        await file.writeAsString(
          widget.repository.exportProject(_controller.project),
          flush: true,
        );
      } else {
        bytes = type == 'png'
            ? await ProjectExporter.renderPng(_controller.project)
            : await ProjectExporter.renderPdf(_controller.project);
        file = File('${directory.path}/elec-lab-${_controller.project.id}.$type');
        await file.writeAsBytes(bytes, flush: true);
      }
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'ELEC LAB — ${_controller.project.name}',
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التصدير: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showScope() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نطاق المحاكاة والسلامة'),
        content: const SingleChildScrollView(
          child: Text(
            'النطاق المدعوم: DC وAC جيبي خطي بطور واحد أو ثلاثة أطوار متوازنة، محول مثالي بمقاومات الملفات، اتصالات وملفات وحمايات وقياسات وطاقة.\n\n'
            'المحول المثالي مخصص لـAC، وRCD يحسب المجموع المتجهي L+N لدائرة أحادية الطور. لا يُحسب قصر أرضي أو منحنى فصل خاص بمصنّع.\n\n'
            'غير مدعوم: العابرات الكهرومغناطيسية، harmonics، VFD/PLC، نموذج العزم والانزلاق الميكانيكي الدقيق، منحنيات RCD والحمايات الخاصة بالمصنعين، واختيار حمايات مطابق للمعايير.\n\n'
            'المحاكاة تعليمية فقط. لا توصّل أو تختبر قصراً على معدات حقيقية اعتماداً على التطبيق.',
          ),
        ),
        actions: <Widget>[
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('فهمت')),
        ],
      ),
    );
  }
}

class _ComponentContextBar extends StatelessWidget {
  const _ComponentContextBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final component = controller.selectedComponent!;
    final fixedSupply = SupplyBay.isFixed(component);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(component.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => ComponentDetailsSheet(
                  controller: controller,
                  componentId: component.id,
                ),
              ),
              icon: const Icon(Icons.info_outline),
              tooltip: 'التفاصيل و3D والخصائص',
            ),
            if (!fixedSupply)
              IconButton(
                onPressed: () => controller.rotateComponent(component.id),
              icon: const Icon(Icons.rotate_90_degrees_cw),
              tooltip: 'تدوير',
            ),
            if (!fixedSupply)
              IconButton(
                onPressed: () => controller.duplicateComponent(component.id),
              icon: const Icon(Icons.copy),
              tooltip: 'نسخ',
            ),
            if (!fixedSupply)
              IconButton(
                onPressed: () => controller.resizeComponent(
                component.id,
                component.scale >= 1.4 ? 0.8 : component.scale + 0.2,
              ),
              icon: const Icon(Icons.open_in_full),
              tooltip: 'تغيير الحجم',
            ),
            if (!fixedSupply)
              IconButton(
                onPressed: () => controller.deleteComponent(component.id),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف مع إمكانية التراجع',
            ),
          ],
        ),
      ),
    );
  }
}
