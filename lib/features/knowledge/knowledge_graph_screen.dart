import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_editor_sheet.dart';

/// Radial, drevovidnaya visualisation of [PersonalKnowledge].
///
/// At the centre is the user (the "trunk"). From it five primary branches
/// fan out — Goals, Constraints, Highlights, Reflections, Preferences —
/// and each carries its own leaf nodes. Each node breathes via a small
/// continuous sin-based jitter so the graph feels alive instead of static.
///
/// Tapping any node opens an edit sheet that mutates the underlying
/// [PersonalKnowledge] document. The graph re-lays out to absorb the
/// change without a full screen replacement.
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
  late final AnimationController _shimmer;
  // Drives the InteractiveViewer, lets us reset to the home position.
  final _zoom = TransformationController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _load();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// Reset pan + zoom back to the natural "everything fits on screen" view.
  void _resetCamera() {
    _zoom.value = Matrix4.identity();
    HapticFeedback.selectionClick();
  }

  Future<void> _load() async {
    try {
      final k = await _service.load();
      if (!mounted) return;
      setState(() {
        _knowledge = k;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

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
    if (mounted) setState(() => _knowledge = upd);
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
    if (mounted) setState(() => _knowledge = upd);
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
    if (mounted) setState(() => _knowledge = upd);
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Recent notes (kind=note) and recent completed tasks (kind=task,
    // completedAt != null) — both auto-flow into the knowledge graph
    // as live read-only branches. Capped to 6 each so the radial
    // layout stays readable.
    final entries =
        ref.watch(entriesProvider).valueOrNull ?? const <Entry>[];
    final recentNotes = [
      for (final e in entries
          .where((e) => e.kind == EntryKind.note && !e.isDeleted)
          .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        e.title.isEmpty
            ? (e.body.length > 32 ? '${e.body.substring(0, 32)}…' : e.body)
            : e.title,
    ].take(6).toList();
    final recentTasks = [
      for (final e in entries
          .where((e) =>
              e.kind == EntryKind.task && e.isCompleted && !e.isDeleted)
          .toList()
            ..sort((a, b) =>
                (b.completedAt ?? b.updatedAt)
                    .compareTo(a.completedAt ?? a.updatedAt)))
        e.title,
    ].take(6).toList();
    // Look up the underlying entry by index for tap-to-edit.
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('База знаний'),
        actions: [
          IconButton(
            tooltip: 'К центру',
            icon: const Icon(Icons.center_focus_weak_outlined),
            onPressed: _resetCamera,
          ),
          IconButton(
            tooltip: 'Сводка о тебе',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: _knowledge == null
                ? null
                : () => _editSummary(_knowledge!.summary),
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.small(
              tooltip: 'Сбросить вид',
              onPressed: _resetCamera,
              child: const Icon(Icons.fit_screen_outlined),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SafeArea(
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, _) => InteractiveViewer(
                      transformationController: _zoom,
                      // Wider zoom range so the user can pull way out to
                      // see the whole graph and zoom way in to read tiny
                      // leaves. Boundary margin lets pan go off-canvas.
                      minScale: 0.25,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(400),
                      child: SizedBox(
                        // Oversized canvas so the radial layout has room
                        // to spread (was getting clipped on phones).
                        // 1.4× viewport works well on both mobile and
                        // desktop without losing density at scale 1.0.
                        width: MediaQuery.of(context).size.width * 1.4,
                        height:
                            (MediaQuery.of(context).size.height - 100) * 1.4,
                        child: _GraphCanvas(
                          knowledge: _knowledge!,
                          palette: palette,
                          shimmer: _shimmer.value,
                          recentNotes: recentNotes,
                          recentTasks: recentTasks,
                          onTapCenter: () =>
                              _editSummary(_knowledge!.summary),
                          onTapBranchHeader: (branch) async {
                            switch (branch) {
                              case _Branch.goals:
                                await _editList(
                                  title: 'Цели',
                                  hint: 'Что хочешь достичь',
                                  items: _knowledge!.goals,
                                  apply: (n) =>
                                      _knowledge!.copyWith(goals: n,
                                          updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.constraints:
                                await _editList(
                                  title: 'Ограничения',
                                  hint: 'Что мешает или ограничивает',
                                  items: _knowledge!.constraints,
                                  apply: (n) =>
                                      _knowledge!.copyWith(constraints: n,
                                          updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.highlights:
                                await _editList(
                                  title: 'Достижения',
                                  hint: 'Что уже получилось',
                                  items: _knowledge!.completedHighlights,
                                  maxItems: 20,
                                  apply: (n) =>
                                      _knowledge!.copyWith(
                                          completedHighlights: n,
                                          updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.reflections:
                                await _editList(
                                  title: 'Рефлексии',
                                  hint: 'Заметки о пройденном',
                                  items: _knowledge!.recentReflections,
                                  maxItems: 10,
                                  apply: (n) =>
                                      _knowledge!.copyWith(
                                          recentReflections: n,
                                          updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.preferences:
                                final prefs = _knowledge!.preferences;
                                final flat = [
                                  for (final e in prefs.entries)
                                    '${e.key}: ${e.value}',
                                ];
                                await _editList(
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
                                        m[line.substring(0, i).trim()] =
                                            line.substring(i + 1).trim();
                                      }
                                    }
                                    return _knowledge!.copyWith(
                                      preferences: m,
                                      updatedAt: DateTime.now(),
                                    );
                                  },
                                );
                                break;
                              case _Branch.notes:
                              case _Branch.tasks:
                                // Read-only branches — header tap is a
                                // no-op; the user edits these from the
                                // Notes / Tasks tabs (or by tapping a leaf).
                                break;
                            }
                          },
                          onTapLeaf: (branch, index) async {
                            switch (branch) {
                              case _Branch.goals:
                                await _editLeaf(
                                  branch: 'Цель',
                                  index: index,
                                  source: _knowledge!.goals,
                                  apply: (n) => _knowledge!.copyWith(
                                      goals: n, updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.constraints:
                                await _editLeaf(
                                  branch: 'Ограничение',
                                  index: index,
                                  source: _knowledge!.constraints,
                                  apply: (n) => _knowledge!.copyWith(
                                      constraints: n,
                                      updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.highlights:
                                await _editLeaf(
                                  branch: 'Достижение',
                                  index: index,
                                  source: _knowledge!.completedHighlights,
                                  apply: (n) => _knowledge!.copyWith(
                                      completedHighlights: n,
                                      updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.reflections:
                                await _editLeaf(
                                  branch: 'Рефлексия',
                                  index: index,
                                  source: _knowledge!.recentReflections,
                                  apply: (n) => _knowledge!.copyWith(
                                      recentReflections: n,
                                      updatedAt: DateTime.now()),
                                );
                                break;
                              case _Branch.preferences:
                                // Edit handled at branch level (key:value).
                                break;
                              case _Branch.notes:
                                if (index < notesEntries.length) {
                                  await showEntryEditor(
                                    context,
                                    ref,
                                    existing: notesEntries[index],
                                  );
                                }
                                break;
                              case _Branch.tasks:
                                if (index < tasksEntries.length) {
                                  await showEntryEditor(
                                    context,
                                    ref,
                                    existing: tasksEntries[index],
                                  );
                                }
                                break;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _EditResult {
  const _EditResult({required this.value});
  final String value;
}

enum _Branch {
  goals,
  constraints,
  highlights,
  reflections,
  preferences,
  // Live, read-only branches — populated from the entries store directly,
  // not from PersonalKnowledge. They auto-update whenever the user adds
  // a note or completes a task and surface that activity inside the
  // knowledge graph (the user asked for it: "заметки пользвоателя и
  // прочее, все это должно идти в базу знаний в том числе").
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

  String get symbol {
    switch (this) {
      case _Branch.goals:
        return '◇';
      case _Branch.constraints:
        return '◐';
      case _Branch.highlights:
        return '✦';
      case _Branch.reflections:
        return '◯';
      case _Branch.preferences:
        return '■';
      case _Branch.notes:
        return '✎';
      case _Branch.tasks:
        return '✓';
    }
  }

}

class _GraphCanvas extends StatelessWidget {
  const _GraphCanvas({
    required this.knowledge,
    required this.palette,
    required this.shimmer,
    required this.onTapCenter,
    required this.onTapBranchHeader,
    required this.onTapLeaf,
    required this.recentNotes,
    required this.recentTasks,
  });

  final PersonalKnowledge knowledge;
  final NoeticaPalette palette;
  final double shimmer; // 0..1, advances slowly
  final VoidCallback onTapCenter;
  final ValueChanged<_Branch> onTapBranchHeader;
  final void Function(_Branch branch, int index) onTapLeaf;

  /// Live data piped in from the entries store. Capped to ~6 each so
  /// the graph stays readable.
  final List<String> recentNotes;
  final List<String> recentTasks;

  List<String> _items(_Branch b) {
    switch (b) {
      case _Branch.goals:
        return knowledge.goals;
      case _Branch.constraints:
        return knowledge.constraints;
      case _Branch.highlights:
        return knowledge.completedHighlights;
      case _Branch.reflections:
        return knowledge.recentReflections;
      case _Branch.preferences:
        return [
          for (final e in knowledge.preferences.entries)
            '${e.key}: ${e.value}',
        ];
      case _Branch.notes:
        return recentNotes;
      case _Branch.tasks:
        return recentTasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    const branches = _Branch.values;
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final centre = Offset(size.width / 2, size.height / 2);
        final branchRadius =
            math.min(size.width, size.height) * 0.27;
        final leafRadius = branchRadius * 1.65;

        // Compute branch positions on a circle.
        final positions = <_Branch, Offset>{};
        final n = branches.length;
        for (var i = 0; i < n; i++) {
          final angle = -math.pi / 2 + i * 2 * math.pi / n;
          final wobble = 4 *
              math.sin((shimmer * 2 * math.pi) + i * 1.3);
          positions[branches[i]] = Offset(
            centre.dx + branchRadius * math.cos(angle),
            centre.dy + branchRadius * math.sin(angle) + wobble,
          );
        }

        // Build leaf positions per branch.
        final leafPositions = <_Branch, List<Offset>>{};
        for (var bi = 0; bi < branches.length; bi++) {
          final b = branches[bi];
          final items = _items(b);
          final List<Offset> pts = [];
          if (items.isEmpty) {
            leafPositions[b] = pts;
            continue;
          }
          final anchor = positions[b]!;
          final base = -math.pi / 2 + bi * 2 * math.pi / n;
          const spread = math.pi * 0.45;
          for (var li = 0; li < items.length; li++) {
            final t = items.length == 1
                ? 0.5
                : li / (items.length - 1);
            final theta = base + (t - 0.5) * spread;
            final wobble = 3 *
                math.sin(
                    (shimmer * 2 * math.pi) + bi * 0.7 + li * 1.7);
            final p = Offset(
              centre.dx + leafRadius * math.cos(theta),
              centre.dy + leafRadius * math.sin(theta) + wobble,
            );
            pts.add(p);
            // Used directly via list index alignment; anchor unused here.
            // (kept anchor variable for clarity / future spline routing)
            // ignore: unused_local_variable
            anchor;
          }
          leafPositions[b] = pts;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _GraphPainter(
                centre: centre,
                branches: positions,
                leafPositions: leafPositions,
                fg: palette.fg,
                line: palette.line,
                muted: palette.muted,
              ),
            ),
            // Centre node — user / "трунк".
            Positioned(
              left: centre.dx - 38,
              top: centre.dy - 38,
              width: 76,
              height: 76,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTapCenter();
                },
                child: _CentreNode(
                  palette: palette,
                  pulse: 0.5 + 0.5 * math.sin(shimmer * 2 * math.pi),
                  summary: knowledge.summary,
                ),
              ),
            ),
            // Branch header nodes.
            for (final b in branches)
              Positioned(
                left: positions[b]!.dx - 44,
                top: positions[b]!.dy - 22,
                width: 88,
                height: 44,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTapBranchHeader(b);
                  },
                  child: _BranchNode(
                    title: b.title,
                    symbol: b.symbol,
                    count: _items(b).length,
                    palette: palette,
                  ),
                ),
              ),
            // Leaf nodes.
            for (final b in branches)
              for (var li = 0; li < leafPositions[b]!.length; li++)
                Positioned(
                  left: leafPositions[b]![li].dx - 60,
                  top: leafPositions[b]![li].dy - 16,
                  width: 120,
                  height: 32,
                  child: GestureDetector(
                    onTap: b == _Branch.preferences
                        ? () => onTapBranchHeader(b)
                        : () => onTapLeaf(b, li),
                    child: _LeafNode(
                      label: _items(b)[li],
                      palette: palette,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.centre,
    required this.branches,
    required this.leafPositions,
    required this.fg,
    required this.line,
    required this.muted,
  });

  final Offset centre;
  final Map<_Branch, Offset> branches;
  final Map<_Branch, List<Offset>> leafPositions;
  final Color fg;
  final Color line;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = fg.withOpacity(0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final twigPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    branches.forEach((b, p) {
      // Trunk → branch (curved).
      final mid = Offset.lerp(centre, p, 0.5)!;
      final ctrl =
          Offset(mid.dx + (p.dy - centre.dy) * 0.12,
              mid.dy - (p.dx - centre.dx) * 0.12);
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p.dx, p.dy);
      canvas.drawPath(path, trunkPaint);

      // Branch → each leaf.
      for (final leaf in leafPositions[b] ?? const <Offset>[]) {
        final m = Offset.lerp(p, leaf, 0.5)!;
        final c =
            Offset(m.dx + (leaf.dy - p.dy) * 0.18,
                m.dy - (leaf.dx - p.dx) * 0.18);
        final path = Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(c.dx, c.dy, leaf.dx, leaf.dy);
        canvas.drawPath(path, twigPaint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.centre != centre ||
      !mapEquals(old.branches, branches) ||
      !mapEquals(old.leafPositions, leafPositions);

  static bool mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }
}

class _CentreNode extends StatelessWidget {
  const _CentreNode({
    required this.palette,
    required this.pulse,
    required this.summary,
  });

  final NoeticaPalette palette;
  final double pulse; // 0..1
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 70 + 4 * pulse,
          height: 70 + 4 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface,
            border: Border.all(color: palette.fg, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: palette.fg.withOpacity(0.05 + 0.10 * pulse),
                blurRadius: 14 + 6 * pulse,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              summary.isEmpty ? 'я' : 'я',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BranchNode extends StatelessWidget {
  const _BranchNode({
    required this.title,
    required this.symbol,
    required this.count,
    required this.palette,
  });

  final String title;
  final String symbol;
  final int count;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.fg.withOpacity(0.55)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            symbol,
            style: TextStyle(color: palette.fg, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(color: palette.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LeafNode extends StatelessWidget {
  const _LeafNode({required this.label, required this.palette});

  final String label;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.fg, fontSize: 10),
        ),
      ),
    );
  }
}

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
