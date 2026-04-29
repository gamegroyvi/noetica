import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/body_utils.dart';
import '../entry/entry_editor_sheet.dart';

// ---------------------------------------------------------------------------
// Graph node — a single point in the force-directed simulation.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Branch enum — PersonalKnowledge categories shown as branch headers.
// ---------------------------------------------------------------------------

enum _Branch {
  goals,
  constraints,
  highlights,
  reflections,
  preferences,
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
    }
  }

  Color get color {
    switch (this) {
      case _Branch.goals:
        return const Color(0xFF7C3AED);
      case _Branch.constraints:
        return const Color(0xFFEF4444);
      case _Branch.highlights:
        return const Color(0xFFF59E0B);
      case _Branch.reflections:
        return const Color(0xFF3B82F6);
      case _Branch.preferences:
        return const Color(0xFF8B5CF6);
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
    required this.color,
    required this.isCentre,
    this.entry,
    this.isBookmarked = false,
    this.isBranchHeader = false,
    this.isLeaf = false,
    this.branch,
    this.leafIndex = -1,
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
  final bool isBranchHeader;
  final bool isLeaf;
  final _Branch? branch;
  final int leafIndex;
  final List<String> tags;
  int linkCount = 0;
  int childCount = 0;
  Offset pos;
  Offset vel;
  bool pinned = false;

  double get radius {
    if (isCentre) return 18;
    if (isBranchHeader) return 12;
    if (isBookmarked) return 13;
    if (isLeaf) return 7;
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

enum _FilterMode { all, notes, tasks, bookmarks, daily, knowledge }

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
      case _FilterMode.knowledge:
        return 'Знания о себе';
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
      case _FilterMode.knowledge:
        return Icons.account_tree_outlined;
    }
  }

  /// Whether this filter shows the PersonalKnowledge category branches
  /// (Цели / Ограничения / Достижения / Рефлексии / Предпочтения).
  /// Other filter modes hide them so the user actually sees a filtered
  /// graph instead of the same star of branches dominating the view.
  bool get showsKnowledgeBranches {
    switch (this) {
      case _FilterMode.all:
      case _FilterMode.knowledge:
        return true;
      case _FilterMode.notes:
      case _FilterMode.tasks:
      case _FilterMode.bookmarks:
      case _FilterMode.daily:
        return false;
    }
  }

  /// Whether this filter shows entry nodes (notes / tasks / journals).
  bool get showsEntries {
    switch (this) {
      case _FilterMode.all:
      case _FilterMode.notes:
      case _FilterMode.tasks:
      case _FilterMode.bookmarks:
      case _FilterMode.daily:
        return true;
      case _FilterMode.knowledge:
        return false;
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
  StreamSubscription<PersonalKnowledge>? _changesSub;

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
    _changesSub = PersonalKnowledgeService.changes.listen((k) {
      if (mounted) setState(() => _knowledge = k);
    });
    _load();
  }

  @override
  void dispose() {
    _changesSub?.cancel();
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

  /// True when the graph has nothing meaningful to show: only the centre
  /// "я" node, possibly with PK branch headers that themselves have no
  /// leaves and no entries. Drives the dedicated empty-state UI.
  bool _isEffectivelyEmpty() {
    if (_nodes.isEmpty) return true;
    // Count anything other than the centre + empty branch headers.
    var meaningful = 0;
    for (final n in _nodes) {
      if (n.isCentre) continue;
      if (n.isBranchHeader && n.childCount == 0) continue;
      meaningful++;
    }
    return meaningful == 0;
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
    final repo = await ref.read(repositoryProvider.future);

    // Read entries directly from the repository instead of via
    // `entriesProvider.valueOrNull`. The stream provider propagates
    // through microtasks, so right after `showEntryEditor(...).then(...)`
    // returns from a save the provider may still hold the pre-save
    // snapshot — a freshly-created note would get its entry_links row
    // via `syncBodyLinks` but the graph wouldn't see the note itself
    // in `idToIndex`, silently dropping the edge. User-visible symptom:
    // "I created a note and linked it to another, but it floats
    // disconnected from the graph."
    final entries = await repo.listEntries();

    // Get all links from DB.
    final links = await repo.allLinks();

    // Filter entries based on current filter mode.
    var filtered = entries.where((e) => !e.isDeleted).toList();

    if (!_filter.showsEntries) {
      filtered = const <Entry>[];
    } else {
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
        case _FilterMode.knowledge:
          // Already short-circuited above.
          filtered = const <Entry>[];
      }
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

    // ---- PersonalKnowledge category branches (like original) ----
    // Only render the goals/constraints/highlights/reflections/preferences
    // "star" when the active filter actually wants to show them. With the
    // old code the branches were drawn for every filter, so e.g. the
    // "Заметки" chip looked broken — the user saw no visible change
    // because PK branches dominated the layout regardless.
    if (k != null &&
        _localGraphCentreId == null &&
        _filter.showsKnowledgeBranches) {
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
        }
      }

      // Hide branches whose user-authored list is empty. Previously we
      // drew all five branches (Цели/Ограничения/Достижения/Рефлексии/
      // Предпочтения) unconditionally — which created a star of empty
      // skeleton nodes for every new user and made the graph look
      // cluttered and fake. In "knowledge"-only filter we still render
      // ALL branches so the user can discover and fill them via taps
      // (the empty-state CTA flow). Other modes ("all") show only the
      // branches that actually have content.
      final renderedBranches = _filter == _FilterMode.knowledge
          ? _Branch.values
          : _Branch.values
              .where((b) => (branchItems[b] ?? const []).isNotEmpty)
              .toList();
      final branchCount = renderedBranches.length;
      for (var bi = 0; bi < branchCount; bi++) {
        final b = renderedBranches[bi];
        final angle = branchCount == 0
            ? 0.0
            : bi * 2 * math.pi / branchCount - math.pi / 2;
        final headerIdx = nodes.length;
        nodes.add(_GraphNode(
          id: '__branch_${b.name}__',
          label: b.title,
          color: b.color,
          isCentre: false,
          isBranchHeader: true,
          branch: b,
          position: Offset(
            math.cos(angle) * 200 + rng.nextDouble() * 20 - 10,
            math.sin(angle) * 200 + rng.nextDouble() * 20 - 10,
          ),
        ));
        graphEdges.add(_GraphEdge(0, headerIdx));

        final items = branchItems[b] ?? [];
        nodes[headerIdx].childCount = items.length;
        for (var li = 0; li < items.length; li++) {
          final leafAngle = angle +
              (li - items.length / 2) * 0.35;
          final leafIdx = nodes.length;
          nodes.add(_GraphNode(
            id: '__leaf_${b.name}_$li',
            label: items[li],
            color: b.color,
            isCentre: false,
            isLeaf: true,
            branch: b,
            leafIndex: li,
            position: Offset(
              math.cos(leafAngle) * 340 + rng.nextDouble() * 20 - 10,
              math.sin(leafAngle) * 340 + rng.nextDouble() * 20 - 10,
            ),
          ));
          graphEdges.add(_GraphEdge(headerIdx, leafIdx));
        }
      }
    }

    // ---- Entry nodes (notes, tasks, etc.) ----
    final idToIndex = <String, int>{};
    final entryStartAngle = _Branch.values.length * 2 * math.pi / 5;
    for (var i = 0; i < filtered.length; i++) {
      final e = filtered[i];
      final angle = entryStartAngle +
          i * 2 * math.pi / math.max(filtered.length, 1);
      final dist = 250.0 + rng.nextDouble() * 100;
      final idx = nodes.length;
      idToIndex[e.id] = idx;
      nodes.add(_GraphNode(
        id: e.id,
        label: e.title.isEmpty
            ? (() {
                final plain = bodyToPlainText(e.body);
                return plain.length > 30
                    ? '${plain.substring(0, 30)}…'
                    : plain;
              })()
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

    // Connect orphan entry nodes to the centre.
    final connectedNodeIndices = <int>{};
    for (final e in graphEdges) {
      connectedNodeIndices.add(e.from);
      connectedNodeIndices.add(e.to);
    }
    for (final kv in idToIndex.entries) {
      if (!connectedNodeIndices.contains(kv.value)) {
        graphEdges.add(_GraphEdge(0, kv.value));
      }
    }

    // `_rebuildGraph` is async and awaits repositoryProvider +
    // repo.allLinks(); if the user leaves the screen mid-flight the
    // callback would hit setState-after-dispose. Sibling `_performSearch`
    // already follows this pattern (Devin Review
    // BUG_pr-review-job-30b43c75…_0001).
    if (!mounted) return;
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
    if (node.isBranchHeader) {
      _onTapBranch(node.branch!);
      return;
    }
    if (node.isLeaf) {
      _onTapLeaf(node.branch!, node.leafIndex);
      return;
    }
    if (node.entry != null) {
      showEntryEditor(context, ref, existing: node.entry).then((_) {
        _syncBodyLinks(node.entry!);
        _rebuildGraph();
      });
    }
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
    }
  }

  void _onTapLeaf(_Branch branch, int index) {
    _onTapBranch(branch);
  }

  Future<void> _editList({
    required String title,
    required String hint,
    required List<String> items,
    required PersonalKnowledge Function(List<String> next) apply,
    int maxItems = 12,
  }) async {
    final palette = context.palette;
    // Dismissable bottom sheet with a drag handle + resizable scroll
    // area. This keeps the graph partially visible behind the sheet,
    // which matches the mobile-native feel the user asked for.
    final next = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scroll) => _EditListSheet(
          title: title,
          hint: hint,
          initial: items,
          maxItems: maxItems,
          scrollController: scroll,
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

  Future<void> _editLeaf({
    required String branch,
    required int index,
    required List<String> source,
    required PersonalKnowledge Function(List<String> next) apply,
  }) async {
    if (index < 0 || index >= source.length) return;
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
                      child: _isEffectivelyEmpty()
                          ? _GraphEmptyState(
                              filter: _filter,
                              palette: palette,
                              onCreateEntry: () =>
                                  showEntryEditor(context, ref).then((_) {
                                if (mounted) _rebuildGraph();
                              }),
                              onResetFilter: () {
                                setState(() {
                                  _filter = _FilterMode.all;
                                  _activeTag = null;
                                });
                                _rebuildGraph();
                              },
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
                                              if (node.entry != null) {
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
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.bookmark,
                          size: 12, color: Color(0xFFF59E0B)),
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

// ---------------------------------------------------------------------------
// Simple list editor for PersonalKnowledge branch items.
// ---------------------------------------------------------------------------

class _EditListSheet extends StatefulWidget {
  const _EditListSheet({
    required this.title,
    required this.hint,
    required this.initial,
    required this.scrollController,
    this.maxItems = 12,
  });
  final String title;
  final String hint;
  final List<String> initial;
  final int maxItems;
  final ScrollController scrollController;

  @override
  State<_EditListSheet> createState() => _EditListSheetState();
}

class _EditListSheetState extends State<_EditListSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final item in widget.initial) TextEditingController(text: item),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (_controllers.length >= widget.maxItems) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _remove(int i) {
    setState(() {
      _controllers[i].dispose();
      _controllers.removeAt(i);
    });
  }

  void _save() {
    final items = _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    Navigator.of(context).pop(items);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: palette.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header row with title + save action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_controllers.length < widget.maxItems)
                  IconButton(
                    tooltip: 'Добавить',
                    icon: Icon(Icons.add, color: palette.fg),
                    onPressed: _add,
                  ),
                TextButton.icon(
                  onPressed: _save,
                  icon: Icon(Icons.check, color: palette.fg, size: 18),
                  label: Text(
                    'Готово',
                    style: TextStyle(color: palette.fg),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: _controllers.isEmpty
                ? _EmptyListCta(palette: palette, onAdd: _add)
                : ReorderableListView.builder(
                    scrollController: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: _controllers.length,
                    onReorder: (old, nw) {
                      setState(() {
                        final c = _controllers.removeAt(old);
                        _controllers.insert(nw > old ? nw - 1 : nw, c);
                      });
                    },
                    itemBuilder: (_, i) {
                      return Padding(
                        key: ValueKey(_controllers[i]),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.drag_indicator,
                                color: palette.muted, size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _controllers[i],
                                style: TextStyle(
                                    color: palette.fg, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: widget.hint,
                                  hintStyle:
                                      TextStyle(color: palette.muted),
                                  filled: true,
                                  fillColor: palette.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: palette.muted, size: 18),
                              onPressed: () => _remove(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListCta extends StatelessWidget {
  const _EmptyListCta({required this.palette, required this.onAdd});
  final NoeticaPalette palette;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.add, color: palette.fg),
        label: Text(
          'Добавить первую запись',
          style: TextStyle(color: palette.fg),
        ),
      ),
    );
  }
}


class _GraphEmptyState extends StatelessWidget {
  const _GraphEmptyState({
    required this.filter,
    required this.palette,
    required this.onCreateEntry,
    required this.onResetFilter,
  });

  final _FilterMode filter;
  final NoeticaPalette palette;
  final VoidCallback onCreateEntry;
  final VoidCallback onResetFilter;

  @override
  Widget build(BuildContext context) {
    final (title, hint, primaryLabel, primaryAction, showReset) =
        _copyForFilter();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filter.icon, size: 48, color: palette.muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.fg,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primaryAction != null)
                  FilledButton.icon(
                    onPressed: primaryAction,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(primaryLabel),
                  ),
                if (showReset)
                  OutlinedButton.icon(
                    onPressed: onResetFilter,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Сбросить фильтр'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, String, String, VoidCallback?, bool) _copyForFilter() {
    switch (filter) {
      case _FilterMode.all:
        return (
          'База знаний пока пуста',
          'Создайте первую заметку или задачу — они появятся здесь как узлы графа.',
          'Создать запись',
          onCreateEntry,
          false,
        );
      case _FilterMode.notes:
        return (
          'Заметок пока нет',
          'Заметки будут видны как отдельные узлы. Связи появляются автоматически, когда в теле есть [[ссылка]] на другую заметку.',
          'Создать заметку',
          onCreateEntry,
          true,
        );
      case _FilterMode.tasks:
        return (
          'Задач в графе нет',
          'Создайте задачу через «+» или сгенерируйте план задач из вашей цели.',
          'Создать запись',
          onCreateEntry,
          true,
        );
      case _FilterMode.bookmarks:
        return (
          'Закладок пока нет',
          'Долгое нажатие на узел графа добавит его в закладки.',
          '',
          null,
          true,
        );
      case _FilterMode.daily:
        return (
          'Дневник пуст',
          'Тапните иконку календаря в шапке, чтобы создать запись на сегодня.',
          '',
          null,
          true,
        );
      case _FilterMode.knowledge:
        return (
          'Знания о себе пусты',
          'Заполните цели, ограничения и достижения через тапы по веткам графа — это даст AI больше контекста для генерации планов.',
          '',
          null,
          true,
        );
    }
  }
}
