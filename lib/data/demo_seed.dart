import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';
import 'profile.dart';
import 'repository.dart';
import '../providers.dart' show markOnboarded;

const _uuid = Uuid();

/// Seeds the local database with realistic demo data so the app looks
/// fully populated for a video presentation. Only runs once per
/// installation (checks a SharedPreferences flag).
Future<void> seedDemoDataIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('noetica.demo_seeded') == true) return;

  // 1. Open the database.
  final db = await NoeticaDb.open();

  // 2. Save a user profile.
  await _seedProfile(db);
  final repo = NoeticaRepository(db);

  final axes = await _seedAxes(repo);
  await _seedEntries(repo, axes);

  // 3. Mark onboarded so the app goes straight to HomeShell.
  await markOnboarded();
  await prefs.setBool('noetica.demo_seeded', true);
}

Future<void> _seedProfile(NoeticaDb db) async {
  final profile = UserProfile(
    name: 'Алексей',
    aspiration: 'Стать лучшей версией себя: развивать тело, ум и душу',
    interests: [
      'Программирование',
      'Спорт',
      'Чтение',
      'Медитация',
      'Финансы',
    ],
    interestLevels: {
      'Программирование': 'confident',
      'Спорт': 'learning',
      'Чтение': 'confident',
      'Медитация': 'novice',
      'Финансы': 'learning',
    },
    painPoint: 'Не хватает дисциплины, чтобы поддерживать привычки каждый день',
    weeklyHours: 10,
    updatedAt: DateTime.now(),
    currentEpoch: 1,
    epochStartedAt: DateTime.now().subtract(const Duration(days: 30)),
    epochTier: 1,
  );
  final svc = ProfileService(db);
  await svc.save(profile);
}

Future<List<LifeAxis>> _seedAxes(NoeticaRepository repo) async {
  final defs = <Map<String, dynamic>>[
    {'name': 'Тело', 'symbol': '◐', 'pos': 0},
    {'name': 'Ум', 'symbol': '◇', 'pos': 1},
    {'name': 'Дело', 'symbol': '■', 'pos': 2},
    {'name': 'Связи', 'symbol': '◯', 'pos': 3},
    {'name': 'Душа', 'symbol': '✦', 'pos': 4},
  ];
  final axes = <LifeAxis>[];
  for (final d in defs) {
    final a = await repo.createAxis(
      name: d['name'] as String,
      symbol: d['symbol'] as String,
      position: d['pos'] as int,
    );
    axes.add(a);
  }
  return axes;
}

Future<void> _seedEntries(
    NoeticaRepository repo, List<LifeAxis> axes) async {
  final now = DateTime.now();
  final rng = Random(42);

  // Helper to get a random subset of axis IDs.
  List<String> pickAxes(List<int> indices) =>
      indices.map((i) => axes[i].id).toList();

  // ---------- Completed tasks (various days) ----------

  final completedTasks = <Map<String, dynamic>>[
    {
      'title': 'Утренняя пробежка 5 км',
      'body': 'Маршрут: парк — набережная — парк. Темп 5:30.',
      'xp': 15,
      'axes': [0],
      'daysAgo': 1,
    },
    {
      'title': 'Прочитать 30 страниц «Думай медленно, решай быстро»',
      'body':
          'Глава про систему 1 и систему 2. Очень интересно про когнитивные искажения.',
      'xp': 12,
      'axes': [1],
      'daysAgo': 1,
    },
    {
      'title': 'Code review фронтенда',
      'body': 'Ревью PR по рефакторингу модуля авторизации.',
      'xp': 20,
      'axes': [2],
      'daysAgo': 1,
    },
    {
      'title': 'Медитация 15 минут',
      'body': 'Сессия осознанного дыхания. Фокус на теле.',
      'xp': 10,
      'axes': [4],
      'daysAgo': 1,
    },
    {
      'title': 'Тренировка в зале — верхняя группа',
      'body':
          'Жим лёжа 4×8, тяга верхнего блока 3×12, жим гантелей 3×10, разводка 3×15.',
      'xp': 18,
      'axes': [0],
      'daysAgo': 2,
    },
    {
      'title': 'Написать статью на Хабр',
      'body':
          'Тема: «Как мы внедрили Riverpod в наш Flutter-проект». Черновик готов, нужно вычитать.',
      'xp': 25,
      'axes': [1, 2],
      'daysAgo': 2,
    },
    {
      'title': 'Позвонить родителям',
      'body': '',
      'xp': 8,
      'axes': [3],
      'daysAgo': 2,
    },
    {
      'title': 'Планирование бюджета на месяц',
      'body':
          'Записать все доходы и расходы. Цель — откладывать 20% от зарплаты.',
      'xp': 15,
      'axes': [2],
      'daysAgo': 3,
    },
    {
      'title': 'Йога утренняя — 30 минут',
      'body': 'Комплекс Сурья Намаскар × 5 циклов.',
      'xp': 12,
      'axes': [0, 4],
      'daysAgo': 3,
    },
    {
      'title': 'Закончить модуль уведомлений',
      'body':
          'Реализация push-уведомлений для iOS и Android. Тестирование с firebase.',
      'xp': 30,
      'axes': [2],
      'daysAgo': 4,
    },
    {
      'title': 'Встреча с ментором',
      'body':
          'Обсудили карьерный план на следующие 6 месяцев. Фокус на системный дизайн.',
      'xp': 20,
      'axes': [1, 2, 3],
      'daysAgo': 5,
    },
    {
      'title': 'Плавание 1 км',
      'body': 'Бассейн 50м, кроль и брасс по 500м.',
      'xp': 15,
      'axes': [0],
      'daysAgo': 5,
    },
    {
      'title': 'Прочитать «Atomic Habits» — главы 5-8',
      'body':
          'Стратегия стекирования привычек. Привязка новой привычки к существующему триггеру.',
      'xp': 14,
      'axes': [1],
      'daysAgo': 6,
    },
    {
      'title': 'Ужин с друзьями',
      'body': 'Ресторан грузинской кухни. Обсуждали планы на лето.',
      'xp': 10,
      'axes': [3],
      'daysAgo': 7,
    },
    {
      'title': 'Написать unit-тесты для API модуля',
      'body': 'Покрытие: auth, entries, sync. ~85% coverage.',
      'xp': 22,
      'axes': [2],
      'daysAgo': 8,
    },
    {
      'title': 'Дыхательная практика Вим Хофа',
      'body': '3 раунда × 30 вдохов. Задержка: 1:45, 2:10, 2:30.',
      'xp': 12,
      'axes': [0, 4],
      'daysAgo': 9,
    },
    {
      'title': 'Изучить основы Kubernetes',
      'body':
          'Прошёл курс на Udemy — pods, services, deployments. Развернул тестовый кластер.',
      'xp': 25,
      'axes': [1, 2],
      'daysAgo': 10,
    },
    {
      'title': 'Благодарственный дневник',
      'body':
          '1. Здоровье\n2. Возможность работать удалённо\n3. Поддержка семьи',
      'xp': 8,
      'axes': [4],
      'daysAgo': 10,
    },
    {
      'title': 'Пробежка 7 км — новый рекорд',
      'body': 'Темп 5:15! Прогресс ощутимый.',
      'xp': 20,
      'axes': [0],
      'daysAgo': 12,
    },
    {
      'title': 'Вебинар по инвестициям',
      'body': 'Диверсификация портфеля. ETF vs отдельные акции.',
      'xp': 15,
      'axes': [1, 2],
      'daysAgo': 14,
    },
  ];

  for (final t in completedTasks) {
    final daysAgo = t['daysAgo'] as int;
    final createdAt = now.subtract(Duration(days: daysAgo, hours: rng.nextInt(12)));
    final completedAt = createdAt.add(Duration(hours: 1 + rng.nextInt(4)));
    final axisIndices = t['axes'] as List<int>;

    final entry = Entry(
      id: _uuid.v4(),
      title: t['title'] as String,
      body: t['body'] as String,
      kind: EntryKind.task,
      createdAt: createdAt,
      updatedAt: completedAt,
      completedAt: completedAt,
      xp: t['xp'] as int,
      axisIds: pickAxes(axisIndices),
    );
    await repo.upsertEntry(entry);
  }

  // ---------- Open tasks (today / upcoming) ----------

  final openTasks = <Map<String, dynamic>>[
    {
      'title': 'Тренировка ног в зале',
      'body': 'Приседания 4×8, жим ногами 3×12, выпады 3×10.',
      'xp': 18,
      'axes': [0],
      'dueDays': 0,
    },
    {
      'title': 'Закончить рефакторинг state management',
      'body':
          'Перевести 3 оставшихся экрана на Riverpod. Убрать legacy Provider.',
      'xp': 25,
      'axes': [2],
      'dueDays': 0,
    },
    {
      'title': 'Вечерняя медитация',
      'body': 'Сканирование тела — 20 минут.',
      'xp': 10,
      'axes': [4],
      'dueDays': 0,
    },
    {
      'title': 'Подготовить презентацию для стендапа',
      'body': 'Итоги спринта, метрики, планы на следующую неделю.',
      'xp': 15,
      'axes': [2, 3],
      'dueDays': 1,
    },
    {
      'title': 'Прочитать 20 страниц «Мастер и Маргарита»',
      'body': '',
      'xp': 10,
      'axes': [1],
      'dueDays': 1,
    },
    {
      'title': 'Записаться на курс по системному дизайну',
      'body': 'Сравнить: Educative vs Grokking.',
      'xp': 12,
      'axes': [1, 2],
      'dueDays': 3,
    },
    {
      'title': 'Организовать поход с друзьями',
      'body': 'Маршрут, снаряжение, дата — согласовать в группе.',
      'xp': 15,
      'axes': [0, 3],
      'dueDays': 5,
    },
    {
      'title': 'Написать еженедельную рефлексию',
      'body': '',
      'xp': 10,
      'axes': [4],
      'dueDays': 2,
    },
  ];

  for (final t in openTasks) {
    final dueDays = t['dueDays'] as int;
    final dueAt = DateTime(now.year, now.month, now.day)
        .add(Duration(days: dueDays, hours: 18));
    final createdAt = now.subtract(Duration(days: rng.nextInt(3)));
    final axisIndices = t['axes'] as List<int>;

    final entry = Entry(
      id: _uuid.v4(),
      title: t['title'] as String,
      body: t['body'] as String,
      kind: EntryKind.task,
      createdAt: createdAt,
      updatedAt: createdAt,
      dueAt: dueAt,
      xp: t['xp'] as int,
      axisIds: pickAxes(axisIndices),
    );
    await repo.upsertEntry(entry);
  }

  // ---------- Journal notes ----------

  final notes = <Map<String, dynamic>>[
    {
      'title': 'Мысли о продуктивности',
      'body':
          'Заметил, что самые продуктивные часы — с 9 до 12 утра. '
              'Нужно перенести сложные задачи на это время и защитить '
              'этот блок от встреч.\n\n'
              'Также помогает «правило двух минут»: если задача занимает '
              'меньше 2 минут — делай сразу.',
      'daysAgo': 1,
      'tags': ['рефлексия', 'продуктивность'],
    },
    {
      'title': 'Цитата дня: Марк Аврелий',
      'body':
          '«Счастье твоей жизни зависит от качества твоих мыслей».\n\n'
              'Стоицизм учит, что мы не контролируем внешние события, '
              'но контролируем свою реакцию на них.',
      'daysAgo': 2,
      'tags': ['цитаты', 'философия'],
    },
    {
      'title': 'Идея: трекер привычек в Noetica',
      'body':
          'Было бы круто добавить визуальный streak-трекер для ежедневных '
              'привычек. GitHub-style heatmap, но для личных привычек.\n\n'
              '**MVP:** простой список привычек + чекбокс на каждый день.',
      'daysAgo': 3,
      'tags': ['идеи', 'проект'],
    },
    {
      'title': 'Итоги недели #18',
      'body':
          '**Что получилось:**\n'
              '- Пробежал 3 раза (15 км за неделю)\n'
              '- Закончил модуль авторизации\n'
              '- Прочитал 80 страниц\n\n'
              '**Над чем поработать:**\n'
              '- Медитация пока нестабильная (2/7 дней)\n'
              '- Сон: ложусь поздно, нужно раньше\n\n'
              '**Настроение:** 7/10',
      'daysAgo': 7,
      'tags': ['итоги', 'рефлексия'],
      'bookmarked': true,
    },
    {
      'title': 'Рецепт: смузи для восстановления',
      'body':
          '- 1 банан\n'
              '- 200 мл миндального молока\n'
              '- 30г протеина\n'
              '- 1 ст.л. арахисовой пасты\n'
              '- Горсть шпината\n\n'
              'Отлично после утренней тренировки!',
      'daysAgo': 5,
      'tags': ['питание', 'рецепты'],
    },
  ];

  for (final n in notes) {
    final daysAgo = n['daysAgo'] as int;
    final createdAt = now.subtract(Duration(days: daysAgo, hours: rng.nextInt(8)));
    final tags = (n['tags'] as List<String>?) ?? [];

    final entry = Entry(
      id: _uuid.v4(),
      title: n['title'] as String,
      body: n['body'] as String,
      kind: EntryKind.note,
      createdAt: createdAt,
      updatedAt: createdAt,
      xp: 5,
      tags: tags,
      bookmarked: (n['bookmarked'] as bool?) ?? false,
    );
    await repo.upsertEntry(entry);
  }

  // ---------- Overdue task ----------

  final overdueEntry = Entry(
    id: _uuid.v4(),
    title: 'Обновить резюме на LinkedIn',
    body: 'Добавить последний проект и обновить навыки.',
    kind: EntryKind.task,
    createdAt: now.subtract(const Duration(days: 5)),
    updatedAt: now.subtract(const Duration(days: 5)),
    dueAt: now.subtract(const Duration(days: 2)),
    xp: 12,
    axisIds: [axes[2].id, axes[3].id],
  );
  await repo.upsertEntry(overdueEntry);
}
