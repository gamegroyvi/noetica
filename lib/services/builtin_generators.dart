import 'package:flutter/material.dart';

import '../features/tools/habits/habits_generator_screen.dart';
import '../features/tools/menu/menu_generator_screen.dart';
import '../l10n/generated/app_localizations.dart';
import 'generator_input.dart';
import 'generator_manifest.dart';

/// Form schema for the «Меню недели» generator.
List<GeneratorInputField> menuWeekInputs(S tr) => [
      GeneratorInputEnum(
        id: 'goal',
        label: tr.genMenuGoal,
        required: true,
        options: [
          GeneratorEnumOption(value: 'classic', label: tr.genMenuClassic),
          GeneratorEnumOption(value: 'lose_weight', label: tr.genMenuLoseWeight),
          GeneratorEnumOption(value: 'health', label: tr.genMenuHealth),
          GeneratorEnumOption(value: 'muscle', label: tr.genMenuMuscle),
          GeneratorEnumOption(value: 'energy', label: tr.genMenuEnergy),
        ],
        initial: 'classic',
      ),
      GeneratorInputInt(
        id: 'servings',
        label: tr.genMenuServings,
        required: true,
        min: 1,
        max: 6,
        initial: 1,
        presentation: IntInputPresentation.chips,
      ),
      GeneratorInputDate(
        id: 'start_date',
        label: tr.genMenuStart,
        required: true,
        daysBefore: 7,
        daysAfter: 60,
      ),
      GeneratorInputAxisRef(
        id: 'axis_id',
        label: tr.genMenuAxis,
        help: tr.genMenuAxisHelp,
        preferAxisHint: 'тело',
      ),
      GeneratorInputText(
        id: 'restrictions',
        label: tr.genMenuRestrictions,
        placeholder: tr.genMenuRestrictionsHint,
        multiline: true,
        minLines: 1,
        maxLines: 3,
      ),
      GeneratorInputText(
        id: 'notes',
        label: tr.genMenuNotes,
        placeholder: tr.genMenuNotesHint,
        multiline: true,
        minLines: 2,
        maxLines: 4,
      ),
    ];

/// Form schema for the «Микро-привычки» generator.
List<GeneratorInputField> habitsInputs(S tr) => [
      GeneratorInputText(
        id: 'intent',
        label: tr.genHabitIntent,
        required: true,
        placeholder: tr.genHabitIntentHint,
        multiline: true,
        minLines: 2,
        maxLines: 4,
      ),
      GeneratorInputInt(
        id: 'duration_days',
        label: tr.genHabitDays,
        required: true,
        min: 3,
        max: 21,
        initial: 7,
        presentation: IntInputPresentation.chips,
      ),
      GeneratorInputAxisRef(
        id: 'axis_id',
        label: tr.genHabitAxis,
        help: tr.genHabitAxisHelp,
      ),
      GeneratorInputText(
        id: 'notes',
        label: tr.genHabitNotes,
        placeholder: tr.genHabitNotesHint,
        multiline: true,
        minLines: 1,
        maxLines: 3,
      ),
    ];

/// All hand-coded generators known to this build.
List<GeneratorManifest> defaultBuiltinManifests(S tr) => [
      GeneratorManifest(
        id: 'menu-week',
        title: tr.genMenuTitle,
        description: tr.genMenuDesc,
        icon: Icons.restaurant_menu_outlined,
        status: GeneratorStatus.available,
        category: 'health',
        bullets: [
          tr.genMenuBullet1,
          tr.genMenuBullet2,
          tr.genMenuBullet3,
        ],
        inputs: menuWeekInputs(tr),
        builder: (_) => const MenuGeneratorScreen(),
      ),
      GeneratorManifest(
        id: 'training-program',
        title: tr.genTrainingTitle,
        description: tr.genTrainingDesc,
        icon: Icons.fitness_center_outlined,
        status: GeneratorStatus.soon,
        category: 'health',
        bullets: [
          tr.genTrainingBullet1,
          tr.genTrainingBullet2,
        ],
      ),
      GeneratorManifest(
        id: 'study-plan',
        title: tr.genStudyTitle,
        description: tr.genStudyDesc,
        icon: Icons.menu_book_outlined,
        status: GeneratorStatus.soon,
        category: 'mind',
        bullets: [
          tr.genStudyBullet1,
          tr.genStudyBullet2,
        ],
      ),
      GeneratorManifest(
        id: 'micro-habits',
        title: tr.genHabitsTitle,
        description: tr.genHabitsDesc,
        icon: Icons.eco_outlined,
        status: GeneratorStatus.available,
        category: 'discipline',
        bullets: [
          tr.genHabitsBullet1,
          tr.genHabitsBullet2,
          tr.genHabitsBullet3,
        ],
        inputs: habitsInputs(tr),
        builder: (_) => const HabitsGeneratorScreen(),
      ),
    ];

BuiltinGeneratorRegistry buildBuiltinGeneratorRegistry(S tr) =>
    BuiltinGeneratorRegistry(defaultBuiltinManifests(tr));
