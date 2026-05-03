import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/body_utils.dart';
import '../../utils/subtask_utils.dart';
import '../../utils/time_utils.dart';
import '../../widgets/brand_glyph.dart';
import '../entry/entry_editor_sheet.dart';
import '../entry/markdown_body_editor.dart';
import '../home/home_shell.dart';
import '../reflection/reflection_sheet.dart';
import '../settings/settings_screen.dart';

/// Status filter applied to the visible task list.
enum _StatusFilter { all, open, overdue, done }

extension on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.all => 'Все',
        _StatusFilter.open => 'Открытые',
        _StatusFilter.overdue => 'Просрочены',
        _StatusFilter.done => 'Готово',
      };

  bool matches(Entry e) {
    switch (this) {
      case _StatusFilter.all:
        return true;
      case _StatusFilter.open:
        return !e.isCompleted;
      case _StatusFilter.done:
        return e.isCompleted;
      case _StatusFilter.overdue:
        return !e.isCompleted &&
            e.dueAt != null &&
            e.dueAt!.isBefore(DateTime.now());
    }
  }
}

/// Sort order applied after filtering.
enum _SortMode { smart, dueAsc, createdDesc, xpDesc }

extension on _SortMode {
  String get label => switch (this) {
        _SortMode.smart => 'Умная',
        _SortMode.dueAsc => 'Срок ↑',
        _SortMode.createdDesc => 'Свежие',
        _SortMode.xpDesc => 'Тяжёлые сверху',
      };
}

/// Date bucket the task is shown under in the grouped list.
enum _DateBucket {
  overdue,
  today,
  tomorrow,
  thisWeek,
  later,
  noDate,
  done,
}

extension on _DateBucket {
  String get label => switch (this) {
        _DateBucket.overdue => 'Просрочено',
        _DateBucket.today => 'Сегодня',
        _DateBucket.tomorrow => 'Завтра',
        _DateBucket.thisWeek => 'На этой неделе',
        _DateBucket.later => 'Позже',
        _DateBucket.noDate => 'Без даты',
        _DateBucket.done => 'Готово',
      };

  IconData get icon => switch (this) {
        _DateBucket.overdue => Icons.warning_amber_rounded,
        _DateBucket.today => Icons.today,
        _DateBucket.tomorrow => Icons.event,
        _DateBucket.thisWeek => Icons.date_range,
        _DateBucket.later => Icons.schedule,
        _DateBucket.noDate => Icons.do_not_disturb_on_total_silence_outlined,
        _DateBucket.done => Icons.check_circle_outline,
      };
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _StatusFilter _status = _StatusFilter.open;
  _SortMode _sort = _SortMode.smart;
  String? _axisFilterId; // null = all axes
  bool _noAxisOnly = false;
  bool _expandPlans = false;

  /// Buckets the user has explicitly collapsed from the section header.
  final Set<_DateBucket> _collapsedBuckets = {};

  /// Plan folders (`menu/<menuId>`) the user has expanded.
  final Set<String> _expandedMenus = {};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: BrandGlyph(size: 24),
        ),
        leadingWidth: 48,
        title: const Text('Задачи'),
        actions: [
          PopupMenuButton<_SortMode>(
            tooltip: 'Сортировка',
            icon: const Icon(Icons.sort),
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => [
              for (final m in _SortMode.values)
                CheckedPopupMenuItem(
                  value: m,
                  checked: m == _sort,
                  child: Text(m.label),
                ),
            ],
          ),
          if (isMobile)
            IconButton(
              tooltip: 'Настройки',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          final axes = axesAsync.valueOrNull ?? const [];
          final axesById = {for (final a in axes) a.id: a};
          if (_axisFilterId != null && !axesById.containsKey(_axisFilterId)) {
            _axisFilterId = null;
          }

          final filtered = entries.where((e) => e.isTask).where((e) {
            // Hide menu-generated meals — they live in the dedicated
            // «Меню недели» screen accessible from the sidebar.
            if (e.tags.any((t) => t.startsWith('menu/'))) return false;
            if (!_status.matches(e)) return false;
            if (_noAxisOnly && e.axisIds.isNotEmpty) return false;
            if (_axisFilterId != null && !e.axisIds.contains(_axisFilterId)) {
              return false;
            }
            return true;
          }).toList();

          filtered.sort(_compareTasks);

          final items = _buildItems(filtered);

          return Column(
            children: [
              _FilterBar(
                status: _status,
                onStatus: (s) => setState(() => _status = s),
                axes: axes,
                axisId: _axisFilterId,
                noAxisOnly: _noAxisOnly,
                onAxis: (id) => setState(() {
                  _axisFilterId = id;
                  if (id != null) _noAxisOnly = false;
                }),
                onNoAxisOnly: (v) => setState(() {
                  _noAxisOnly = v;
                  if (v) _axisFilterId = null;
                }),
                expandPlans: _expandPlans,
                onExpandPlans: (v) => setState(() => _expandPlans = v),
                hasPlans: items.any((it) => it is _FolderHeaderItem),
                palette: palette,
              ),
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(
                        hasAnyTasks:
                            entries.where((e) => e.isTask).isNotEmpty,
                        palette: palette,
                      )
                    : ListView.builder(
                        // Reserve room for the floating capsule + FAB.
                        padding: const EdgeInsets.fromLTRB(
                            16, 4, 16, 24 + kFloatingTabBarReserve),
                        itemCount: items.length,
                        itemBuilder: (_, i) =>
                            _renderItem(items[i], axesById, palette),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------- structure

  List<_Item> _buildItems(List<Entry> filtered) {
    // Split into plan-folders (menu/<menuId>) and free tasks.
    final folderTasks = <String, List<Entry>>{};
    final free = <Entry>[];
    for (final e in filtered) {
      final menuId = _menuIdOf(e);
      if (menuId != null && !_expandPlans) {
        folderTasks.putIfAbsent(menuId, () => []).add(e);
      } else {
        free.add(e);
      }
    }

    // Build folders (sorted by earliest dueAt).
    final folders = folderTasks.entries
        .map((kv) => _PlanFolder(menuId: kv.key, meals: kv.value))
        .toList()
      ..sort((a, b) {
        final ad = a.meals.first.dueAt;
        final bd = b.meals.first.dueAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

    // Bucket free tasks by date.
    final now = DateTime.now();
    final buckets = <_DateBucket, List<Entry>>{};
    for (final e in free) {
      buckets.putIfAbsent(_bucketOf(e, now), () => []).add(e);
    }

    final items = <_Item>[];
    if (folders.isNotEmpty) {
      items.add(_PlansSectionHeaderItem(folders.length));
      for (final folder in folders) {
        final expanded = _expandedMenus.contains(folder.menuId);
        items.add(_FolderHeaderItem(folder, expanded: expanded));
        if (expanded) {
          // Group meals by day inside the folder for readability.
          final byDay = <DateTime, List<Entry>>{};
          for (final m in folder.meals) {
            final d = m.dueAt;
            final key = d == null
                ? DateTime.fromMillisecondsSinceEpoch(0)
                : DateTime(d.year, d.month, d.day);
            byDay.putIfAbsent(key, () => []).add(m);
          }
          final sortedKeys = byDay.keys.toList()..sort();
          for (final key in sortedKeys) {
            items.add(_DayLabelItem(key));
            for (final m in byDay[key]!) {
              items.add(_TaskItem(m, insideFolder: true));
            }
          }
        }
      }
    }

    for (final bucket in _DateBucket.values) {
      final tasks = buckets[bucket];
      if (tasks == null || tasks.isEmpty) continue;
      final collapsed = _collapsedBuckets.contains(bucket);
      items.add(_BucketHeaderItem(bucket, tasks.length, collapsed: collapsed));
      if (!collapsed) {
        for (final t in tasks) {
          items.add(_TaskItem(t));
        }
      }
    }

    return items;
  }

  Widget _renderItem(
    _Item item,
    Map<String, LifeAxis> axesById,
    NoeticaPalette palette,
  ) {
    if (item is _PlansSectionHeaderItem) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Text(
          'Планы (${item.count})',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.muted,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }
    if (item is _FolderHeaderItem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _PlanFolderTile(
          folder: item.folder,
          expanded: item.expanded,
          onTap: () => setState(() {
            if (_expandedMenus.contains(item.folder.menuId)) {
              _expandedMenus.remove(item.folder.menuId);
            } else {
              _expandedMenus.add(item.folder.menuId);
            }
          }),
          palette: palette,
        ),
      );
    }
    if (item is _BucketHeaderItem) {
      return _BucketHeader(
        bucket: item.bucket,
        count: item.count,
        collapsed: item.collapsed,
        onTap: () => setState(() {
          if (_collapsedBuckets.contains(item.bucket)) {
            _collapsedBuckets.remove(item.bucket);
          } else {
            _collapsedBuckets.add(item.bucket);
          }
        }),
        palette: palette,
      );
    }
    if (item is _DayLabelItem) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 0, 4),
        child: Text(
          _formatDay(item.day),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }
    if (item is _TaskItem) {
      return Padding(
        padding: EdgeInsets.fromLTRB(item.insideFolder ? 12 : 0, 0, 0, 6),
        child: _TaskTile(task: item.task, axesById: axesById),
      );
    }
    return const SizedBox.shrink();
  }

  // -------------------------------------------------------------- bucketing

  static String? _menuIdOf(Entry e) {
    for (final t in e.tags) {
      if (t.startsWith('menu/')) return t.substring(5);
    }
    return null;
  }

  static _DateBucket _bucketOf(Entry e, DateTime now) {
    if (e.isCompleted) return _DateBucket.done;
    final due = e.dueAt;
    if (due == null) return _DateBucket.noDate;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(today)) return _DateBucket.overdue;
    if (dueDay == today) return _DateBucket.today;
    final tomorrow = today.add(const Duration(days: 1));
    if (dueDay == tomorrow) return _DateBucket.tomorrow;
    final endOfWeek = today.add(Duration(days: 7 - today.weekday));
    if (!dueDay.isAfter(endOfWeek)) return _DateBucket.thisWeek;
    return _DateBucket.later;
  }

  String _formatDay(DateTime d) {
    if (d.millisecondsSinceEpoch == 0) return 'Без даты';
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  // -------------------------------------------------------------- sort

  int _compareTasks(Entry a, Entry b) {
    switch (_sort) {
      case _SortMode.smart:
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (!a.isCompleted) {
          final ad = a.dueAt;
          final bd = b.dueAt;
          if (ad == null && bd != null) return 1;
          if (ad != null && bd == null) return -1;
          if (ad != null && bd != null) {
            final c = ad.compareTo(bd);
            if (c != 0) return c;
          }
          final aHas = hasSubtasks(a.body);
          final bHas = hasSubtasks(b.body);
          if (aHas != bHas) return aHas ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        }
        return (b.completedAt ?? b.updatedAt)
            .compareTo(a.completedAt ?? a.updatedAt);
      case _SortMode.dueAsc:
        final ad = a.dueAt;
        final bd = b.dueAt;
        if (ad == null && bd == null) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      case _SortMode.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case _SortMode.xpDesc:
        final cmp = b.xp.compareTo(a.xp);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
    }
  }
}

// ---------------------------------------------------------------------- items

abstract class _Item {
  const _Item();
}

class _PlansSectionHeaderItem extends _Item {
  const _PlansSectionHeaderItem(this.count);
  final int count;
}

class _FolderHeaderItem extends _Item {
  const _FolderHeaderItem(this.folder, {required this.expanded});
  final _PlanFolder folder;
  final bool expanded;
}

class _BucketHeaderItem extends _Item {
  const _BucketHeaderItem(
    this.bucket,
    this.count, {
    required this.collapsed,
  });
  final _DateBucket bucket;
  final int count;
  final bool collapsed;
}

class _DayLabelItem extends _Item {
  const _DayLabelItem(this.day);
  final DateTime day;
}

class _TaskItem extends _Item {
  const _TaskItem(this.task, {this.insideFolder = false});
  final Entry task;
  final bool insideFolder;
}

class _PlanFolder {
  _PlanFolder({required this.menuId, required List<Entry> meals})
      : meals = (List.of(meals)
          ..sort((a, b) {
            final ad = a.dueAt;
            final bd = b.dueAt;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return ad.compareTo(bd);
          }));

  final String menuId;
  final List<Entry> meals;

  int get done => meals.where((e) => e.isCompleted).length;
  int get total => meals.length;
  double get progress => total == 0 ? 0 : done / total;

  String? get range {
    final dues = meals
        .map((e) => e.dueAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dues.isEmpty) return null;
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    return '${f(dues.first)}–${f(dues.last)}';
  }
}

// ----------------------------------------------------------------- filter bar

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.onStatus,
    required this.axes,
    required this.axisId,
    required this.noAxisOnly,
    required this.onAxis,
    required this.onNoAxisOnly,
    required this.expandPlans,
    required this.onExpandPlans,
    required this.hasPlans,
    required this.palette,
  });

  final _StatusFilter status;
  final ValueChanged<_StatusFilter> onStatus;
  final List<LifeAxis> axes;
  final String? axisId;
  final bool noAxisOnly;
  final ValueChanged<String?> onAxis;
  final ValueChanged<bool> onNoAxisOnly;
  final bool expandPlans;
  final ValueChanged<bool> onExpandPlans;
  final bool hasPlans;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final s in _StatusFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: s == status,
                  onSelected: (_) => onStatus(s),
                ),
              ),
            if (axes.isNotEmpty) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: palette.line,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Все оси'),
                  selected: axisId == null && !noAxisOnly,
                  onSelected: (_) => onAxis(null),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Без оси'),
                  selected: noAxisOnly,
                  onSelected: onNoAxisOnly,
                ),
              ),
              for (final a in axes)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${a.symbol}  ${a.name}'),
                    selected: axisId == a.id,
                    onSelected: (_) => onAxis(a.id),
                  ),
                ),
            ],
            if (hasPlans) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: palette.line,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(expandPlans ? 'Развернуть планы' : 'Свернуть планы'),
                  selected: expandPlans,
                  avatar: Icon(
                    expandPlans
                        ? Icons.unfold_more
                        : Icons.folder_outlined,
                    size: 16,
                  ),
                  onSelected: onExpandPlans,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- bucket header

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({
    required this.bucket,
    required this.count,
    required this.collapsed,
    required this.onTap,
    required this.palette,
  });

  final _DateBucket bucket;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final emphasised = bucket == _DateBucket.overdue;
    final fg = emphasised ? palette.fg : palette.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Row(
          children: [
            Icon(
              collapsed
                  ? Icons.keyboard_arrow_right
                  : Icons.keyboard_arrow_down,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: 4),
            Icon(bucket.icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              bucket.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- folder tile

class _PlanFolderTile extends StatelessWidget {
  const _PlanFolderTile({
    required this.folder,
    required this.expanded,
    required this.onTap,
    required this.palette,
  });

  final _PlanFolder folder;
  final bool expanded;
  final VoidCallback onTap;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final range = folder.range;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: palette.muted,
                ),
                const SizedBox(width: 4),
                const Text('🍽', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Меню недели',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${folder.done}/${folder.total}',
                  style:
                      TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: folder.progress,
                minHeight: 4,
                backgroundColor: palette.line,
                valueColor:
                    AlwaysStoppedAnimation<Color>(palette.fg),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (range != null) ...[
                  Icon(Icons.date_range,
                      size: 13, color: palette.muted),
                  const SizedBox(width: 4),
                  Text(range,
                      style: TextStyle(
                          color: palette.muted, fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                Text(
                  '${folder.total} ${_ruTask(folder.total)} в плане',
                  style:
                      TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _ruTask(int n) {
  final n100 = n.abs() % 100;
  final n10 = n100 % 10;
  if (n100 >= 11 && n100 <= 14) return 'задач';
  if (n10 == 1) return 'задача';
  if (n10 >= 2 && n10 <= 4) return 'задачи';
  return 'задач';
}

// ---------------------------------------------------------------- empty state

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAnyTasks, required this.palette});
  final bool hasAnyTasks;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final title = hasAnyTasks ? 'Под фильтр ничего не попало' : 'Задач нет';
    final body = hasAnyTasks
        ? 'Сбрось фильтры или поменяй сортировку, чтобы увидеть остальные задачи.'
        : 'Создай задачу через «+». Привяжи её к осям — выполнение начислит очки в пентаграмму.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- task tile

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.axesById});

  final Entry task;
  final Map<String, LifeAxis> axesById;

  Future<void> _toggleSubtask(WidgetRef ref, int index) async {
    final repo = await ref.read(repositoryProvider.future);
    final next = toggleSubtask(task.body, index);
    if (next == task.body) return;
    await repo.upsertEntry(
      task.copyWith(body: next, updatedAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final overdue = !task.isCompleted &&
        task.dueAt != null &&
        task.dueAt!.isBefore(DateTime.now());
    // Bodies may be legacy Quill JSON; normalise to markdown so
    // subtask parsing and the rendered prose preview both work.
    // Strip metadata HTML comments (e.g. `<!-- noetica:meal -->`) so
    // the menu task body doesn't leak machine-readable markers into
    // the card text.
    final markdownBody = stripDisplayMetadata(bodyToMarkdown(task.body));
    final subtasks = parseSubtasks(markdownBody);
    final prose = stripSubtasks(markdownBody).trim();
    final prog = subtaskProgress(markdownBody);
    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: task),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(
              checked: task.isCompleted,
              onTap: () => toggleTaskWithReflection(context, ref, task),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isEmpty ? '—' : task.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? palette.muted
                              : palette.fg,
                        ),
                  ),
                  if (prose.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    MarkdownPreview(
                      // Render markdown so the user sees real bold /
                      // italic / wiki links / tags instead of raw
                      // markers like `**bold**` polluting the card.
                      body: prose,
                      maxLines: 2,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: palette.muted),
                    ),
                  ],
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (var i = 0; i < subtasks.length; i++)
                      _SubtaskRow(
                        subtask: subtasks[i],
                        palette: palette,
                        onToggle: () => _toggleSubtask(ref, i),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Pill(
                        text: '+${task.xp} XP',
                        palette: palette,
                        emphasised: true,
                      ),
                      if (subtasks.isNotEmpty)
                        _Pill(
                          text: '☑ ${prog.done}/${prog.total}',
                          palette: palette,
                          emphasised: prog.done == prog.total,
                        ),
                      for (final id in task.axisIds)
                        if (axesById[id] != null)
                          _Pill(
                            text:
                                '${axesById[id]!.symbol}  ${axesById[id]!.name}',
                            palette: palette,
                          ),
                      if (task.dueAt != null)
                        _Pill(
                          text: 'до ${formatTimestamp(task.dueAt!)}',
                          palette: palette,
                          warning: overdue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.palette,
    required this.onToggle,
  });

  final Subtask subtask;
  final NoeticaPalette palette;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact checkbox — slightly smaller than the main task
            // checkbox so hierarchy is visually obvious.
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2, right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: palette.line, width: 1.2),
                borderRadius: BorderRadius.circular(4),
                color: subtask.checked ? palette.fg : Colors.transparent,
              ),
              child: subtask.checked
                  ? Icon(Icons.check, size: 11, color: palette.bg)
                  : null,
            ),
            Expanded(
              child: subtask.text.isEmpty
                  ? Text(
                      '—',
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    )
                  : MarkdownPreview(
                      // Subtask text often contains **bold**, [[wiki]],
                      // tags etc. Render them so the row reads cleanly
                      // instead of leaking raw markdown markers.
                      body: subtask.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtask.checked ? palette.muted : palette.fg,
                        decoration: subtask.checked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          border: Border.all(color: palette.line, width: 1.5),
          borderRadius: BorderRadius.circular(6),
          color: checked ? palette.fg : Colors.transparent,
        ),
        child: checked
            ? Icon(Icons.check, size: 14, color: palette.bg)
            : null,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.palette,
    this.emphasised = false,
    this.warning = false,
  });

  final String text;
  final NoeticaPalette palette;
  final bool emphasised;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final fg = warning
        ? palette.fg
        : (emphasised ? palette.fg : palette.muted);
    final border = warning ? palette.fg : palette.line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
