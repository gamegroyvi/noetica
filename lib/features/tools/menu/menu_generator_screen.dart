import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models.dart';
import '../../../providers.dart';
import '../../../services/builtin_generators.dart';
import '../../../services/tools_api.dart';
import '../../../theme/app_theme.dart';
import '../../entry/entry_editor_sheet.dart';
import '../manifest/generator_form_view.dart';

/// Stages the screen walks the user through. State machine instead of
/// child routes so the user can jump back without losing the generated
/// plan (re-typing the form values would be infuriating after a 15s
/// generation).
enum _Stage { form, generating, preview, importing, imported }

/// "Меню недели" — first AI tool surfaced in «Ассистент». Walks the
/// user through:
///
/// 1. **Form** — pick goal / servings / start date / restrictions.
/// 2. **Generate** — POST `/tools/menu/generate` (~10–20s).
/// 3. **Preview** — 7-day grid; user can re-generate or import.
/// 4. **Import** — batch-create 21 task entries (breakfast/lunch/dinner
///    × 7 days) + 1 «Список покупок» note + per-meal stub recipe notes
///    that lazy-load via `/tools/menu/recipe` when the user opens them
///    inside the same generator screen.
class MenuGeneratorScreen extends ConsumerStatefulWidget {
  const MenuGeneratorScreen({super.key});

  @override
  ConsumerState<MenuGeneratorScreen> createState() =>
      _MenuGeneratorScreenState();
}

class _MenuGeneratorScreenState extends ConsumerState<MenuGeneratorScreen> {
  _Stage _stage = _Stage.form;
  String? _error;

  /// Form state, keyed by `GeneratorInputField.id` from the manifest.
  /// All form mutations go through `setState(() => _values[id] = …)`
  /// so the universal `GeneratorFormView` can render the same data
  /// without bespoke widgets for chips / pickers / textareas.
  final GeneratorFormValues _values = {};

  // Generated plan + import bookkeeping.
  MenuPlan? _plan;
  String? _menuId;
  // (taskEntryId, recipeStubId) per meal in import order. Used so the
  // recipe panel knows which note to fill on lazy-generate.
  final List<_ImportedMeal> _imported = [];
  // Recipe loading state by meal index.
  final Map<int, _RecipeState> _recipes = {};

  // Convenience accessors — keep the rest of the screen oblivious to
  // the manifest plumbing. Defaults match the previous hard-coded
  // initial state for the form.
  MenuGoal get _goal =>
      MenuGoal.fromWire(_values['goal'] as String? ?? 'classic');
  int get _servings => _values['servings'] as int? ?? 2;
  DateTime get _startDate =>
      _values['start_date'] as DateTime? ??
      DateTime.now().add(const Duration(days: 1));
  String? get _selectedAxisId => _values['axis_id'] as String?;
  String get _restrictions =>
      ((_values['restrictions'] as String?) ?? '').trim();
  String get _extraNotes => ((_values['notes'] as String?) ?? '').trim();

  void _seedValuesFromManifest() {
    _values.clear();
    for (final f in menuWeekInputs()) {
      _values[f.id] = f.defaultValue;
    }
    // Date default isn't covered by manifest defaults (intentionally
    // null so user-authored manifests don't pin a particular day);
    // the menu UX wants tomorrow as starting point.
    _values['start_date'] = DateTime.now().add(const Duration(days: 1));
    // Servings default to 2 (was the hard-coded initial); manifest
    // says 1 to keep the schema sensible for single-person plans.
    _values['servings'] = 2;
  }

  @override
  void initState() {
    super.initState();
    _seedValuesFromManifest();
    // Best-effort: if the user has already imported a menu in a past
    // session, drop them back into the imported view so they can keep
    // generating recipes for individual dishes. Without this, exiting
    // the screen between recipe generations was a one-way trip — there
    // was no way to come back to the meal list except by importing a
    // brand-new menu.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeLastMenu());
  }

  // --------------------------------------------------------------- resume

  Future<void> _resumeLastMenu() async {
    if (_stage != _Stage.form) return;
    try {
      final repo = await ref.read(repositoryProvider.future);
      final entries = await repo.listEntries();
      // Group meal tasks by their menu/<id> tag.
      final byMenu = <String, List<Entry>>{};
      for (final e in entries) {
        if (e.kind != EntryKind.task || e.isDeleted) continue;
        if (!e.tags.contains('meal')) continue;
        final menuTag = e.tags.firstWhere(
          (t) => t.startsWith('menu/'),
          orElse: () => '',
        );
        if (menuTag.isEmpty) continue;
        byMenu.putIfAbsent(menuTag.substring(5), () => []).add(e);
      }
      if (byMenu.isEmpty) return;

      // Pick the latest menu by max createdAt across its tasks.
      String? latestId;
      DateTime? latestTime;
      byMenu.forEach((id, tasks) {
        final t = tasks
            .map((e) => e.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        if (latestTime == null || t.isAfter(latestTime!)) {
          latestTime = t;
          latestId = id;
        }
      });
      final menuId = latestId!;
      final tasks = byMenu[menuId]!;

      // Recipe stubs share the menu/<id> tag plus 'recipe'.
      final stubs = entries
          .where((e) =>
              e.kind == EntryKind.note &&
              !e.isDeleted &&
              e.tags.contains('recipe') &&
              e.tags.contains('menu/$menuId'))
          .toList();
      final stubByTitle = {for (final s in stubs) s.title: s};

      // Sort meal tasks by dueAt for a stable order.
      tasks.sort((a, b) {
        final ad = a.dueAt;
        final bd = b.dueAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

      final imported = <_ImportedMeal>[];
      final recipeStates = <int, _RecipeState>{};
      MenuGoal? resolvedGoal;
      int? resolvedServings;
      for (final task in tasks) {
        final meta = _parseMealMeta(task.body);
        if (meta == null) continue;
        final ingredients = _parseIngredients(task.body);
        final stubKey = 'Рецепт: ${meta.mealName}';
        final stub = stubByTitle[stubKey];
        if (stub == null) continue;
        final idx = imported.length;
        imported.add(_ImportedMeal(
          taskId: task.id,
          recipeId: stub.id,
          meal: MenuMeal(
            name: meta.mealName,
            ingredients: ingredients,
          ),
          dayName: '',
          slotLabel: meta.slot,
        ));
        if (!stub.body.contains('Рецепт ещё не сгенерирован')) {
          recipeStates[idx] = _RecipeState.loaded(stub.body);
        }
        resolvedGoal ??= MenuGoal.fromWire(meta.goal);
        resolvedServings ??= meta.servings;
      }

      if (!mounted || imported.isEmpty) return;
      setState(() {
        _menuId = menuId;
        _imported
          ..clear()
          ..addAll(imported);
        _recipes
          ..clear()
          ..addAll(recipeStates);
        if (resolvedGoal != null) _values['goal'] = resolvedGoal.wire;
        if (resolvedServings != null) _values['servings'] = resolvedServings;
        _stage = _Stage.imported;
      });
    } catch (_) {
      // Resume is opportunistic — if anything goes wrong we silently
      // fall back to the form state, which is still fully functional.
    }
  }

  /// Parse the `<!-- noetica:meal {...} -->` marker our generator wrote
  /// into every meal task body. Returns null if the marker is missing
  /// or malformed (e.g. user manually edited the body).
  ({String mealName, String goal, int servings, String slot})? _parseMealMeta(
      String body) {
    final m = RegExp(r'<!-- noetica:meal (\{[\s\S]*?\}) -->').firstMatch(body);
    if (m == null) return null;
    try {
      final json = jsonDecode(m.group(1)!) as Map<String, Object?>;
      return (
        mealName: (json['meal_name'] as String?) ?? '',
        goal: (json['goal'] as String?) ?? 'classic',
        servings: (json['servings'] as num?)?.toInt() ?? 1,
        slot: (json['slot'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Pull the ingredients list out of a meal-task body that follows the
  /// generator's template (`## Ингредиенты\n- name — amount\n`). Best
  /// effort — we'll send what we find to the recipe endpoint.
  List<MenuIngredient> _parseIngredients(String body) {
    final lines = body.split('\n');
    final out = <MenuIngredient>[];
    var inSection = false;
    for (final line in lines) {
      if (line.trim() == '## Ингредиенты') {
        inSection = true;
        continue;
      }
      if (!inSection) continue;
      if (line.startsWith('## ') || line.startsWith('**КБЖУ')) break;
      final m = RegExp(r'^\s*-\s*(.+?)(?:\s+—\s+(.+?))?\s*$').firstMatch(line);
      if (m == null) continue;
      out.add(MenuIngredient(
        name: m.group(1)!.trim(),
        amount: (m.group(2) ?? '').trim(),
      ));
    }
    return out;
  }

  void _startNewMenu() {
    setState(() {
      _imported.clear();
      _recipes.clear();
      _menuId = null;
      _plan = null;
      _error = null;
      _seedValuesFromManifest();
      _stage = _Stage.form;
    });
  }

  Future<void> _confirmStartNewMenu() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать новое меню?'),
        content: const Text(
          'Текущие задачи и рецепты останутся в базе знаний — их можно '
          'найти по тегу menu/… или открыть по ссылке.\n\n'
          'Форма генерации откроется заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok == true) _startNewMenu();
  }

  // --------------------------------------------------------------- generate

  Future<void> _generate() async {
    setState(() {
      _stage = _Stage.generating;
      _error = null;
    });
    try {
      final api = ref.read(toolsApiProvider);
      final plan = await api.generateMenu(
        goal: _goal,
        servings: _servings,
        restrictions: _restrictions,
        extraNotes: _extraNotes,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = _Stage.form;
      });
    }
  }

  // --------------------------------------------------------------- import

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _stage = _Stage.importing;
      _error = null;
    });
    try {
      final repo = await ref.read(repositoryProvider.future);
      final menuId = const Uuid().v4();
      final imported = <_ImportedMeal>[];

      final axisIds = _selectedAxisId == null ? const <String>[] : [_selectedAxisId!];
      final menuTag = 'menu/$menuId';

      for (var d = 0; d < plan.days.length; d++) {
        final day = plan.days[d];
        final date = _startDate.add(Duration(days: d));
        final slots = <(MenuMeal? meal, int hour, int minute, String label, String emoji)>[
          (day.breakfast, 8, 0, 'Завтрак', '🌅'),
          (day.lunch, 13, 0, 'Обед', '🥗'),
          (day.dinner, 19, 0, 'Ужин', '🍽'),
          (day.snack, 16, 0, 'Перекус', '🍎'),
        ];
        for (final slot in slots) {
          final meal = slot.$1;
          if (meal == null) continue;
          final dueAt = DateTime(
            date.year, date.month, date.day, slot.$2, slot.$3,
          );
          final body = _renderMealBody(meal, slot.$4);
          final task = await repo.createEntry(
            title: '${slot.$5} ${slot.$4}: ${meal.name}',
            body: body,
            kind: EntryKind.task,
            dueAt: dueAt,
            xp: 10,
            axisIds: axisIds,
            tags: [menuTag, 'meal'],
          );
          // Pre-create a stub note for the recipe so wiki-link
          // navigation from the task body opens an empty note the
          // user can fill in later via "Сгенерировать рецепт".
          final recipeStub = await repo.createEntry(
            title: 'Рецепт: ${meal.name}',
            body: '_Рецепт ещё не сгенерирован._\n\nОткрой меню недели → '
                'нажми «Получить рецепт» рядом с этим блюдом.',
            kind: EntryKind.note,
            tags: [menuTag, 'recipe'],
          );
          imported.add(_ImportedMeal(
            taskId: task.id,
            recipeId: recipeStub.id,
            meal: meal,
            dayName: day.dayName,
            slotLabel: slot.$4,
          ));
          await repo.syncBodyLinks(task);
        }
      }

      // Shopping list as a single checklist note. The body uses the
      // same `- [ ] item` syntax that our task editor already renders
      // as ticking sub-tasks, so the user gets a working checklist
      // without any extra plumbing.
      final shopping = StringBuffer();
      shopping.writeln('# Список покупок на неделю');
      shopping.writeln();
      shopping.writeln('Цель: ${_goal.label} · $_servings порций');
      shopping.writeln();
      plan.shoppingList.forEach((category, items) {
        shopping.writeln('## $category');
        for (final ing in items) {
          final amount = ing.amount.isEmpty ? '' : ' — ${ing.amount}';
          shopping.writeln('- [ ] ${ing.name}$amount');
        }
        shopping.writeln();
      });
      await repo.createEntry(
        title: 'Список покупок · меню ${_humanRange()}',
        body: shopping.toString().trim(),
        kind: EntryKind.note,
        tags: [menuTag, 'shopping'],
      );

      if (!mounted) return;
      setState(() {
        _menuId = menuId;
        _imported
          ..clear()
          ..addAll(imported);
        _stage = _Stage.imported;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось импортировать меню: $e';
        _stage = _Stage.preview;
      });
    }
  }

  // --------------------------------------------------------------- recipes

  Future<void> _loadRecipe(int idx) async {
    final imported = _imported[idx];
    setState(() {
      _recipes[idx] = const _RecipeState.loading();
    });
    try {
      final api = ref.read(toolsApiProvider);
      final markdown = await api.generateRecipe(
        mealName: imported.meal.name,
        ingredients: imported.meal.ingredients,
        goal: _goal,
        servings: _servings,
      );
      final repo = await ref.read(repositoryProvider.future);
      // Persist into the recipe stub note so [[wiki-link]] navigation
      // from the meal task surfaces the full recipe.
      final entry = await repo.findEntryById(imported.recipeId);
      if (entry != null) {
        await repo.upsertEntry(entry.copyWith(
          body: markdown,
          updatedAt: DateTime.now(),
        ));
      }
      if (!mounted) return;
      setState(() {
        _recipes[idx] = _RecipeState.loaded(markdown);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recipes[idx] = _RecipeState.error(e.toString());
      });
    }
  }

  // --------------------------------------------------------------- helpers

  String _renderMealBody(MenuMeal meal, String slot) {
    final buf = StringBuffer();
    if (meal.ingredients.isNotEmpty) {
      buf.writeln('## Ингредиенты');
      for (final ing in meal.ingredients) {
        final amount = ing.amount.isEmpty ? '' : ' — ${ing.amount}';
        buf.writeln('- ${ing.name}$amount');
      }
      buf.writeln();
    }
    final macroParts = <String>[];
    if (meal.calories > 0) macroParts.add('${meal.calories} ккал');
    if (meal.protein > 0) macroParts.add('${meal.protein}б');
    if (meal.fat > 0) macroParts.add('${meal.fat}ж');
    if (meal.carbs > 0) macroParts.add('${meal.carbs}у');
    if (macroParts.isNotEmpty) {
      buf.writeln('**КБЖУ:** ${macroParts.join(' · ')}');
      buf.writeln();
    }
    buf.writeln('Полный рецепт: [[Рецепт: ${meal.name}]]');
    // Marker for downstream tooling (history view, recipe regen) so
    // we don't need a separate database table for `tools_runs`.
    buf.writeln();
    buf.writeln('<!-- noetica:meal ${jsonEncode({
      'meal_name': meal.name,
      'goal': _goal.wire,
      'servings': _servings,
      'slot': slot,
    })} -->');
    return buf.toString().trim();
  }

  String _humanRange() {
    final end = _startDate.add(const Duration(days: 6));
    return '${_d(_startDate)}–${_d(end)}';
  }

  String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Меню недели'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.form => _buildForm(palette),
          _Stage.generating => _buildBusy(palette, 'AI составляет меню…'),
          _Stage.preview => _buildPreview(palette),
          _Stage.importing => _buildBusy(palette, 'Создаю задачи и список покупок…'),
          _Stage.imported => _buildImported(palette),
        },
      ),
    );
  }

  Widget _buildForm(NoeticaPalette palette) {
    final theme = Theme.of(context);
    final axesAsync = ref.watch(axesProvider);
    final axes = axesAsync.valueOrNull ?? const <LifeAxis>[];
    if (axes.isNotEmpty && _selectedAxisId == null) {
      // Pre-select the most natural axis for nutrition. Falls back to
      // the first axis if no obvious match is found so we never push
      // the user back to "no axis" by default. Kept as a bespoke
      // helper because the manifest's single-substring `preferAxisHint`
      // can't express the full "тел/здоров/body/health/фитн" set.
      final body = axes.firstWhere(
        (a) => _looksLikeBodyAxis(a),
        orElse: () => axes.first,
      );
      _values['axis_id'] = body.id;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: TextStyle(color: palette.fg)),
          ),
        GeneratorFormView(
          fields: menuWeekInputs(),
          values: _values,
          axes: axes,
          onChanged: (id, v) => setState(() => _values[id] = v),
        ),
        const SizedBox(height: 8),
        // Range hint sits below the date so the form stays a clean
        // top-down list — the form view itself doesn't know about
        // "7-day window", that's still domain-specific to menu.
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '7 дней с ${_d(_startDate)} по ${_d(_startDate.add(const Duration(days: 6)))}',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Что я создам', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _bullet(palette, '21 задача (завтрак / обед / ужин на 7 дней)'),
              _bullet(palette, '1 заметка «Список покупок» с чек-листом'),
              _bullet(palette,
                  'Рецепты подгрузятся по тапу и сохранятся в связанные заметки'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Сгенерировать'),
          onPressed: _generate,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _bullet(NoeticaPalette palette, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 8),
              child: Container(
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: palette.muted, shape: BoxShape.circle),
              ),
            ),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: palette.muted, height: 1.4)),
            ),
          ],
        ),
      );

  Widget _buildBusy(NoeticaPalette palette, String label) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            Text(label, style: TextStyle(color: palette.muted)),
          ],
        ),
      );

  Widget _buildPreview(NoeticaPalette palette) {
    final plan = _plan!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_goal.label} · $_servings порций · ${_humanRange()}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan.dailyAvgCalories > 0)
                      Text(
                        '~${plan.dailyAvgCalories} ккал в день',
                        style: TextStyle(color: palette.muted),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Перегенерировать'),
                onPressed: _generate,
              ),
            ],
          ),
        ),
        if (plan.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(plan.notes,
                style: TextStyle(color: palette.muted, height: 1.4)),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: plan.days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, dayIdx) =>
                _DayCard(day: plan.days[dayIdx], palette: palette),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.download_for_offline_outlined),
            label: const Text('Импортировать в задачи'),
            onPressed: _import,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImported(NoeticaPalette palette) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: palette.fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Меню импортировано · ${_imported.length} задач',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _confirmStartNewMenu,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Новое меню'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Тег #${'menu/${(_menuId ?? '').substring(0, 8)}'} группирует все '
            'эти записи. Тапни блюдо — открой задачу. Нажми «Получить рецепт» '
            'на любом блюде — рецепт сохранится в связанной заметке.',
            style: TextStyle(color: palette.muted, height: 1.4),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: _imported.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              final m = _imported[idx];
              final state = _recipes[idx];
              return _MealRow(
                imported: m,
                state: state,
                palette: palette,
                onOpenTask: () => _openEntryById(m.taskId),
                onOpenRecipe: () => _openEntryById(m.recipeId),
                onLoadRecipe: () => _loadRecipe(idx),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openEntryById(String id) async {
    final repo = await ref.read(repositoryProvider.future);
    final entry = await repo.findEntryById(id);
    if (!mounted || entry == null) return;
    await showEntryEditor(context, ref, existing: entry);
  }
}

bool _looksLikeBodyAxis(LifeAxis a) {
  final name = a.name.toLowerCase();
  return name.contains('тел') ||
      name.contains('здоров') ||
      name.contains('body') ||
      name.contains('health') ||
      name.contains('фитн');
}

class _ImportedMeal {
  const _ImportedMeal({
    required this.taskId,
    required this.recipeId,
    required this.meal,
    required this.dayName,
    required this.slotLabel,
  });

  final String taskId;
  final String recipeId;
  final MenuMeal meal;
  final String dayName;
  final String slotLabel;
}

class _RecipeState {
  const _RecipeState._({this.loading = false, this.markdown, this.error});

  const _RecipeState.loading() : this._(loading: true);
  const _RecipeState.loaded(String markdown) : this._(markdown: markdown);
  const _RecipeState.error(String error) : this._(error: error);

  final bool loading;
  final String? markdown;
  final String? error;
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.palette});
  final MenuDay day;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(day.dayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          if (day.breakfast != null)
            _MealLine('Завтрак', day.breakfast!, palette),
          if (day.lunch != null) _MealLine('Обед', day.lunch!, palette),
          if (day.dinner != null) _MealLine('Ужин', day.dinner!, palette),
          if (day.snack != null) _MealLine('Перекус', day.snack!, palette),
        ],
      ),
    );
  }
}

class _MealLine extends StatelessWidget {
  const _MealLine(this.label, this.meal, this.palette);
  final String label;
  final MenuMeal meal;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: palette.muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (meal.calories > 0)
                  Text(
                    '${meal.calories} ккал · ${meal.protein}б/${meal.fat}ж/${meal.carbs}у',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.imported,
    required this.state,
    required this.palette,
    required this.onOpenTask,
    required this.onOpenRecipe,
    required this.onLoadRecipe,
  });

  final _ImportedMeal imported;
  final _RecipeState? state;
  final NoeticaPalette palette;
  final VoidCallback onOpenTask;
  final VoidCallback onOpenRecipe;
  final VoidCallback onLoadRecipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecipe = state?.markdown != null && state!.markdown!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '${imported.dayName}\n${imported.slotLabel}',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpenTask,
                  child: Text(
                    imported.meal.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (imported.meal.calories > 0)
                  Text(
                    '${imported.meal.calories} ккал · '
                    '${imported.meal.protein}б/${imported.meal.fat}ж/'
                    '${imported.meal.carbs}у',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.muted),
                  ),
                if (state?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(state!.error!,
                        style: TextStyle(color: palette.fg, fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (state?.loading == true)
            const SizedBox(
              width: 36, height: 36,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (hasRecipe)
            TextButton.icon(
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('Открыть'),
              onPressed: onOpenRecipe,
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Получить рецепт'),
              onPressed: onLoadRecipe,
            ),
        ],
      ),
    );
  }
}
