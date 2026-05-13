import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class SRu extends S {
  SRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'NOETICA';

  @override
  String get tabDashboard => 'Сейчас';

  @override
  String get tabSelf => 'Я';

  @override
  String get tabTasks => 'Задачи';

  @override
  String get tabMore => 'Ещё';

  @override
  String get navJournal => 'Журнал';

  @override
  String get navCalendar => 'Календарь';

  @override
  String get navKnowledge => 'Граф';

  @override
  String get navAssistant => 'Ассистент';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navPomodoro => 'Помодоро';

  @override
  String get navRoadmap => 'AI-План';

  @override
  String get navCoach => 'AI Коуч';

  @override
  String get sectionNow => 'СЕЙЧАС';

  @override
  String get sectionToday => 'СЕГОДНЯ';

  @override
  String get sectionPulse => 'ПУЛЬС';

  @override
  String get sectionRecent => 'ПОСЛЕДНЕЕ';

  @override
  String get sectionOverdue => 'ПРОСРОЧЕНО';

  @override
  String get sectionTomorrow => 'ЗАВТРА';

  @override
  String get sectionThisWeek => 'НА ЭТОЙ НЕДЕЛЕ';

  @override
  String get sectionLater => 'ПОЗЖЕ';

  @override
  String get sectionDone => 'ГОТОВО';

  @override
  String get sectionHeatmap => 'АКТИВНОСТЬ';

  @override
  String get sectionTree => 'ДРЕВО';

  @override
  String get sectionRecentlyClosed => 'НЕДАВНО ЗАКРЫТО';

  @override
  String get linkCalendar => 'календарь →';

  @override
  String get linkAll => 'все →';

  @override
  String get linkTasks => 'задачи →';

  @override
  String get freeDay => 'свободный день';

  @override
  String get filterAll => 'Все';

  @override
  String get filterOpen => 'Открытые';

  @override
  String get filterOverdue => 'Просроч.';

  @override
  String get filterDone => 'Готово';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionUndo => 'Отменить';

  @override
  String get actionDone => 'Готово';

  @override
  String get actionAdd => 'Добавить';

  @override
  String get actionEdit => 'Редактировать';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionExport => 'Экспорт';

  @override
  String get actionImport => 'Импорт';

  @override
  String get taskNew => 'Новая запись';

  @override
  String get taskComplete => 'Готово';

  @override
  String get taskSubtasks => 'Подзадачи';

  @override
  String get taskDueDate => 'Дедлайн';

  @override
  String get taskXp => 'XP';

  @override
  String get editorTitle => 'Заголовок';

  @override
  String get editorBody => 'Текст';

  @override
  String get editorTags => 'Теги';

  @override
  String get editorAddTag => 'добавить тег…';

  @override
  String get editorAxes => 'Оси';

  @override
  String get editorBacklinks => 'Сюда ссылаются';

  @override
  String get editorSubtasks => 'Подзадачи';

  @override
  String get selfBranches => 'Ветви';

  @override
  String get selfSettings => 'Настройки';

  @override
  String get selfEpoch => 'Эпоха';

  @override
  String get selfLevel => 'Уровень';

  @override
  String get selfStreak => 'Стрик';

  @override
  String get selfNewEpoch => 'Новая эпоха';

  @override
  String get selfDeepen => 'Углубиться';

  @override
  String get axisBody => 'Тело';

  @override
  String get axisMind => 'Ум';

  @override
  String get axisWork => 'Дело';

  @override
  String get axisSocial => 'Связи';

  @override
  String get axisSoul => 'Душа';

  @override
  String get onboardingName => 'Как тебя зовут?';

  @override
  String get onboardingGoals => 'Какие у тебя цели?';

  @override
  String get onboardingInterests => 'Что тебе интересно?';

  @override
  String get onboardingHours => 'Сколько часов в неделю?';

  @override
  String get onboardingContinue => 'Далее';

  @override
  String get onboardingFinish => 'Начать';

  @override
  String get pomodoroTitle => 'Помодоро';

  @override
  String get pomodoroStart => 'Старт';

  @override
  String get pomodoroPause => 'Пауза';

  @override
  String get pomodoroReset => 'Сброс';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsAccount => 'Аккаунт';

  @override
  String get settingsExport => 'Экспорт данных';

  @override
  String get settingsImport => 'Импорт данных';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsDarkMode => 'Тёмная тема';

  @override
  String get settingsLightMode => 'Светлая тема';

  @override
  String get knowledgeEmpty => 'База знаний пока пуста';

  @override
  String get knowledgeEmptyHint => 'Создайте первую заметку или задачу — они появятся здесь как узлы графа.';

  @override
  String get knowledgeCreateEntry => 'Создать запись';

  @override
  String get knowledgeGoals => 'Цели';

  @override
  String get knowledgeConstraints => 'Ограничения';

  @override
  String get knowledgeHighlights => 'Достижения';

  @override
  String get knowledgeReflections => 'Рефлексии';

  @override
  String get knowledgePreferences => 'Предпочтения';

  @override
  String get calendarTitle => 'Календарь';

  @override
  String get notesTitle => 'Журнал';

  @override
  String get deleteConfirm => 'Запись удалена';

  @override
  String get deleteUndone => 'Восстановлено';

  @override
  String get emptyTasks => 'Задач пока нет';

  @override
  String get emptyNotes => 'Заметок пока нет';

  @override
  String get greetingMorning => 'Доброе утро';

  @override
  String get greetingDay => 'Добрый день';

  @override
  String get greetingEvening => 'Добрый вечер';

  @override
  String get greetingNight => 'Доброй ночи';

  @override
  String get reflectionHow => 'Как прошло?';

  @override
  String get reflectionEasy => 'Легко';

  @override
  String get reflectionNormal => 'Нормально';

  @override
  String get reflectionHard => 'Сложно';

  @override
  String get reflectionSkip => 'Пропустить';

  @override
  String get weeklyReflection => 'Недельная рефлексия';

  @override
  String daysTotalStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      few: '$count дня',
      one: '1 день',
      zero: '0 дней',
    );
    return '$_temp0';
  }

  @override
  String get sortSmart => 'Умная';

  @override
  String get sortDueAsc => 'Срок ↑';

  @override
  String get sortCreatedDesc => 'Свежие';

  @override
  String get sortXpDesc => 'Тяжёлые сверху';

  @override
  String get tooltipSort => 'Сортировка';

  @override
  String get tooltipSettings => 'Настройки';

  @override
  String get noDate => 'Без даты';

  @override
  String get allAxes => 'Все оси';

  @override
  String get noAxis => 'Без оси';

  @override
  String get expandPlans => 'Развернуть планы';

  @override
  String get collapsePlans => 'Свернуть планы';

  @override
  String get weeklyMenu => 'Меню недели';

  @override
  String tasksInPlan(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'задач',
      few: 'задачи',
      one: 'задача',
    );
    return '$count $_temp0 в плане';
  }

  @override
  String plansCount(int count) {
    return 'Планы ($count)';
  }

  @override
  String get emptyFilterTitle => 'Под фильтр ничего не попало';

  @override
  String get emptyFilterHint => 'Сбрось фильтры или поменяй сортировку, чтобы увидеть остальные задачи.';

  @override
  String get emptyTasksTitle => 'Задач нет';

  @override
  String get emptyTasksHint => 'Создай задачу через «+». Привяжи её к осям — выполнение начислит очки в пентаграмму.';

  @override
  String get sectionAccount => 'Аккаунт';

  @override
  String get sectionProfile => 'Профиль';

  @override
  String get sectionAxes => 'Оси роста';

  @override
  String get sectionNotifications => 'Уведомления';

  @override
  String get sectionBackend => 'Бэкенд';

  @override
  String get sectionData => 'Данные';

  @override
  String get sectionAbout => 'О приложении';

  @override
  String get sectionDeveloper => '⚙ Разработчик';

  @override
  String get settingsLogout => 'Выйти';

  @override
  String get settingsSyncNow => 'Синхронизировать сейчас';

  @override
  String get settingsSyncHint => 'Стянуть данные с облака и отправить локальные изменения';

  @override
  String get settingsNotLoggedIn => 'Не выполнен вход';

  @override
  String get settingsNotLoggedInHint => 'Перезапустите приложение, чтобы войти.';

  @override
  String get settingsNoName => 'Без имени';

  @override
  String get settingsNoGoal => 'Цель не указана';

  @override
  String get settingsRegenAxes => 'Перегенерировать оси';

  @override
  String get settingsRegenAxesNoInterests => 'Добавь интересы в профиле, чтобы AI собрал оси';

  @override
  String settingsRegenAxesHint(int count) {
    return 'AI пересоберёт оси по $count интересам';
  }

  @override
  String get settingsNotificationsUnsupported => 'Уведомления здесь не поддерживаются';

  @override
  String get settingsLocalNotifications => 'Локальные уведомления';

  @override
  String get settingsLocalNotificationsHint => 'За 1 день, утром, и через час после дедлайна';

  @override
  String get settingsMorningReminder => 'Утреннее напоминание';

  @override
  String get settingsCoachReminders => 'AI-коуч напоминания';

  @override
  String get settingsCoachRemindersHint => 'Утренний план и вечерний разбор';

  @override
  String get settingsEveningReview => 'Вечерний разбор';

  @override
  String get settingsExportJson => 'Экспорт в JSON';

  @override
  String get settingsExportJsonHint => 'Сохранить профиль, оси и записи в файл';

  @override
  String get settingsImportJson => 'Импорт из JSON';

  @override
  String get settingsImportJsonHint => 'Восстановить данные из буфера обмена';

  @override
  String get settingsEraseAll => 'Стереть все данные';

  @override
  String get settingsEraseAllHint => 'Возврат к экрану онбординга';

  @override
  String get settingsSourceCode => 'Исходный код';

  @override
  String get settingsVersion => 'v0.1.0 — minimalist growth tracker';

  @override
  String get dialogImportTitle => 'Импорт данных';

  @override
  String get dialogImportBody => 'Вставьте JSON экспорта из буфера обмена. Существующие данные объединятся с импортом (entry ID используется для дедупликации).';

  @override
  String get dialogPasteClipboard => 'Вставить из буфера';

  @override
  String get dialogEraseTitle => 'Стереть все данные?';

  @override
  String get dialogEraseBody => 'Удалятся профиль, оси, задачи, заметки и настройки. Действие необратимо.';

  @override
  String get dialogErase => 'Стереть';

  @override
  String get dialogLogoutTitle => 'Выйти из аккаунта?';

  @override
  String get dialogLogoutBody => 'Локальные данные останутся на устройстве. Чтобы они снова синхронизировались, войдите тем же Google-аккаунтом.';

  @override
  String snackExportSaved(String path) {
    return 'Сохранён: $path';
  }

  @override
  String get snackCopy => 'Копировать';

  @override
  String snackExportError(String error) {
    return 'Не удалось экспортировать: $error';
  }

  @override
  String get snackClipboardEmpty => 'Буфер обмена пуст.';

  @override
  String snackImportSuccess(int count) {
    return 'Импортировано $count записей.';
  }

  @override
  String snackImportError(String error) {
    return 'Не удалось импортировать: $error';
  }

  @override
  String snackEraseError(String error) {
    return 'Не удалось стереть: $error';
  }

  @override
  String get snackSyncing => 'Синхронизация…';

  @override
  String get snackSyncDone => 'Готово. Данные подтянуты с облака.';

  @override
  String snackSyncError(String error) {
    return 'Не удалось: $error';
  }

  @override
  String snackLogoutError(String error) {
    return 'Не удалось выйти: $error';
  }

  @override
  String get loadingBackends => 'Загрузка…';

  @override
  String get loadingBackendsHint => 'Подгружаем список бэкендов…';

  @override
  String get reflectionDidNotGo => 'Не пошло';

  @override
  String get reflectionDifficult => 'Сложно';

  @override
  String get reflectionOk => 'Норм';

  @override
  String get reflectionEasyShort => 'Легко';

  @override
  String get entryKindTask => 'Задача';

  @override
  String get entryKindNote => 'Заметка';

  @override
  String get entryKindHabit => 'Привычка';
}
