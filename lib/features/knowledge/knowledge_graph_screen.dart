import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_editor_sheet.dart';

// ---------------------------------------------------------------------------
// Graph node — a single point in the force-directed simulation.
// ---------------------------------------------------------------------------

class _GraphNode {
  _GraphNode({
    required this.id,
    required this.label,
    required this.color,
    required this.isCentre,
    this.entry,
    this.isBookmarked = false,
    this.tags = const [],
    Offset? position,
  })  : pos = position ?? Offset.zero,
        vel = Offset.zero;

  final String id;
  final String label;
  final Color color;
  final bool isCentre;
  final Entry? entry;
  final bool isBookmarked;
  final List<String> tags;
  int linkCount = 0;
  Offset pos;
  Offset vel;
  bool pinned = false;

  double get radius {
    if (isCentre) return 16;
    if (isBookmarked) return 13;
    final base = 6.0 + math.min(linkCount * 1.5, 8.0);
    return base;
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
const double _kDamping = 0.85;
const double _kMinVelocity = 0.05;
const double _kMaxForce = 80;
const double _kCentreGravity = 0.0008;

// ---------------------------------------------------------------------------
// Color palette for entry types.
// ---------------------------------------------------------------------------

Color _entryColor(Entry? e) {
  if (e == null) return const Color(0xFFAAAAAA);
  if (e.bookmarked) return const Color(0xFFF59E0B);
  if (e.tags.contains('daily')) return const Color(0xFF3B82F6);
  if (e.isTask) return const Color(0xFF06B6D4);
  return const Color(0xFF10B981);
}

// ---------------------------------------------------------------------------
// Filter modes.
// ---------------------------------------------------------------------------

enum _FilterMode { all, notes, tasks, bookmarks, daily }

extension on _FilterMode {
  String get label {
    switch (this) {
      case _FilterMode.all:
        return 'Все';
      case _FilterMode.notes:
        return 'Заметки';
      case _FilterMode.tasks:
        return 'Задачи';
      case _FilterMode.bookmarks:
        return 'Закладки';
      case _FilterMode.daily:
        return 'Дневник';
    }
  }

  IconData get icon {
    switch (this) {
      case _FilterMode.all:
        return Icons.blur_on;
      case _FilterMode.notes:
        return Icons.note_outlined;
      case _FilterMode.tasks:
        return Icons.checklist;
      case _FilterMode.bookmarks:
        return Icons.bookmark_outline;
      case _FilterMode.daily:
        return Icons.today;
    }
  }
}

// ---------------------------------------------------------------------------
// Knowledge Graph Screen — Obsidian-style "Second Brain".
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
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;

  // Graph state.
  List<_GraphNode> _nodes = [];
  List<_GraphEdge> _edges = [];
  int? _selectedNode;
  bool _settled = false;

  // Filters.
  _FilterMode _filter = _FilterMode.all;
  String? _activeTag;
  String? _localGraphCentreId;
  bool _searchVisible = false;
  List<Entry> _searchResults = [];

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
    _searchController.dispose();
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

  Future<void> _rebuildGraph() async {
    final entries =
        ref.read(entriesProvider).valueOrNull ?? const <Entry>[];
    final repo = await ref.read(repositoryProvider.future);

    // Get all links from DB.
    final links = await repo.allLinks();

    // Filter entries based on current filter mode.
    var filtered = entries.where((e) => !e.isDeleted).toList();

    switch (_filter) {
      case _FilterMode.all:
        break;
      case _FilterMode.notes:
        filtered = filtered.where((e) => e.kind == EntryKind.note).toList();
      case _FilterMode.tasks:
        filtered = filtered.where((e) => e.kind == EntryKind.task).toList();
      case _FilterMode.bookmarks:
        filtered = filtered.where((e) => e.bookmarked).toList();
      case _FilterMode.daily:
        filtered =
            filtered.where((e) => e.tags.contains('daily')).toList();
    }

    if (_activeTag != null) {
      filtered =
          filtered.where((e) => e.tags.contains(_activeTag)).toList();
    }

    // Local graph: only show nodes within 2 hops of selected node.
    Set<String>? localIds;
    if (_localGraphCentreId != null) {
      localIds = {_localGraphCentreId!};
      final first = links
          .where((l) =>
              l.source == _localGraphCentreId ||
              l.target == _localGraphCentreId)
          .expand((l) => [l.source, l.target])
          .toSet();
      localIds.addAll(first);
      for (final id in first) {
        final second = links
            .where((l) => l.source == id || l.target == id)
            .expand((l) => [l.source, l.target])
            .toSet();
        localIds.addAll(second);
      }
      filtered = filtered.where((e) => localIds!.contains(e.id)).toList();
    }

    final rng = math.Random(42);
    final nodes = <_GraphNode>[];
    final graphEdges = <_GraphEdge>[];

    // Centre node (user summary from PersonalKnowledge).
    final k = _knowledge;
    nodes.add(_GraphNode(
      id: '__centre__',
      label: k?.summary.isEmpty != false ? 'я' : k!.summary,
      color: const Color(0xFFFFFFFF),
      isCentre: true,
      position: Offset.zero,
    ));

    // Map entry IDs to node indices.
    final idToIndex = <String, int>{};

    // Add entry nodes.
    for (var i = 0; i < filtered.length; i++) {
      final e = filtered[i];
      final angle = i * 2 * math.pi / math.max(filtered.length, 1);
      final dist = 150.0 + rng.nextDouble() * 100;
      final idx = nodes.length;
      idToIndex[e.id] = idx;
      nodes.add(_GraphNode(
        id: e.id,
        label: e.title.isEmpty
            ? (e.body.length > 30 ? '${e.body.substring(0, 30)}…' : e.body)
            : e.title,
        color: _entryColor(e),
        isCentre: false,
        entry: e,
        isBookmarked: e.bookmarked,
        tags: e.tags,
        position: Offset(
          math.cos(angle) * dist + rng.nextDouble() * 20 - 10,
          math.sin(angle) * dist + rng.nextDouble() * 20 - 10,
        ),
      ));
    }

    // Add edges from entry_links.
    for (final link in links) {
      final si = idToIndex[link.source];
      final ti = idToIndex[link.target];
      if (si != null && ti != null) {
        graphEdges.add(_GraphEdge(si, ti));
        nodes[si].linkCount++;
        nodes[ti].linkCount++;
      }
    }

    // Connect orphan nodes to the centre with weak springs so they don't
    // float off into the void.
    final connectedNodeIndices = <int>{};
    for (final e in graphEdges) {
      connectedNodeIndices.add(e.from);
      connectedNodeIndices.add(e.to);
    }
    for (var i = 1; i < nodes.length; i++) {
      if (!connectedNodeIndices.contains(i)) {
        graphEdges.add(_GraphEdge(0, i));
      }
    }

    setState(() {
      _nodes = nodes;
      _edges = graphEdges;
      _selectedNode = null;
    });
    _settled = false;
  }

  // ======================== physics simulation ========================

  void _stepSimulation() {
    if (_nodes.length < 2 || _settled) return;

    final n = _nodes.length;
    final forces = List<Offset>.filled(n, Offset.zero);
    const canvasCenter = Offset.zero;

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

    for (final edge in _edges) {
      final a = _nodes[edge.from];
      final b = _nodes[edge.to];
      final delta = b.pos - a.pos;
      final dist = delta.distance;
      if (dist < 1) continue;
      final displacement = dist - _kSpringLen;
      final force = _kSpringK * displacement;
      final clamped =
          force.abs() > _kMaxForce ? _kMaxForce * force.sign : force;
      final f = delta / dist * clamped;
      forces[edge.from] = forces[edge.from] + f;
      forces[edge.to] = forces[edge.to] - f;
    }

    for (var i = 0; i < n; i++) {
      final toCenter = canvasCenter - _nodes[i].pos;
      forces[i] = forces[i] + toCenter * _kCentreGravity;
    }

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

  // ======================== search ========================

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final repo = await ref.read(repositoryProvider.future);
    final results = await repo.searchEntries(query);
    if (mounted) setState(() => _searchResults = results);
  }

  // ======================== daily note ========================

  Future<void> _openDailyNote() async {
    final repo = await ref.read(repositoryProvider.future);
    final daily = await repo.getOrCreateDailyNote();
    if (!mounted) return;
    await showEntryEditor(context, ref, existing: daily);
    _rebuildGraph();
  }

  // ======================== create note ========================

  Future<void> _createNote() async {
    await showEntryEditor(context, ref, initialKind: EntryKind.note);
    _rebuildGraph();
  }

  // ======================== node tap ========================

  void _onTapNode(_GraphNode node) {
    HapticFeedback.selectionClick();
    if (node.isCentre) {
      _editSummary(_knowledge?.summary ?? '');
      return;
    }
    if (node.entry != null) {
      showEntryEditor(context, ref, existing: node.entry).then((_) {
        _syncBodyLinks(node.entry!);
        _rebuildGraph();
      });
    }
  }

  Future<void> _syncBodyLinks(Entry entry) async {
    final repo = await ref.read(repositoryProvider.future);
    // Re-read the entry to get the latest body.
    final entries = await repo.listEntries();
    final updated = entries.where((e) => e.id == entry.id).firstOrNull;
    if (updated != null) {
      await repo.syncBodyLinks(updated);
    }
  }

  // ======================== bookmark toggle ========================

  Future<void> _toggleBookmark(Entry entry) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.toggleBookmark(entry);
    _rebuildGraph();
  }

  // ======================== local graph toggle ========================

  void _toggleLocalGraph(String entryId) {
    setState(() {
      if (_localGraphCentreId == entryId) {
        _localGraphCentreId = null;
      } else {
        _localGraphCentreId = entryId;
      }
    });
    _rebuildGraph();
  }

  // ======================== editing helpers ========================

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

  // ======================== build ========================

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    ref.listen(entriesProvider, (_, __) => _rebuildGraph());

    // Collect all unique tags for the filter menu.
    final allEntries =
        ref.watch(entriesProvider).valueOrNull ?? const <Entry>[];
    final allTags = <String>{};
    for (final e in allEntries) {
      allTags.addAll(e.tags);
    }
    final sortedTags = allTags.toList()..sort();

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: palette.fg),
                decoration: InputDecoration(
                  hintText: 'Поиск по базе знаний…',
                  hintStyle: TextStyle(color: palette.muted),
                  border: InputBorder.none,
                ),
                onChanged: _performSearch,
              )
            : const Text('База знаний'),
        actions: [
          IconButton(
            tooltip: 'Поиск',
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Дневник',
            icon: const Icon(Icons.today),
            onPressed: _openDailyNote,
          ),
          if (_localGraphCentreId != null)
            IconButton(
              tooltip: 'Глобальный граф',
              icon: const Icon(Icons.public),
              onPressed: () {
                setState(() => _localGraphCentreId = null);
                _rebuildGraph();
              },
            ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'new_note',
                  tooltip: 'Новая заметка',
                  onPressed: _createNote,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
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
              : Column(
                  children: [
                    // Filter bar.
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final f in _FilterMode.values)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: FilterChip(
                                selected: _filter == f && _activeTag == null,
                                label: Text(f.label),
                                avatar: Icon(f.icon, size: 16),
                                onSelected: (_) {
                                  setState(() {
                                    _filter = f;
                                    _activeTag = null;
                                  });
                                  _rebuildGraph();
                                },
                                selectedColor:
                                    palette.fg.withOpacity(0.15),
                                checkmarkColor: palette.fg,
                                labelStyle:
                                    TextStyle(color: palette.fg, fontSize: 12),
                              ),
                            ),
                          if (sortedTags.isNotEmpty)
                            const VerticalDivider(width: 16),
                          for (final tag in sortedTags)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: FilterChip(
                                selected: _activeTag == tag,
                                label: Text('#$tag'),
                                onSelected: (_) {
                                  setState(() {
                                    _activeTag =
                                        _activeTag == tag ? null : tag;
                                  });
                                  _rebuildGraph();
                                },
                                selectedColor:
                                    palette.fg.withOpacity(0.15),
                                checkmarkColor: palette.fg,
                                labelStyle:
                                    TextStyle(color: palette.fg, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Search results overlay.
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.line),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) {
                            final e = _searchResults[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                e.isTask
                                    ? Icons.checklist
                                    : Icons.note_outlined,
                                color: _entryColor(e),
                                size: 20,
                              ),
                              title: Text(
                                e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: palette.fg, fontSize: 13),
                              ),
                              subtitle: e.tags.isEmpty
                                  ? null
                                  : Text(
                                      e.tags.map((t) => '#$t').join(' '),
                                      style: TextStyle(
                                          color: palette.muted,
                                          fontSize: 11),
                                    ),
                              trailing: IconButton(
                                icon: Icon(
                                  e.bookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  size: 18,
                                  color: e.bookmarked
                                      ? const Color(0xFFF59E0B)
                                      : palette.muted,
                                ),
                                onPressed: () => _toggleBookmark(e),
                              ),
                              onTap: () {
                                showEntryEditor(context, ref, existing: e)
                                    .then((_) => _rebuildGraph());
                              },
                            );
                          },
                        ),
                      ),
                    // Graph view.
                    Expanded(
                      child: _nodes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_graph,
                                      size: 48, color: palette.muted),
                                  const SizedBox(height: 12),
                                  Text(
                                    'База знаний пуста\nСоздайте первую заметку',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: palette.muted),
                                  ),
                                ],
                              ),
                            )
                          : SafeArea(
                              top: false,
                              child: AnimatedBuilder(
                                animation: _zoom,
                                builder: (context, _) {
                                  final zoomScale =
                                      _zoom.value.getMaxScaleOnAxis();
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final viewSize = Size(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      );
                                      return InteractiveViewer(
                                        transformationController: _zoom,
                                        minScale: 0.15,
                                        maxScale: 5.0,
                                        boundaryMargin:
                                            const EdgeInsets.all(2000),
                                        child: SizedBox(
                                          width: math.max(
                                              1600, viewSize.width * 3),
                                          height: math.max(
                                              1600, viewSize.height * 3),
                                          child: _ObsidianGraphView(
                                            nodes: _nodes,
                                            edges: _edges,
                                            zoomScale: zoomScale,
                                            selectedNode: _selectedNode,
                                            onTapNode: (i) {
                                              setState(() =>
                                                  _selectedNode =
                                                      _selectedNode == i
                                                          ? null
                                                          : i);
                                              _onTapNode(_nodes[i]);
                                            },
                                            onDragStart: (i) {
                                              _nodes[i].pinned = true;
                                              _settled = false;
                                            },
                                            onDragUpdate: (i, delta) {
                                              final scale = _zoom.value
                                                  .getMaxScaleOnAxis();
                                              _nodes[i].pos +=
                                                  delta / scale;
                                              _nodes[i].vel = Offset.zero;
                                              _settled = false;
                                              setState(() {});
                                            },
                                            onDragEnd: (i) {
                                              _nodes[i].pinned = false;
                                            },
                                            onBookmark: (i) {
                                              final node = _nodes[i];
                                              if (node.entry != null) {
                                                _toggleBookmark(node.entry!);
                                              }
                                            },
                                            onLocalGraph: (i) {
                                              final node = _nodes[i];
                                              if (!node.isCentre) {
                                                _toggleLocalGraph(node.id);
                                              }
                                            },
                                            palette: palette,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
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
    required this.zoomScale,
    required this.selectedNode,
    required this.onTapNode,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBookmark,
    required this.onLocalGraph,
    required this.palette,
  });

  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final double zoomScale;
  final int? selectedNode;
  final ValueChanged<int> onTapNode;
  final ValueChanged<int> onDragStart;
  final void Function(int, Offset) onDragUpdate;
  final ValueChanged<int> onDragEnd;
  final ValueChanged<int> onBookmark;
  final ValueChanged<int> onLocalGraph;
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
            for (var i = 0; i < nodes.length; i++)
              _PositionedNode(
                node: nodes[i],
                canvasCentre: canvasCentre,
                palette: palette,
                zoomScale: zoomScale,
                isSelected: selectedNode == i,
                onTap: () => onTapNode(i),
                onDragStart: () => onDragStart(i),
                onDragUpdate: (delta) => onDragUpdate(i, delta),
                onDragEnd: () => onDragEnd(i),
                onBookmark: () => onBookmark(i),
                onLocalGraph: () => onLocalGraph(i),
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
    required this.zoomScale,
    required this.isSelected,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBookmark,
    required this.onLocalGraph,
  });

  final _GraphNode node;
  final Offset canvasCentre;
  final NoeticaPalette palette;
  final double zoomScale;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onBookmark;
  final VoidCallback onLocalGraph;

  static const double _expandThreshold = 1.8;

  @override
  Widget build(BuildContext context) {
    final screenPos = canvasCentre + node.pos;
    final r = node.radius;
    final color = node.color;

    final expanded = zoomScale >= _expandThreshold && !node.isCentre;
    final showLabel = node.isCentre || isSelected || expanded;

    final cardW = expanded ? 160.0 : 0.0;
    final cardH = expanded ? 36.0 : 0.0;
    final hitSize = expanded
        ? math.max(cardW, 44.0)
        : math.max(r * 2 + 16, 44.0);
    final hitHeight = expanded ? math.max(cardH + 8, 44.0) : hitSize;

    if (expanded) {
      return Positioned(
        left: screenPos.dx - hitSize / 2,
        top: screenPos.dy - hitHeight / 2,
        width: hitSize,
        height: hitHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onBookmark,
          onPanStart: (_) => onDragStart(),
          onPanUpdate: (d) => onDragUpdate(d.delta),
          onPanEnd: (_) => onDragEnd(),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: cardW),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color.withOpacity(isSelected ? 0.9 : 0.5),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.isBookmarked)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.bookmark,
                          size: 12, color: const Color(0xFFF59E0B)),
                    ),
                  Flexible(
                    child: Text(
                      node.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (node.linkCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${node.linkCount}',
                        style: TextStyle(
                          color: color.withOpacity(0.6),
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: screenPos.dx - hitSize / 2,
      top: screenPos.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onBookmark,
        onDoubleTap: onLocalGraph,
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (d) => onDragUpdate(d.delta),
        onPanEnd: (_) => onDragEnd(),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
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
              child: node.isBookmarked
                  ? const Center(
                      child: Icon(Icons.bookmark,
                          size: 10, color: Colors.white),
                    )
                  : null,
            ),
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
                    node.isCentre ? 'я' : node.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: node.isCentre ? 12 : 10,
                      fontWeight: FontWeight.w400,
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
// Edge painter.
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
    for (final edge in edges) {
      final a = nodes[edge.from];
      final b = nodes[edge.to];
      final posA = centre + a.pos;
      final posB = centre + b.pos;

      final isHighlighted = selectedNode != null &&
          (edge.from == selectedNode || edge.to == selectedNode);

      final color = b.color;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.5 : 1.2
        ..color = color.withOpacity(isHighlighted ? 0.75 : 0.35);

      canvas.drawLine(posA, posB, paint);
    }

    final rng = math.Random(7);
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      dotPaint.color =
          palette.muted.withOpacity(0.04 + rng.nextDouble() * 0.04);
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
