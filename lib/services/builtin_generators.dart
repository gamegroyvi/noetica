import 'package:flutter/material.dart';

import '../features/tools/menu/menu_generator_screen.dart';
import 'generator_input.dart';
import 'generator_manifest.dart';
import 'generator_run_spec.dart';

/// System prompt for the «Микро-привычки» builtin. Carries the
/// hard-won «≤ 2 minutes» rule the bespoke `prompts_habits.py`
/// enforced. Uses `{duration_days}` and `{axis_id_name}` placeholders
/// the universal runtime resolves before the LLM call.
const String _habitsSystemPromptText = 'Ты — Noetica-коуч по микро-'
    'привычкам. Преврати желание пользователя в план из '
    'ровно {duration_days} крошечных ежедневных действий.\n\n'
    'ПРАВИЛА:\n'
    '1. Каждое действие — НЕ БОЛЬШЕ 2 минут реального усилия. '
    '«Завести таймер на 60 секунд», «положить телефон в другую '
    'комнату», «выпить стакан воды». НЕ «помедитировать 20 минут», '
    'НЕ «сходить в зал». Если по другому никак — раздели на два дня.\n'
    '2. Дни идут по нарастающей: первый элемент — самое лёгкое '
    '(тренируем появление), последний — закрепляющий ритуал.\n'
    '3. Не повторяй формулировки. Каждый элемент — новое микро-'
    'действие или эволюция вчерашнего (2–3 шт. подряд можно как '
    '«связка»).\n'
    '4. `title` — императивный, на «ты», ≤ 80 символов.\n'
    '5. `body` — ОДНО предложение, до 200 символов. Зачем '
    'именно это действие, без воды, без «это поможет тебе…».\n'
    '6. Отвечай на ТОМ ЖЕ языке, на котором написан intent.\n'
    '7. Сфера (если указана): {axis_id_name}. Не уходи в смежные темы.';

const String _habitsUserPromptText = 'Цель пользователя:\n{intent}\n\n'
    'Длительность: ровно {duration_days} дней.\n\n'
    'Дополнительно: {notes}\n\n'
    'Сгенерируй ровно {duration_days} элементов в массиве `items` — '
    'по одному на каждый день, в порядке от лёгкого к закрепляющему.';

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
        // Universal runtime — no bespoke `builder`. /tools/run renders
        // these templates server-side and returns generic items.
        promptSystem: _habitsSystemPromptText,
        promptUser: _habitsUserPromptText,
        // Worst-case cap; the prompt asks for exactly N items via
        // the `{duration_days}` placeholder, so the runtime trims if
        // the LLM returns more.
        maxItems: 21,
        temperature: 0.6,
        importSpec: const GeneratorImportSpec(
          importAs: GeneratorImportTarget.task,
          dueStrategy: GeneratorDueStrategy.ladder,
          dueHourLocal: 9,
          axisIdInputId: 'axis_id',
          tagPrefix: 'challenge',
          xpPerItem: 5,
        ),
      ),
    ];

BuiltinGeneratorRegistry buildBuiltinGeneratorRegistry() =>
    BuiltinGeneratorRegistry(defaultBuiltinManifests());
