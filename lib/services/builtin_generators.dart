import 'package:flutter/material.dart';

import '../features/tools/menu/menu_generator_screen.dart';
import 'generator_manifest.dart';

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
      const GeneratorManifest(
        id: 'micro-habits',
        title: 'Микро-привычки',
        description: '7-дневный челлендж из коротких ежедневных задач.',
        icon: Icons.eco_outlined,
        status: GeneratorStatus.soon,
        category: 'discipline',
        bullets: [
          'Подбираем под выбранную ось',
          'Серии и стрик-счётчик из коробки',
        ],
      ),
    ];

BuiltinGeneratorRegistry buildBuiltinGeneratorRegistry() =>
    BuiltinGeneratorRegistry(defaultBuiltinManifests());
