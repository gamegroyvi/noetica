import 'package:flutter/material.dart';

import '../features/tools/habits/habits_generator_screen.dart';
import '../features/tools/menu/menu_generator_screen.dart';
import 'generator_input.dart';
import 'generator_manifest.dart';

/// Form schema for the «Меню недели» generator. Kept as a top-level
/// constant so tests can verify the shape and the future authoring
/// UI can use it as the canonical example of a builtin manifest.
List<GeneratorInputField> menuWeekInputs() => const [
      GeneratorInputEnum(
        id: 'goal',
        label: 'Цель питания',
        required: true,
        // Wire values match the backend's `MenuGoal` literal — keep in
        // sync with `lib/services/tools_api.dart#MenuGoal`.
        options: [
          GeneratorEnumOption(value: 'classic', label: 'Сбалансированно'),
          GeneratorEnumOption(value: 'lose_weight', label: 'Похудение'),
          GeneratorEnumOption(value: 'health', label: 'Здоровье'),
          GeneratorEnumOption(value: 'muscle', label: 'Набор мышц'),
          GeneratorEnumOption(value: 'energy', label: 'Энергия / спорт'),
        ],
        initial: 'classic',
      ),
      GeneratorInputInt(
        id: 'servings',
        label: 'Порций',
        required: true,
        min: 1,
        max: 6,
        initial: 1,
        presentation: IntInputPresentation.chips,
      ),
      GeneratorInputDate(
        id: 'start_date',
        label: 'Старт меню',
        required: true,
        daysBefore: 7,
        daysAfter: 60,
      ),
      GeneratorInputAxisRef(
        id: 'axis_id',
        label: 'Ось роста',
        help:
            '21 задача добавится к выбранной оси и будет давать XP при '
            'отметке «выполнено».',
        preferAxisHint: 'тело',
      ),
      GeneratorInputText(
        id: 'restrictions',
        label: 'Ограничения (опционально)',
        placeholder: 'без глютена; без свинины; вегетарианец',
        multiline: true,
        minLines: 1,
        maxLines: 3,
      ),
      GeneratorInputText(
        id: 'notes',
        label: 'Доп. пожелания (опционально)',
        placeholder:
            'минимум готовки в будни; больше рыбы; быстрые завтраки',
        multiline: true,
        minLines: 2,
        maxLines: 4,
      ),
    ];

/// Form schema for the «Микро-привычки» generator. Same authoring
/// surface as `menuWeekInputs()` — pure declaration of fields, no
/// behaviour. The screen wires defaults and reads values by id.
List<GeneratorInputField> habitsInputs() => const [
      GeneratorInputText(
        id: 'intent',
        label: 'Какую привычку хочешь освоить?',
        required: true,
        placeholder:
            'хочу засыпать раньше · перестать залипать в телефон утром · '
            'пить больше воды',
        multiline: true,
        minLines: 2,
        maxLines: 4,
      ),
      GeneratorInputInt(
        id: 'duration_days',
        label: 'Сколько дней',
        required: true,
        // Min matches `HabitsRequest.duration_days` ge=3 on the
        // backend; max matches le=30.
        min: 3,
        max: 21,
        initial: 7,
        presentation: IntInputPresentation.chips,
      ),
      GeneratorInputAxisRef(
        id: 'axis_id',
        label: 'Ось роста',
        help:
            'Все мини-задачи получат XP от выполнения и будут расти '
            'вместе с этой осью.',
      ),
      GeneratorInputText(
        id: 'notes',
        label: 'Доп. пожелания (опционально)',
        placeholder:
            'буду делать утром · уже пробовал, не получалось · '
            'хочу без приложений',
        multiline: true,
        minLines: 1,
        maxLines: 3,
      ),
    ];

/// All hand-coded generators known to this build. Edit this list when
/// adding a new builtin tool — the catalog screen, deep-links, and
/// (eventually) analytics all read from here.
///
/// New builtins should land in this list with `status: soon` first
/// (catalog placeholder), then flip to `available` + a `builder`
/// in the same PR that ships the actual runtime.
List<GeneratorManifest> defaultBuiltinManifests() => [
      GeneratorManifest(
        id: 'menu-week',
        title: 'Меню недели',
        description:
            '7 дней × завтрак / обед / ужин с КБЖУ под твою цель питания.',
        icon: Icons.restaurant_menu_outlined,
        status: GeneratorStatus.available,
        category: 'health',
        bullets: const [
          '21 задача на оси «Тело» с дедлайнами',
          'Список покупок отдельной заметкой-чеклистом',
          'Полные рецепты подгружаются по тапу',
        ],
        inputs: menuWeekInputs(),
        builder: (_) => const MenuGeneratorScreen(),
      ),
      const GeneratorManifest(
        id: 'training-program',
        title: 'План тренировок',
        description:
            'Программа на 4 недели под цель: сила, выносливость, рекомпозиция.',
        icon: Icons.fitness_center_outlined,
        status: GeneratorStatus.soon,
        category: 'health',
        bullets: [
          'Учитывает доступное оборудование',
          'Каждое занятие — задача с подходами в подзадачах',
        ],
      ),
      const GeneratorManifest(
        id: 'study-plan',
        title: 'Учебный план',
        description:
            'Декомпозиция «выучить X» на занятия с заметками-конспектами.',
        icon: Icons.menu_book_outlined,
        status: GeneratorStatus.soon,
        category: 'mind',
        bullets: [
          'Уроки = задачи на оси «Разум»',
          'Конспекты — заметки, связанные [[wiki-ссылками]]',
        ],
      ),
      GeneratorManifest(
        id: 'micro-habits',
        title: 'Микро-привычки',
        description: '7-дневный челлендж из коротких ежедневных задач.',
        icon: Icons.eco_outlined,
        status: GeneratorStatus.available,
        category: 'discipline',
        bullets: const [
          'Каждое действие ≤ 2 минут — реально доходишь',
          'Подбираем под выбранную ось, идут по нарастающей',
          'Появятся в Задачах с дедлайнами по дням',
        ],
        inputs: habitsInputs(),
        builder: (_) => const HabitsGeneratorScreen(),
      ),
    ];

BuiltinGeneratorRegistry buildBuiltinGeneratorRegistry() =>
    BuiltinGeneratorRegistry(defaultBuiltinManifests());
