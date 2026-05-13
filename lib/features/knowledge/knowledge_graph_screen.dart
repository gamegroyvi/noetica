import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/body_utils.dart';
import '../entry/entry_editor_sheet.dart';
import 'graph_models.dart';
import 'widgets/edit_list_sheet.dart';
import 'widgets/graph_empty_state.dart';
import 'widgets/obsidian_graph_view.dart';

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
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  int? _selectedNode;
  bool _settled = false;

  // Filters.
  GraphFilterMode _filter = GraphFilterMode.all;
  String? _activeTag;
  String? _localGraphCentreId;
  bool _searchVisible = false;

  /// When true, entries tagged with `recipe` (i.e. menu-import recipe
  /// stubs) are hidden from the graph. Defaults to true so importing a
  /// 7-day menu doesn't dump 21 ancillary nodes into the user's view.
  /// Toggleable from the AppBar.
  bool _hideRecipes = true;
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
    final tr = S.of(context)!;
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
        case GraphFilterMode.all:
          break;
        case GraphFilterMode.notes:
          filtered = filtered.where((e) => e.kind == EntryKind.note).toList();
        case GraphFilterMode.tasks:
          filtered = filtered.where((e) => e.kind == EntryKind.task).toList();
        case GraphFilterMode.bookmarks:
          filtered = filtered.where((e) => e.bookmarked).toList();
        case GraphFilterMode.daily:
          filtered =
              filtered.where((e) => e.tags.contains('daily')).toList();
        case GraphFilterMode.knowledge:
          // Already short-circuited above.
          filtered = const <Entry>[];
      }
    }

    if (_activeTag != null) {
      filtered =
          filtered.where((e) => e.tags.contains(_activeTag)).toList();
    }

    // Hide recipe stubs (created by the menu generator) by default —
    // they're auxiliary notes the user navigates to via wiki-links from
    // meal tasks, so dumping 21 of them into the global graph just
    // creates noise. Toggleable via the AppBar.
    if (_hideRecipes && _activeTag != 'recipe') {
      filtered = filtered.where((e) => !e.tags.contains('recipe')).toList();
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
    final nodes = <GraphNode>[];
    final graphEdges = <GraphEdge>[];

    // Centre node (user summary from PersonalKnowledge).
    final k = _knowledge;
    nodes.add(GraphNode(
      id: '__centre__',
      label: k?.summary.isEmpty != false ? tr.graphCentreLabel : k!.summary,
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
      final branchItems = <GraphBranch, List<String>>{};
      for (final b in GraphBranch.values) {
        switch (b) {
          case GraphBranch.goals:
            branchItems[b] = k.goals;
          case GraphBranch.constraints:
            branchItems[b] = k.constraints;
          case GraphBranch.highlights:
            branchItems[b] = k.completedHighlights;
          case GraphBranch.reflections:
            branchItems[b] = k.recentReflections;
          case GraphBranch.preferences:
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
      final renderedBranches = _filter == GraphFilterMode.knowledge
          ? GraphBranch.values
          : GraphBranch.values
              .where((b) => (branchItems[b] ?? const []).isNotEmpty)
              .toList();
      final branchCount = renderedBranches.length;
      for (var bi = 0; bi < branchCount; bi++) {
        final b = renderedBranches[bi];
        final angle = branchCount == 0
            ? 0.0
            : bi * 2 * math.pi / branchCount - math.pi / 2;
        final headerIdx = nodes.length;
        nodes.add(GraphNode(
          id: '__branch_${b.name}__',
          label: b.localTitle(tr),
          color: b.color,
          isCentre: false,
          isBranchHeader: true,
          branch: b,
          position: Offset(
            math.cos(angle) * 200 + rng.nextDouble() * 20 - 10,
            math.sin(angle) * 200 + rng.nextDouble() * 20 - 10,
          ),
        ));
        graphEdges.add(GraphEdge(0, headerIdx));

        final items = branchItems[b] ?? [];
        nodes[headerIdx].childCount = items.length;
        for (var li = 0; li < items.length; li++) {
          final leafAngle = angle +
              (li - items.length / 2) * 0.35;
          final leafIdx = nodes.length;
          nodes.add(GraphNode(
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
          graphEdges.add(GraphEdge(headerIdx, leafIdx));
        }
      }
    }

    // ---- Entry nodes (notes, tasks, etc.) ----
    final idToIndex = <String, int>{};
    final entryStartAngle = GraphBranch.values.length * 2 * math.pi / 5;
    for (var i = 0; i < filtered.length; i++) {
      final e = filtered[i];
      final angle = entryStartAngle +
          i * 2 * math.pi / math.max(filtered.length, 1);
      final dist = 250.0 + rng.nextDouble() * 100;
      final idx = nodes.length;
      idToIndex[e.id] = idx;
      nodes.add(GraphNode(
        id: e.id,
        label: e.title.isEmpty
            ? (() {
                final plain = bodyToPlainText(e.body);
                return plain.length > 30
                    ? '${plain.substring(0, 30)}…'
                    : plain;
              })()
            : e.title,
        color: entryColor(e),
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
        graphEdges.add(GraphEdge(si, ti));
        nodes[si].linkCount++;
        nodes[ti].linkCount++;
      }
    }

    // Every entry is always anchored to the "я" centre — whether it's
    // standalone or sits inside a wiki-linked cluster. The previous
    // "orphan-only" rule produced the surprising effect that adding a
    // single `[[wiki]]` ref between two notes caused both to detach
    // from the centre (since they were no longer orphans). The user
    // expected the opposite: linking two notes shouldn't break either
    // note's connection to the core. Hub-and-spoke is fine — the force
    // simulation still renders the wiki-link edges clearly on top.
    for (final idx in idToIndex.values) {
      graphEdges.add(GraphEdge(0, idx));
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
        final force = kGraphRepulsion / (dist * dist);
        final clamped = math.min(force, kGraphMaxForce);
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
      final displacement = dist - kGraphSpringLen;
      final force = kGraphSpringK * displacement;
      final clamped =
          force.abs() > kGraphMaxForce ? kGraphMaxForce * force.sign : force;
      final f = delta / dist * clamped;
      forces[edge.from] = forces[edge.from] + f;
      forces[edge.to] = forces[edge.to] - f;
    }

    for (var i = 0; i < n; i++) {
      final toCenter = canvasCenter - _nodes[i].pos;
      forces[i] = forces[i] + toCenter * kGraphCentreGravity;
    }

    var totalKinetic = 0.0;
    for (var i = 0; i < n; i++) {
      if (_nodes[i].pinned) continue;
      _nodes[i].vel = (_nodes[i].vel + forces[i]) * kGraphDamping;
      _nodes[i].pos = _nodes[i].pos + _nodes[i].vel;
      totalKinetic += _nodes[i].vel.distanceSquared;
    }

    if (totalKinetic < kGraphMinVelocity * n) {
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

  void _onTapNode(GraphNode node) {
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

  void _onTapBranch(GraphBranch branch) {
    switch (branch) {
      case GraphBranch.goals:
        _editList(
          title: S.of(context)!.graphBranchGoals,
          hint: S.of(context)!.graphGoalsHint,
          items: _knowledge!.goals,
          apply: (n) =>
              _knowledge!.copyWith(goals: n, updatedAt: DateTime.now()),
        );
      case GraphBranch.constraints:
        _editList(
          title: S.of(context)!.graphBranchConstraints,
          hint: S.of(context)!.graphConstraintsHint,
          items: _knowledge!.constraints,
          apply: (n) =>
              _knowledge!.copyWith(constraints: n, updatedAt: DateTime.now()),
        );
      case GraphBranch.highlights:
        _editList(
          title: S.of(context)!.graphBranchHighlights,
          hint: S.of(context)!.graphHighlightsHint,
          items: _knowledge!.completedHighlights,
          maxItems: 20,
          apply: (n) => _knowledge!.copyWith(
              completedHighlights: n, updatedAt: DateTime.now()),
        );
      case GraphBranch.reflections:
        _editList(
          title: S.of(context)!.graphBranchReflections,
          hint: S.of(context)!.graphReflectionsHint,
          items: _knowledge!.recentReflections,
          maxItems: 10,
          apply: (n) => _knowledge!.copyWith(
              recentReflections: n, updatedAt: DateTime.now()),
        );
      case GraphBranch.preferences:
        final prefs = _knowledge!.preferences;
        final flat = [
          for (final e in prefs.entries) '${e.key}: ${e.value}',
        ];
        _editList(
          title: S.of(context)!.knowledgePrefs,
          hint: S.of(context)!.knowledgePrefHint,
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

  void _onTapLeaf(GraphBranch branch, int index) {
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
        builder: (context, scroll) => EditListSheet(
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
      title: S.of(context)!.aboutApp,
      hint: S.of(context)!.knowledgeContextHint,
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
    final r = await showModalBottomSheet<EditResult>(
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
                          Navigator.of(ctx).pop(const EditResult(value: '')),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(S.of(context)!.graphDelete),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.fg,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: Text(S.of(context)!.actionCancel),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(
                      EditResult(value: ctrl.text.trim()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.fg,
                      foregroundColor: palette.bg,
                    ),
                    child: Text(S.of(context)!.actionSave),
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
                  hintText: S.of(context)!.graphSearchHint,
                  hintStyle: TextStyle(color: palette.muted),
                  border: InputBorder.none,
                ),
                onChanged: _performSearch,
              )
            : Text(S.of(context)!.graphKnowledgeBase),
        actions: [
          IconButton(
            tooltip: S.of(context)!.graphSearchTooltip,
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
            tooltip: S.of(context)!.graphDailyTooltip,
            icon: const Icon(Icons.today),
            onPressed: _openDailyNote,
          ),
          IconButton(
            tooltip: _hideRecipes
                ? S.of(context)!.graphShowRecipes
                : S.of(context)!.graphHideRecipes,
            icon: Icon(
              _hideRecipes
                  ? Icons.restaurant_menu_outlined
                  : Icons.restaurant_menu,
            ),
            onPressed: () {
              setState(() => _hideRecipes = !_hideRecipes);
              _rebuildGraph();
            },
          ),
          if (_localGraphCentreId != null)
            IconButton(
              tooltip: S.of(context)!.graphGlobalTooltip,
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
                  tooltip: S.of(context)!.graphNewNote,
                  onPressed: _createNote,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'reset',
                  tooltip: S.of(context)!.graphResetView,
                  onPressed: _resetCamera,
                  child: const Icon(Icons.fit_screen_outlined),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'shake',
                  tooltip: S.of(context)!.graphShuffle,
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
                          for (final f in GraphFilterMode.values)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: FilterChip(
                                selected: _filter == f && _activeTag == null,
                                label: Text(f.localLabel(S.of(context)!)),
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
                                color: entryColor(e),
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
                          ? GraphEmptyState(
                              filter: _filter,
                              palette: palette,
                              onCreateEntry: () =>
                                  showEntryEditor(context, ref).then((_) {
                                if (mounted) _rebuildGraph();
                              }),
                              onResetFilter: () {
                                setState(() {
                                  _filter = GraphFilterMode.all;
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
                                          child: ObsidianGraphView(
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
