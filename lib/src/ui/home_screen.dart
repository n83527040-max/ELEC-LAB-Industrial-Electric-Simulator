import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../export/project_exporter.dart';
import '../models/project.dart';
import '../models/project_templates.dart';
import '../state/settings_controller.dart';
import '../storage/project_repository.dart';
import 'editor_screen.dart';
import 'learning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    required this.settings,
    super.key,
  });

  final ProjectRepository repository;
  final SettingsController settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProjectSummary> _projects = <ProjectSummary>[];
  bool _loading = true;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final projects = await widget.repository.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _projects
        .where((project) => project.name.contains(_query.trim()))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bolt_rounded, color: Color(0xff00c8ff), size: 30),
            SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('ELEC LAB', textDirection: TextDirection.ltr),
                  Text(
                    'المختبر الكهربائي الصناعي',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: widget.settings.toggleTheme,
            tooltip: 'تبديل الوضع الداكن والفاتح',
            icon: Icon(
                widget.settings.darkMode ? Icons.light_mode : Icons.dark_mode),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenu,
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'import', child: Text('استيراد مشروع')),
              PopupMenuItem(
                  value: 'backup', child: Text('إنشاء نسخة احتياطية')),
              PopupMenuItem(
                  value: 'restore', child: Text('استعادة نسخة احتياطية')),
              PopupMenuItem(
                  value: 'learning', child: Text('التحديات والمساعدة')),
              PopupMenuItem(value: 'about', child: Text('حول ونطاق المحاكاة')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: <Widget>[
              _HeroCard(onStart: _createProject),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _createProject,
                      icon: const Icon(Icons.add),
                      label: const Text('مشروع جديد'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _importProject,
                    tooltip: 'استيراد ملف مشروع',
                    icon: const Icon(Icons.upload_file),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'ابحث في مشاريعي…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('مشاريعي',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('${_projects.length} مشروع'),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _refresh)
              else if (filtered.isEmpty)
                _EmptyProjects(hasProjects: _projects.isNotEmpty)
              else
                ...filtered.map(
                  (project) => _ProjectCard(
                    key: ValueKey<String>(project.id),
                    summary: project,
                    repository: widget.repository,
                    onOpen: () => _openProject(project.id),
                    onAction: (action) => _projectAction(project, action),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'تعلّم وصمّم وجرّب دون إنترنت • محاكاة تعليمية فقط',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    final draft = await showModalBottomSheet<_ProjectDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _NewProjectSheet(),
    );
    if (draft == null) return;
    try {
      var project = await widget.repository.createProject(
        name: draft.name,
        description: draft.description,
        width: draft.width,
        height: draft.height,
      );
      project = ProjectTemplates.apply(project, draft.template);
      await widget.repository.saveProject(project);
      await _refresh();
      if (mounted) await _openProject(project.id);
    } on Object catch (error) {
      _showError('تعذر إنشاء المشروع', error);
    }
  }

  Future<void> _openProject(String id) async {
    try {
      final project = await widget.repository.loadProject(id);
      if (project == null || !mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => EditorScreen(
            project: project,
            repository: widget.repository,
          ),
        ),
      );
      await _refresh();
    } on Object catch (error) {
      _showError('تعذر فتح المشروع', error);
    }
  }

  Future<void> _projectAction(ProjectSummary summary, String action) async {
    switch (action) {
      case 'rename':
        final name = await _askForName(summary.name);
        if (name != null) {
          await widget.repository.renameProject(summary.id, name);
          await _refresh();
        }
      case 'duplicate':
        await widget.repository.duplicateProject(summary.id);
        await _refresh();
      case 'export':
        final project = await widget.repository.loadProject(summary.id);
        if (project != null) await _shareProject(project);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف المشروع؟'),
            content: Text(
                'سيتم حذف «${summary.name}» ونسخته المحلية. لا يمكن التراجع.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await widget.repository.deleteProject(summary.id);
          await _refresh();
        }
    }
  }

  Future<String?> _askForName(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تسمية المشروع'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم المشروع'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result;
  }

  Future<void> _shareProject(ElectricalProject project) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/elec-lab-${project.id}.json');
    await file.writeAsString(widget.repository.exportProject(project),
        flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'مشروع ELEC LAB: ${project.name}',
        subject: 'ELEC LAB project',
      ),
    );
  }

  Future<void> _importProject() async {
    try {
      final document = await _pickTextFile();
      if (document == null) return;
      final project = await widget.repository.importProject(document);
      await _refresh();
      if (mounted) await _openProject(project.id);
    } on Object catch (error) {
      _showError('ملف المشروع غير صالح', error);
    }
  }

  Future<String?> _pickTextFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.bytes != null) return utf8.decode(picked.bytes!);
    if (picked.path != null) return File(picked.path!).readAsString();
    throw const FormatException('No readable file data.');
  }

  Future<void> _backup() async {
    try {
      final document = await widget.repository.createBackup();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/elec-lab-backup.json');
      await file.writeAsString(document, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'نسخة احتياطية من ELEC LAB',
        ),
      );
    } on Object catch (error) {
      _showError('تعذر إنشاء النسخة الاحتياطية', error);
    }
  }

  Future<void> _restore() async {
    try {
      final document = await _pickTextFile();
      if (document == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('استعادة النسخة؟'),
          content: const Text(
              'ستُستبدل المشاريع التي لها نفس المعرّف بمحتوى النسخة الاحتياطية.'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('استعادة')),
          ],
        ),
      );
      if (confirmed != true) return;
      final count = await widget.repository.restoreBackup(document);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت استعادة $count مشروعاً.')),
        );
      }
    } on Object catch (error) {
      _showError('تعذر استعادة النسخة', error);
    }
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'import':
        unawaited(_importProject());
      case 'backup':
        unawaited(_backup());
      case 'restore':
        unawaited(_restore());
      case 'learning':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (context) => const LearningScreen()),
        );
      case 'about':
        _showAbout();
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'ELEC LAB',
      applicationVersion: '0.3.0',
      applicationIcon:
          Image.asset('assets/icon/app_icon.png', width: 64, height: 64),
      children: const <Widget>[
        Text('مختبر تعليمي يعمل دون إنترنت لدوائر DC وAC الجيبية الخطية.'),
        SizedBox(height: 8),
        Text(
            'لا يحسب العابرات أو harmonics أو نموذج عزم المحرك الميكانيكي، ولا يصلح مرجعاً لتنفيذ دائرة حقيقية.'),
      ],
    );
  }

  void _showError(String title, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $error')),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xff0b2544), Color(0xff075eb5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'تعلّم بالكهرباء الصناعية بالتجارب',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'صمّم • وصّل • حاكي • قِس • شخّص',
                  style: TextStyle(color: Color(0xffb9e6ff)),
                ),
              ],
            ),
          ),
          Icon(Icons.electrical_services, color: Color(0xff00c8ff), size: 58),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.summary,
    required this.repository,
    required this.onOpen,
    required this.onAction,
    super.key,
  });

  final ProjectSummary summary;
  final ProjectRepository repository;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final date = summary.updatedAt.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.all(10),
        leading: SizedBox(
          width: 88,
          height: 68,
          child: FutureBuilder<ElectricalProject?>(
            future: repository.loadProject(summary.id),
            builder: (context, snapshot) {
              final project = snapshot.data;
              if (project == null) {
                return const ColoredBox(
                  color: Color(0xff14273b),
                  child: Icon(Icons.electrical_services, size: 36),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: project.boardWidth,
                    height: project.boardHeight,
                    child: ProjectThumbnail(project: project),
                  ),
                ),
              );
            },
          ),
        ),
        title: Text(summary.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${summary.componentCount} عناصر • ${summary.wireCount} أسلاك\n${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: onAction,
          itemBuilder: (context) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
            PopupMenuItem(value: 'duplicate', child: Text('نسخ المشروع')),
            PopupMenuItem(value: 'export', child: Text('مشاركة ملف المشروع')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }
}

class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  ProjectTemplateKind _template = ProjectTemplateKind.blank;
  double _width = 1200;
  double _height = 900;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('مشروع جديد',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 70,
              decoration: const InputDecoration(
                labelText: 'اسم المشروع',
                hintText: 'مثال: دائرة تشغيل محرك',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 16),
            const Text('مساحة اللوحة'),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const <ButtonSegment<double>>[
                ButtonSegment(value: 800, label: Text('صغيرة')),
                ButtonSegment(value: 1200, label: Text('متوسطة')),
                ButtonSegment(value: 1600, label: Text('كبيرة')),
              ],
              selected: <double>{_width},
              onSelectionChanged: (value) => setState(() {
                _width = value.first;
                _height = _width * 0.75;
              }),
            ),
            const SizedBox(height: 16),
            const Text('قالب البداية'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ProjectTemplateKind.values
                  .map(
                    (template) => ChoiceChip(
                      selected: _template == template,
                      label: Text(ProjectTemplates.name(template)),
                      onSelected: (_) => setState(() => _template = template),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل اسم المشروع أولاً.')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _ProjectDraft(
                    name: _name.text.trim(),
                    description: _description.text.trim(),
                    width: _width,
                    height: _height,
                    template: _template,
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('إنشاء المشروع'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDraft {
  const _ProjectDraft({
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.template,
  });

  final String name;
  final String description;
  final double width;
  final double height;
  final ProjectTemplateKind template;
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.hasProjects});

  final bool hasProjects;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: <Widget>[
          const Icon(Icons.dashboard_customize_outlined,
              size: 64, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(hasProjects
              ? 'لا توجد نتيجة لهذا البحث.'
              : 'لا توجد مشاريع بعد. أنشئ أول لوحة كهربائية.'),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Text(message),
            TextButton(
                onPressed: () => unawaited(onRetry()),
                child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
