import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_editor_sheet.dart';

// ---------------------------------------------------------------------------
// Branch enum & helpers — unchanged from previous version.
// ---------------------------------------------------------------------------

enum _Branch {
  goals,
  constraints,
  highlights,
  reflections,
  preferences,
  notes,
  tasks,
}

extension on _Branch {
  String get title {
    switch (this) {
      case _Branch.goals:
        return 'Цели';
      case _Branch.constraints:
        return 'Ограничения';
      case _Branch.highlights:
        return 'Достижения';
      case _Branch.reflections:
        return 'Рефлексии';
      case _Branch.preferences:
        return 'Предпочтения';
      case _Branch.notes:
        return 'Заметки';
      case _Branch.tasks:
        return 'Задачи';
    }
  }

  /// Accent colour for each branch — inspired by Obsidian's colour coding.
  Color get color {
    switch (this) {
      case _Branch.goals:
        return const Color(0xFF7C3AED); // violet
      case _Branch.constraints:
        return const Color(0xFFEF4444); // red
      case _Branch.highlights:
        return const Color(0xFFF59E0B); // amber
      case _Branch.reflections:
        return const Color(0xFF3B82F6); // blue
      case _Branch.preferences:
        return const Color(0xFF8B5CF6); // purple
      case _Branch.notes:
        return const Color(0xFF10B981); // emerald
      case _Branch.tasks:
        return const Color(0xFF06B6D4); // cyan
    }
  }
}

// ---------------------------------------------------------------------------
// Graph node — a single point in the force-directed simulation.
// ---------------------------------------------------------------------------

class _GraphNode {
  _GraphNode({
    required this.id,
    required this.label,
    required this.branch,
    required this.isCentre,
    required this.isBranchHeader,
    this.leafIndex = -1,
    this.childCount = 0,
    Offset? position,
  }) : pos = position ?? Offset.zero,
       vel = Offset.zero;

  final String id;
  final String label;
  final _Branch? branch;
  final bool isCentre;
  final bool isBranchHeader;
  final int leafIndex;
  /// Number of leaves hanging off this branch header node.
  int childCount;
  Offset pos;
  Offset vel;

  /// During drag, freeze physics for this node.
  bool pinned = false;

  double get radius {
    if (isCentre) return 18;
    if (isBranchHeader) return 12;
    return 7;
  }
}

class _GraphEdge {
  const _GraphEdge(this.from, this.to);
  final int from;
  final int to;
}

// ---------------------------------------------------------------------------
// Force-directed simulation parameters.
// ---------------------------------------------------------------------------

const double _kRepulsion = 8000;
const double _kSpringK = 0.012;
const double _kSpringLen = 140;
const double _kLeafSpringLen = 110;
const double _kDamping = 0.85;
const double _kMinVelocity = 0.05;
const double _kMaxForce = 80;
const double _kCentreGravity = 0.0008;

// ---------------------------------------------------------------------------
// Obsidian-style knowledge graph screen.
// ---------------------------------------------------------------------------

class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends ConsumerState<KnowledgeGraphScreen>
    with SingleTickerProviderStateMixin {
  final _service = PersonalKnowledgeService();
  PersonalKnowledge? _knowledge;
  late final AnimationController _ticker;
  final _zoom = TransformationController();
  bool _loading = true;
  String? _error;

  // Force-directed graph state.
  List<_GraphNode> _nodes = [];
  List<_GraphEdge> _edges = [];
  int? _selectedNode;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _ticker.addListener(_stepSimulation);
    _load();
  }

  @override
  void dispose() {
    _ticker.removeListener(_stepSimulation);
    _ticker.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _resetCamera() {
    _zoom.value = Matrix4.identity();
    HapticFeedback.selectionClick();
  }

  // ======================== data loading ========================

  Future<void> _load() async {
    try {
      final k = await _service.load();
      if (!mounted) return;
      setState(() {
        _knowledge = k;
        _loading = false;
      });
      _rebuildGraph();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ======================== graph construction ========================

  void _rebuildGraph() {
    final k = _knowledge;
    if (k == null) return;

    final entries =
        ref.read(entriesProvider).valueOrNull ?? const <Entry>[];
    final recentNotes = entries
        .where((e) => e.kind == EntryKind.note && !e.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentTasks = entries
        .where(
            (e) => e.kind == EntryKind.task && e.isCompleted && !e.isDeleted)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));

    final rng = math.Random(42);
    final nodes = <_GraphNode>[];
    final edges = <_GraphEdge>[];

    // Centre node.
    nodes.add(_GraphNode(
      id: '__centre__',
      label: k.summary.isEmpty ? 'я' : k.summary,
      branch: null,
      isCentre: true,
      isBranchHeader: false,
      position: Offset.zero,
    ));

    final branchItems = <_Branch, List<String>>{};
    for (final b in _Branch.values) {
      switch (b) {
        case _Branch.goals:
          branchItems[b] = k.goals;
        case _Branch.constraints:
          branchItems[b] = k.constraints;
        case _Branch.highlights:
          branchItems[b] = k.completedHighlights;
        case _Branch.reflections:
          branchItems[b] = k.recentReflections;
        case _Branch.preferences:
          branchItems[b] = [
            for (final e in k.preferences.entries) '${e.key}: ${e.value}',
          ];
        case _Branch.notes:
          branchItems[b] = [
            for (final e in recentNotes.take(6))
              e.title.isEmpty
                  ? (e.body.length > 32
                      ? '${e.body.substring(0, 32)}…'
                      : e.body)
                  : e.title,
          ];
        case _Branch.tasks:
          branchItems[b] = [for (final e in recentTasks.take(6)) e.title];
      }
    }

    // Branch header nodes + leaf nodes.
    final branchCount = _Branch.values.length;
    for (var bi = 0; bi < branchCount; bi++) {
      final b = _Branch.values[bi];
      final angle = bi * 2 * math.pi / branchCount - math.pi / 2;
      final headerIdx = nodes.length;
      nodes.add(_GraphNode(
        id: '__branch_${b.name}__',
        label: b.title,
        branch: b,
        isCentre: false,
        isBranchHeader: true,
        position: Offset(
          math.cos(angle) * 200 + rng.nextDouble() * 20 - 10,
          math.sin(angle) * 200 + rng.nextDouble() * 20 - 10,
        ),
      ));
      edges.add(_GraphEdge(0, headerIdx));

      final items = branchItems[b]!;
      nodes[headerIdx].childCount = items.length;
      for (var li = 0; li < items.length; li++) {
        final leafAngle = angle +
            (li - items.length / 2) * 0.35;
        final leafIdx = nodes.length;
        nodes.add(_GraphNode(
          id: '__leaf_${b.name}_$li',
          label: items[li],
          branch: b,
          isCentre: false,
          isBranchHeader: false,
          leafIndex: li,
          position: Offset(
            math.cos(leafAngle) * 340 + rng.nextDouble() * 30 - 15,
            math.sin(leafAngle) * 340 + rng.nextDouble() * 30 - 15,
          ),
        ));
        edges.add(_GraphEdge(headerIdx, leafIdx));
      }
    }

    _nodes = nodes;
    _edges = edges;
    _settled = false;
  }

  // ======================== physics simulation ========================

  void _stepSimulation() {
    if (_nodes.length < 2 || _settled) return;

    final n = _nodes.length;
    final forces = List<Offset>.filled(n, Offset.zero);
    final canvasCenter = Offset.zero;

    // Repulsion (all pairs).
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var delta = _nodes[i].pos - _nodes[j].pos;
        var dist = delta.distance;
        if (dist < 1) {
          delta = Offset(math.Random().nextDouble() - 0.5,
              math.Random().nextDouble() - 0.5);
          dist = 1;
        }
        final force = _kRepulsion / (dist * dist);
        final clamped = math.min(force, _kMaxForce);
        final f = delta / dist * clamped;
        forces[i] = forces[i] + f;
        forces[j] = forces[j] - f;
      }
    }

    // Spring attraction (edges).
    for (final edge in _edges) {
      final a = _nodes[edge.from];
      final b = _nodes[edge.to];
      final delta = b.pos - a.pos;
      final dist = delta.distance;
      if (dist < 1) continue;
      final restLen =
          (a.isBranchHeader || b.isBranchHeader) && !(a.isCentre || b.isCentre)
              ? _kLeafSpringLen
              : _kSpringLen;
      final displacement = dist - restLen;
      final force = _kSpringK * displacement;
      final clamped =
          force.abs() > _kMaxForce ? _kMaxForce * force.sign : force;
      final f = delta / dist * clamped;
      forces[edge.from] = forces[edge.from] + f;
      forces[edge.to] = forces[edge.to] - f;
    }

    // Gravity toward centre.
    for (var i = 0; i < n; i++) {
      final toCenter = canvasCenter - _nodes[i].pos;
      forces[i] = forces[i] + toCenter * _kCentreGravity;
    }

    // Apply forces, velocity, and damping.
    var totalKinetic = 0.0;
    for (var i = 0; i < n; i++) {
      if (_nodes[i].pinned) continue;
      _nodes[i].vel = (_nodes[i].vel + forces[i]) * _kDamping;
      _nodes[i].pos = _nodes[i].pos + _nodes[i].vel;
      totalKinetic += _nodes[i].vel.distanceSquared;
    }

    if (totalKinetic < _kMinVelocity * n) {
      _settled = true;
    }

    if (mounted) setState(() {});
  }

  // ======================== editing helpers (unchanged) ========================

  Future<void> _editSummary(String current) async {
    final next = await _editSheet(
      title: 'О тебе',
      hint: 'Кратко: кто ты, чем занят, что важно',
      initial: current,
      maxLines: 4,
    );
    if (next == null || _knowledge == null) return;
    final upd = _knowledge!.copyWith(summary: next, updatedAt: DateTime.now());
    await _service.save(upd);
    if (mounted) {
      setState(() => _knowledge = upd);
      _rebuildGraph();
    }
  }

  Future<void> _editList({
    required String title,
    required String hint,
    required List<String> items,
    required PersonalKnowledge Function(List<String> next) apply,
    int maxItems = 12,
  }) async {
    final next = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => _EditListScreen(
          title: title,
          hint: hint,
          initial: items,
          maxItems: maxItems,
        ),
      ),
    );
    if (next == null || _knowledge == null) return;
    final upd = apply(next);
    await _service.save(upd);
    if (mounted) {
      setState(() => _knowledge = upd);
      _rebuildGraph();
    }
  }

  Future<void> _editLeaf({
    required String branch,
    required int index,
    required List<String> source,
    required PersonalKnowledge Function(List<String> next) apply,
  }) async {
    final next = await _editSheet(
      title: branch,
      hint: 'Опиши коротко',
      initial: source[index],
      maxLines: 3,
      allowDelete: true,
    );
    if (next == null || _knowledge == null) return;
    final updated = [...source];
    if (next.isEmpty) {
      updated.removeAt(index);
    } else {
      updated[index] = next;
    }
    final upd = apply(updated);
    await _service.save(upd);
    if (mounted) {
      setState(() => _knowledge = upd);
      _rebuildGraph();
    }
  }

  Future<String?> _editSheet({
    required String title,
    required String hint,
    required String initial,
    int maxLines = 1,
    bool allowDelete = false,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final palette = context.palette;
    final r = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, pad + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 36,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: palette.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: palette.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 1,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.line),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (allowDelete)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(const _EditResult(value: '')),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить'),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.fg,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(
                      _EditResult(value: ctrl.text.trim()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.fg,
                      foregroundColor: palette.bg,
                    ),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return r?.value;
  }

  // ======================== tap handling ========================

  void _onTapNode(_GraphNode node) {
    HapticFeedback.selectionClick();
    if (node.isCentre) {
      _editSummary(_knowledge!.summary);
      return;
    }
    if (node.isBranchHeader) {
      _onTapBranch(node.branch!);
      return;
    }
    _onTapLeaf(node.branch!, node.leafIndex);
  }

  void _onTapBranch(_Branch branch) {
    switch (branch) {
      case _Branch.goals:
        _editList(
          title: 'Цели',
          hint: 'Что хочешь достичь',
          items: _knowledge!.goals,
          apply: (n) =>
              _knowledge!.copyWith(goals: n, updatedAt: DateTime.now()),
        );
      case _Branch.constraints:
        _editList(
          title: 'Ограничения',
          hint: 'Что мешает или ограничивает',
          items: _knowledge!.constraints,
          apply: (n) =>
              _knowledge!.copyWith(constraints: n, updatedAt: DateTime.now()),
        );
      case _Branch.highlights:
        _editList(
          title: 'Достижения',
          hint: 'Что уже получилось',
          items: _knowledge!.completedHighlights,
          maxItems: 20,
          apply: (n) => _knowledge!.copyWith(
              completedHighlights: n, updatedAt: DateTime.now()),
        );
      case _Branch.reflections:
        _editList(
          title: 'Рефлексии',
          hint: 'Заметки о пройденном',
          items: _knowledge!.recentReflections,
          maxItems: 10,
          apply: (n) => _knowledge!.copyWith(
              recentReflections: n, updatedAt: DateTime.now()),
        );
      case _Branch.preferences:
        final prefs = _knowledge!.preferences;
        final flat = [
          for (final e in prefs.entries) '${e.key}: ${e.value}',
        ];
        _editList(
          title: 'Предпочтения',
          hint: 'ключ: значение',
          items: flat,
          apply: (n) {
            final m = <String, String>{};
            for (final line in n) {
              final i = line.indexOf(':');
              if (i <= 0 || i >= line.length - 1) {
                m[line.trim()] = '';
              } else {
                m[line.substring(0, i).trim()] = line.substring(i + 1).trim();
              }
            }
            return _knowledge!
                .copyWith(preferences: m, updatedAt: DateTime.now());
          },
        );
      case _Branch.notes:
      case _Branch.tasks:
        break;
    }
  }

  void _onTapLeaf(_Branch branch, int index) {
    final entries =
        ref.read(entriesProvider).valueOrNull ?? const <Entry>[];
    final notesEntries = entries
        .where((e) => e.kind == EntryKind.note && !e.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final tasksEntries = entries
        .where(
            (e) => e.kind == EntryKind.task && e.isCompleted && !e.isDeleted)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));

    switch (branch) {
      case _Branch.goals:
        _editLeaf(
          branch: 'Цель',
          index: index,
          source: _knowledge!.goals,
          apply: (n) =>
              _knowledge!.copyWith(goals: n, updatedAt: DateTime.now()),
        );
      case _Branch.constraints:
        _editLeaf(
          branch: 'Ограничение',
          index: index,
          source: _knowledge!.constraints,
          apply: (n) =>
              _knowledge!.copyWith(constraints: n, updatedAt: DateTime.now()),
        );
      case _Branch.highlights:
        _editLeaf(
          branch: 'Достижение',
          index: index,
          source: _knowledge!.completedHighlights,
          apply: (n) => _knowledge!.copyWith(
              completedHighlights: n, updatedAt: DateTime.now()),
        );
      case _Branch.reflections:
        _editLeaf(
          branch: 'Рефлексия',
          index: index,
          source: _knowledge!.recentReflections,
          apply: (n) => _knowledge!.copyWith(
              recentReflections: n, updatedAt: DateTime.now()),
        );
      case _Branch.preferences:
        _onTapBranch(branch);
      case _Branch.notes:
        if (index < notesEntries.length) {
          showEntryEditor(context, ref, existing: notesEntries[index]);
        }
      case _Branch.tasks:
        if (index < tasksEntries.length) {
          showEntryEditor(context, ref, existing: tasksEntries[index]);
        }
    }
  }

  // ======================== build ========================

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Rebuild graph when entries change.
    ref.listen(entriesProvider, (_, __) => _rebuildGraph());

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('База знаний'),
        actions: [
          IconButton(
            tooltip: 'Сводка о тебе',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _knowledge == null
                ? null
                : () => _editSummary(_knowledge!.summary),
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'reset',
                  tooltip: 'Сбросить вид',
                  onPressed: _resetCamera,
                  child: const Icon(Icons.fit_screen_outlined),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'shake',
                  tooltip: 'Перемешать',
                  onPressed: () {
                    final rng = math.Random();
                    for (final node in _nodes) {
                      node.vel += Offset(
                        rng.nextDouble() * 40 - 20,
                        rng.nextDouble() * 40 - 20,
                      );
                    }
                    _settled = false;
                  },
                  child: const Icon(Icons.shuffle_rounded),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _nodes.isEmpty
                  ? const Center(child: Text('База знаний пуста'))
                  : SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final viewSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return InteractiveViewer(
                            transformationController: _zoom,
                            minScale: 0.15,
                            maxScale: 5.0,
                            boundaryMargin: const EdgeInsets.all(2000),
                            child: SizedBox(
                              width: math.max(1600, viewSize.width * 3),
                              height: math.max(1600, viewSize.height * 3),
                              child: _ObsidianGraphView(
                                nodes: _nodes,
                                edges: _edges,
                                zoom: _zoom,
                                selectedNode: _selectedNode,
                                onTapNode: (i) {
                                  setState(() => _selectedNode =
                                      _selectedNode == i ? null : i);
                                  _onTapNode(_nodes[i]);
                                },
                                onDragStart: (i) {
                                  _nodes[i].pinned = true;
                                  _settled = false;
                                },
                                onDragUpdate: (i, delta) {
                                  final scale =
                                      _zoom.value.getMaxScaleOnAxis();
                                  _nodes[i].pos += delta / scale;
                                  _nodes[i].vel = Offset.zero;
                                  _settled = false;
                                  setState(() {});
                                },
                                onDragEnd: (i) {
                                  _nodes[i].pinned = false;
                                },
                                palette: palette,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Obsidian-style graph view widget.
// ---------------------------------------------------------------------------

class _ObsidianGraphView extends StatelessWidget {
  const _ObsidianGraphView({
    required this.nodes,
    required this.edges,
    required this.zoom,
    required this.selectedNode,
    required this.onTapNode,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.palette,
  });

  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final TransformationController zoom;
  final int? selectedNode;
  final ValueChanged<int> onTapNode;
  final ValueChanged<int> onDragStart;
  final void Function(int, Offset) onDragUpdate;
  final ValueChanged<int> onDragEnd;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final canvasCentre =
            Offset(canvasSize.width / 2, canvasSize.height / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Edges + ambient glow painted on a canvas.
            CustomPaint(
              size: canvasSize,
              painter: _ObsidianEdgePainter(
                nodes: nodes,
                edges: edges,
                centre: canvasCentre,
                palette: palette,
                selectedNode: selectedNode,
              ),
            ),
            // Nodes as positioned widgets.
            for (var i = 0; i < nodes.length; i++)
              _PositionedNode(
                node: nodes[i],
                canvasCentre: canvasCentre,
                palette: palette,
                isSelected: selectedNode == i,
                onTap: () => onTapNode(i),
                onDragStart: () => onDragStart(i),
                onDragUpdate: (delta) => onDragUpdate(i, delta),
                onDragEnd: () => onDragEnd(i),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Positioned node widget.
// ---------------------------------------------------------------------------

class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.node,
    required this.canvasCentre,
    required this.palette,
    required this.isSelected,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final _GraphNode node;
  final Offset canvasCentre;
  final NoeticaPalette palette;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenPos = canvasCentre + node.pos;
    final r = node.radius;
    final color = node.isCentre
        ? palette.fg
        : (node.branch?.color ?? palette.fg);

    // Determine the label area. For the centre, show it below the node.
    // For branch headers, show it beside. For leaves, show on hover/select.
    final showLabel = node.isCentre || node.isBranchHeader || isSelected;

    final hitSize = math.max(r * 2 + 16, 44.0);

    return Positioned(
      left: screenPos.dx - hitSize / 2,
      top: screenPos.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (d) => onDragUpdate(d.delta),
        onPanEnd: (_) => onDragEnd(),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Glow behind node.
            Container(
              width: r * 2 + (isSelected ? 12 : 6),
              height: r * 2 + (isSelected ? 12 : 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isSelected ? 0.5 : 0.2),
                    blurRadius: isSelected ? 20 : 10,
                    spreadRadius: isSelected ? 4 : 1,
                  ),
                ],
              ),
            ),
            // Node circle.
            Container(
              width: r * 2,
              height: r * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: node.isCentre
                    ? color
                    : color.withOpacity(isSelected ? 1.0 : 0.85),
                border: Border.all(
                  color: color.withOpacity(0.9),
                  width: node.isCentre ? 2 : 1.5,
                ),
              ),
            ),
            // Label.
            if (showLabel)
              Positioned(
                top: hitSize / 2 + r + 4,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: node.isCentre ? 120 : 100,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.bg.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.isCentre
                        ? 'я'
                        : (node.isBranchHeader
                            ? '${node.label} · ${node.childCount}'
                            : node.label),
                    textAlign: TextAlign.center,
                    maxLines: node.isBranchHeader ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: node.isBranchHeader ? color : palette.fg,
                      fontSize: node.isCentre ? 12 : 10,
                      fontWeight: node.isBranchHeader
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


}

// ---------------------------------------------------------------------------
// Edge painter — draws lines + ambient particle glow.
// ---------------------------------------------------------------------------

class _ObsidianEdgePainter extends CustomPainter {
  _ObsidianEdgePainter({
    required this.nodes,
    required this.edges,
    required this.centre,
    required this.palette,
    required this.selectedNode,
  });

  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final Offset centre;
  final NoeticaPalette palette;
  final int? selectedNode;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges.
    for (final edge in edges) {
      final a = nodes[edge.from];
      final b = nodes[edge.to];
      final posA = centre + a.pos;
      final posB = centre + b.pos;

      final isHighlighted = selectedNode != null &&
          (edge.from == selectedNode || edge.to == selectedNode);

      final color =
          (b.branch?.color ?? a.branch?.color ?? palette.muted);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 1.8 : 0.8
        ..color = color.withOpacity(isHighlighted ? 0.6 : 0.15);

      canvas.drawLine(posA, posB, paint);
    }

    // Ambient dots (background particles for atmosphere).
    final rng = math.Random(7);
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      dotPaint.color = palette.muted.withOpacity(0.04 + rng.nextDouble() * 0.04);
      canvas.drawCircle(Offset(x, y), 1.0 + rng.nextDouble() * 1.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ObsidianEdgePainter old) => true;
}

// ---------------------------------------------------------------------------
// Supporting types.
// ---------------------------------------------------------------------------

class _EditResult {
  const _EditResult({required this.value});
  final String value;
}

// ---------------------------------------------------------------------------
// Edit-list screen (unchanged from original).
// ---------------------------------------------------------------------------

class _EditListScreen extends StatefulWidget {
  const _EditListScreen({
    required this.title,
    required this.hint,
    required this.initial,
    required this.maxItems,
  });

  final String title;
  final String hint;
  final List<String> initial;
  final int maxItems;

  @override
  State<_EditListScreen> createState() => _EditListScreenState();
}

class _EditListScreenState extends State<_EditListScreen> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = [
      for (final s in widget.initial) TextEditingController(text: s),
    ];
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _ctrls.length >= widget.maxItems
                ? null
                : () => setState(() => _ctrls.add(TextEditingController())),
            child: const Text('+ ещё'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (var i = 0; i < _ctrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrls[i],
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: palette.line),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      _ctrls[i].dispose();
                      _ctrls.removeAt(i);
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(
          [
            for (final c in _ctrls)
              if (c.text.trim().isNotEmpty) c.text.trim(),
          ],
        ),
        backgroundColor: palette.fg,
        foregroundColor: palette.bg,
        icon: const Icon(Icons.check),
        label: const Text('Сохранить'),
      ),
    );
  }
}
