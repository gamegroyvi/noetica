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
  String get editorTitle => 'Название';

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
  String selfEpoch(int n) {
    return 'Эпоха $n';
  }

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
  String get onboardingInterests => 'Интересы';

  @override
  String get onboardingHours => 'Сколько часов в неделю?';

  @override
  String get onboardingContinue => 'Далее';

  @override
  String get onboardingFinish => 'Начать';

  @override
  String get pomodoroTitle => 'Помодоро';

  @override
  String get pomodoroStart => 'Начать фокус';

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
  String get settingsImport => 'Импорт из буфера';

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
  String get reflectionNormal => 'Норм';

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

  @override
  String editorSaveError(String error) {
    return 'Не удалось сохранить запись: $error';
  }

  @override
  String editorDeletedMsg(String title) {
    return '«$title» удалена';
  }

  @override
  String get editorHintTask => 'Что нужно сделать?';

  @override
  String get editorNewEntry => 'Новая запись';

  @override
  String get editorEntry => 'Запись';

  @override
  String get editorExpand => 'Развернуть';

  @override
  String get editorClose => 'Закрыть';

  @override
  String get editorParams => 'Параметры';

  @override
  String get editorMakeTask => 'Сделать задачей';

  @override
  String get editorTaskModeHint => 'Дедлайн и XP при выполнении';

  @override
  String get editorNoteModeHint => 'По умолчанию — заметка';

  @override
  String get editorNoDeadline => 'Без дедлайна';

  @override
  String get editorXpOnComplete => 'XP при выполнении';

  @override
  String get editorAddAxesHint => 'Сначала добавь оси в онбординге.';

  @override
  String get editorUntitled => '(без названия)';

  @override
  String editorBacklinksCount(int count) {
    return 'Сюда ссылаются ($count)';
  }

  @override
  String editorSubtasksProgress(int done, int total) {
    return 'Подзадачи — $done/$total';
  }

  @override
  String get editorBodyHint => 'Что у тебя на уме?\nФорматирование: жирный, курсив, заголовки, чек-листы, [[ссылки на заметки]].';

  @override
  String get editorToolH1 => 'Заголовок 1';

  @override
  String get editorToolH2 => 'Заголовок 2';

  @override
  String get editorToolH3 => 'Заголовок 3';

  @override
  String get editorToolBold => 'Жирный';

  @override
  String get editorToolItalic => 'Курсив';

  @override
  String get editorToolStrike => 'Зачёркнутый';

  @override
  String get editorToolCode => 'Код';

  @override
  String get editorToolBullet => 'Маркированный список';

  @override
  String get editorToolNumber => 'Нумерованный список';

  @override
  String get editorToolCheckbox => 'Чек-лист';

  @override
  String get editorToolQuote => 'Цитата';

  @override
  String get editorToolLink => 'Ссылка';

  @override
  String get editorToolWikiLink => 'Ссылка на заметку';

  @override
  String get editorToolTag => 'Тег';

  @override
  String get editorWikiLinkTitle => 'Ссылка на заметку';

  @override
  String get editorWikiLinkHint => 'Начни печатать название…';

  @override
  String editorCreateNote(String title) {
    return 'Создать «$title»';
  }

  @override
  String get calendarNoTasks => 'Задач нет';

  @override
  String get calendarPlanTask => 'Запланировать задачу';

  @override
  String get calendarDeadlines => 'Дедлайны';

  @override
  String get notesSearch => 'Поиск заметок…';

  @override
  String get notesEmpty => 'Заметок пока нет';

  @override
  String get notesNew => 'Новая заметка';

  @override
  String get calendarNotes => 'Заметки';

  @override
  String dashboardOverdue(String date) {
    return 'просрочена · $date';
  }

  @override
  String dashboardDueBy(String date) {
    return 'до $date';
  }

  @override
  String get dashboardPostpone15m => '+15 мин';

  @override
  String get dashboardPostpone1h => '+1 час';

  @override
  String get dashboardPostpone1d => '+1 день';

  @override
  String get dashboardPostpone3d => '+3 дня';

  @override
  String dashboardTomorrow(String time) {
    return 'завтра $time';
  }

  @override
  String dashboardYesterday(String time) {
    return 'вчера $time';
  }

  @override
  String get dashboardReflectPrompt => 'Заглянем коротко на пройденное?';

  @override
  String get dashboardGreetingAnon => 'Привет';

  @override
  String dashboardGreeting(String name) {
    return 'Привет, $name';
  }

  @override
  String get dashboardOnboardingHint => 'С чего начнём? Выбери действие ниже — это разово, потом дашборд оживёт твоими записями.';

  @override
  String get dashboardRoadmapNoGoal => 'AI разложит твою цель на 4–10 конкретных задач, привязанных к осям пентаграммы.';

  @override
  String dashboardRoadmapWithGoal(String goal) {
    return 'AI разложит «$goal» на 4–10 задач. Поле уже заполнено — можно редактировать.';
  }

  @override
  String get dashboardGraphHint => 'Граф второго мозга: цели, ограничения, рефлексии и заметки. Тапни ветку — отредактируй.';

  @override
  String get dashboardNoteHint => 'Лёгкий старт: пара мыслей, наблюдение или идея. Заметку можно потом превратить в задачу.';

  @override
  String get dashboardRoadmapTitle => 'Сгенерируй план задач';

  @override
  String get dashboardGenerate => 'Сгенерировать';

  @override
  String get dashboardGraphTitle => 'Заглянь в базу знаний';

  @override
  String get dashboardOpenGraph => 'Открыть граф';

  @override
  String get dashboardNoteTitle => 'Запиши первую заметку';

  @override
  String get dashboardCreate => 'Создать';

  @override
  String get dashboardWeekPassed => 'Прошла неделя';

  @override
  String get pomodoroFocusDone => 'Фокус завершён';

  @override
  String get pomodoroBreakDone => 'Отдых завершён';

  @override
  String pomodoroLongBreakBody(int min) {
    return 'Время длинного отдыха $min мин — нажми «Поехали», когда готов.';
  }

  @override
  String pomodoroShortBreakBody(int min) {
    return 'Короткий отдых $min мин — нажми «Поехали», когда готов.';
  }

  @override
  String pomodoroNextFocusBody(int min) {
    return 'Следующий фокус $min мин — нажми «Поехали», когда готов.';
  }

  @override
  String selfEpochNoData(int n) {
    return 'Эпоха $n · нет данных';
  }

  @override
  String selfToNextLevel(int level, int xp) {
    return 'до L$level: $xp xp';
  }

  @override
  String get selfTreeHint => 'Древо вырастает от 3 ветвей. Добавь хотя бы 3 ветви, чтобы увидеть древо.';

  @override
  String axesSaveError(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get axesAiDrawing => 'AI рисует новые ветви…';

  @override
  String axesRegenError(String error) {
    return 'Не удалось перегенерировать: $error';
  }

  @override
  String get axesProfileUpdated => 'Профиль обновлён. Хочешь сразу перегенерировать ветви?';

  @override
  String get axesAiRedrawHint => 'AI перерисует набор с новыми вводными';

  @override
  String axesDragHint(int min, int max) {
    return 'Перетаскивай, переименовывай, добавляй или удаляй (от $min до $max). Чтобы AI перерисовал ветви с нуля — Меню → «Перегенерировать».';
  }

  @override
  String axesMaxBranches(int max) {
    return 'Максимум $max ветвей';
  }

  @override
  String get axesRemoveTooltip => 'Удалить';

  @override
  String get axesMinBranches => 'Минимум 3 ветви';

  @override
  String get axesNameHint => 'Например: Тело';

  @override
  String get axesAiNewSet => 'AI составит новый набор. Опиши, что хочешь изменить';

  @override
  String get axesAiExample => 'например: больше про здоровье и творчество';

  @override
  String get axisXpTotal => 'XP ВСЕГО';

  @override
  String axisToEpoch(int n) {
    return 'ДО Э$n';
  }

  @override
  String axisLevelHint(int level, int epoch) {
    return 'Уровень L$level — от всех закрытых задач. Эпоха Э$epoch — от XP именно этой оси, растёт и после того как древо заполнено на 100 %.';
  }

  @override
  String pomodoroCompleted(int n) {
    return '✦ $n';
  }

  @override
  String get pomodoroLongBreakEvery => 'Длинный отдых каждые N фокусов';

  @override
  String get knowledgeContextHint => 'Кратко: кто ты, чем занят, что важно';

  @override
  String get knowledgePrefHint => 'ключ: значение';

  @override
  String get navBranches => 'Ветви';

  @override
  String get settingsMore => 'Ещё';

  @override
  String get settingsOnboardAgain => 'Пройти онбординг заново';

  @override
  String get settingsOnboardAgainHint => 'Обновить интересы, боли, цели и пересобрать ветви';

  @override
  String get settingsAddBranch => 'Добавить ветвь';

  @override
  String get editorSymbol => 'Символ';

  @override
  String get roadmapMinAxes => 'Нужно минимум 3 оси, чтобы построить план.';

  @override
  String roadmapImported(int n) {
    return 'Импортировано задач: $n';
  }

  @override
  String roadmapImportError(String error) {
    return 'Не удалось импортировать: $error';
  }

  @override
  String get roadmapGoalHint => 'Чем конкретнее — тем точнее план. Например: «Хочу пробежать полумарафон через 3 месяца, текущая форма средняя».';

  @override
  String get roadmapInputHint => 'Чего хочешь достичь?';

  @override
  String get roadmapNeedAxes => 'Нужно хотя бы 3 оси. Добавь их на вкладке «Я».';

  @override
  String get roadmapGenerating => 'Генерируем план…';

  @override
  String roadmapImportBtn(int n) {
    return 'Импортировать ($n)';
  }

  @override
  String get pomodoroRunning => 'Pomodoro запущен';

  @override
  String pomodoroFocusStarted(int min, String title) {
    return 'Фокус $min мин: $title';
  }

  @override
  String axisXpForAxis(int xp) {
    return '+$xp XP';
  }

  @override
  String get dashboardXpToday => 'XP СЕГОДНЯ';

  @override
  String dashboardXpWeek(int xp) {
    return '$xp за неделю';
  }

  @override
  String dashboardBestAxis(String name, int xp) {
    return '$name · +$xp XP';
  }

  @override
  String get dashboardDescribeGoal => 'Опиши цель';

  @override
  String dashboardOverdueCount(int n) {
    return '$n просрочено';
  }

  @override
  String dashboardTodayCount(int n) {
    return '$n на сегодня';
  }

  @override
  String get dashboardThinking => 'Думаю над планом…';

  @override
  String get aboutApp => 'О тебе';

  @override
  String get knowledgePrefs => 'Предпочтения';

  @override
  String get actionClear => 'Очистить';

  @override
  String get roadmapHorizon => 'Горизонт';

  @override
  String get roadmapWeek => 'Неделя';

  @override
  String get roadmapMonth => 'Месяц';

  @override
  String get roadmapQuarter => 'Квартал';

  @override
  String get roadmapTaskCount => 'Кол-во задач';

  @override
  String get pomodoroTooltip => 'Pomodoro';

  @override
  String get pulseStreak => 'СТРИК';

  @override
  String get pulseStartToday => 'начни сегодня';

  @override
  String get pulseQuiet => 'пока тихо';

  @override
  String get pulseBestAxis => 'ЛУЧШАЯ ОСЬ';

  @override
  String get pulseNoData => 'нет данных';

  @override
  String pulseDeadline(String date) {
    return 'до $date';
  }

  @override
  String get pulseNoDeadline => 'нет дедлайнов';

  @override
  String pulseDeadlineHours(int h) {
    return '$hч';
  }

  @override
  String pulseDeadlineDays(int d) {
    return '$dд';
  }

  @override
  String get onboardQ1 => 'Привет. Я твой ассистент роста. Как тебя зовут?';

  @override
  String onboardQ2(String name) {
    return 'Окей, $name. Чего ты хочешь достичь в ближайший год?';
  }

  @override
  String get onboardQ2NoName => 'Чего ты хочешь достичь в ближайший год?';

  @override
  String get onboardQ3 => 'В каких сферах ты уже что-то делаешь? Выбери 3–8.';

  @override
  String get onboardQ4 => 'Сколько часов в неделю реально готов уделять?';

  @override
  String get onboardHoursWeek => 'ч/нед';

  @override
  String onboardWeeklyTime(int h) {
    return 'В неделю на развитие: ~$h ч';
  }

  @override
  String onboardSaveError(String error) {
    return 'Не удалось сохранить профиль: $error';
  }

  @override
  String get onboardSelectOne => 'Выбери хотя бы одну';

  @override
  String onboardSelectMore(int n) {
    return 'Выбери ещё $n';
  }

  @override
  String get onboardCustomOpen => '× своё';

  @override
  String get onboardCustomClosed => '+ своё';

  @override
  String onboardHoursLabel(int h) {
    return '$h ч';
  }

  @override
  String get onboardLevelNovice => 'новичок';

  @override
  String get onboardLevelLearning => 'учусь';

  @override
  String get onboardLevelConfident => 'уверенно';

  @override
  String get onboardLevelExpert => 'эксперт';

  @override
  String onboardProfileName(String name) {
    return 'Зовут $name.';
  }

  @override
  String onboardProfileGoal(String goal) {
    return 'Цель: $goal.';
  }

  @override
  String onboardProfileNow(String text) {
    return 'Сейчас: $text.';
  }

  @override
  String onboardProfileHours(int h) {
    return 'Готов уделять около $h ч/нед.';
  }

  @override
  String get actionNext => 'Далее';

  @override
  String get onboardPlanTitle => 'Сразу набросать план?';

  @override
  String onboardPlanBody(String goal) {
    return 'AI разложит «$goal» на 4–10 конкретных задач, привязанных к осям, которые ты только что собрала. Промпт уже заполнен — можно отредактировать, прежде чем запускать генерацию.';
  }

  @override
  String get actionLater => 'Позже';

  @override
  String get onboardFillAxes => 'Заполни хотя бы 3 оси, чтобы пентаграмма имела смысл';

  @override
  String get onboardTooManyAxes => 'Слишком много осей: оставь не больше 8, иначе будет хаос';

  @override
  String onboardSaveAxesError(String error) {
    return 'Не удалось сохранить оси: $error';
  }

  @override
  String get onboardRegenTitle => 'Перегенерация осей';

  @override
  String get onboardDescribeAxes => 'Опиши свои оси роста';

  @override
  String get onboardAiGenerating => 'AI придумывает оси…';

  @override
  String get onboardYourAxes => 'Твои личные оси';

  @override
  String get onboardAxesHint => 'От 3 до 8 направлений, по которым ты хочешь расти. К ним будут привязываться задачи и заметки. Их можно изменить позже.';

  @override
  String onboardAiError(String error) {
    return 'Не удалось связаться с AI: $error. Ниже — запасные оси, отредактируй как хочешь.';
  }

  @override
  String onboardAiDrawingAxes(int n) {
    return 'Из $n твоих направлений AI рисует персональную пентаграмму…';
  }

  @override
  String onboardAiGenerated(String model) {
    return 'Сгенерировано на $model. Переименуй, убери лишние, добавь свои. От 3 до 8.';
  }

  @override
  String get onboardRegenBtn => 'Перегенерировать оси';

  @override
  String get onboardWaitSeconds => 'Это занимает 5–25 секунд';

  @override
  String get onboardAddAxis => 'Добавить ось';

  @override
  String get onboardCreatePentagram => 'Создать пентаграмму';

  @override
  String onboardAxisHint(int n) {
    return 'Название оси (#$n)';
  }

  @override
  String get onboardAxesUpdated => 'Оси обновлены';

  @override
  String onboardAxesMigrated(int n) {
    return 'Оси обновлены, перенесено $n связей с задачами';
  }

  @override
  String get backendsTitle => 'Бэкенды';

  @override
  String get backendsAdd => 'Добавить';

  @override
  String backendsError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get backendsHint => 'Активный бэкенд используется для AI, синхронизации и входа. Можно держать несколько (например, прод и личный сервер) и переключаться без перезапуска.';

  @override
  String get backendsDeleteTitle => 'Удалить бэкенд?';

  @override
  String backendsSaveError(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get backendsPinging => 'Пингую…';

  @override
  String get backendsOnline => 'Бэкенд отвечает';

  @override
  String backendsOffline(String error) {
    return 'Не отвечает: $error';
  }

  @override
  String get backendsPing => 'Пинг';

  @override
  String get backendsMakeActive => 'Сделать активным';

  @override
  String get backendsEdit => 'Изменить';

  @override
  String get backendsLastOne => 'Должен остаться хотя бы один бэкенд';

  @override
  String get backendsNewTitle => 'Новый бэкенд';

  @override
  String get backendsEditTitle => 'Изменить бэкенд';

  @override
  String get backendsName => 'Имя';

  @override
  String get backendsNameHint => 'Прод · Локалка · Запасной';

  @override
  String get backendsUrlError => 'Введите валидный URL начинающийся с http(s)://';

  @override
  String get menuTitle => 'Меню недели';

  @override
  String get menuNewConfirmTitle => 'Создать новое меню?';

  @override
  String get menuNewConfirmBody => 'Текущие задачи и рецепты останутся в базе знаний — их можно найти по тегу menu/… или открыть по ссылке.\n\nФорма генерации откроется заново.';

  @override
  String get actionCreate => 'Создать';

  @override
  String get menuBreakfast => 'Завтрак';

  @override
  String get menuLunch => 'Обед';

  @override
  String get menuDinner => 'Ужин';

  @override
  String get menuSnack => 'Перекус';

  @override
  String menuRecipeStubTitle(String name) {
    return 'Рецепт: $name';
  }

  @override
  String get menuRecipeStubBody => '_Рецепт ещё не сгенерирован._\n\nОткрой меню недели → нажми «Получить рецепт» рядом с этим блюдом.';

  @override
  String menuShoppingTitle(String range) {
    return 'Список покупок · меню $range';
  }

  @override
  String get menuShoppingHeader => 'Список покупок на неделю';

  @override
  String menuGoalServings(String goal, int n) {
    return 'Цель: $goal · $n порций';
  }

  @override
  String menuImportError(String error) {
    return 'Не удалось импортировать меню: $error';
  }

  @override
  String get menuIngredients => 'ИНГРЕДИЕНТЫ';

  @override
  String menuFullRecipe(String link) {
    return 'Полный рецепт: [[$link]]';
  }

  @override
  String get menuGenerating => 'AI составляет меню…';

  @override
  String get menuImporting => 'Создаю задачи и список покупок…';

  @override
  String menuDateRange(String from, String to) {
    return '7 дней с $from по $to';
  }

  @override
  String get menuWhatCreated => 'Что я создам';

  @override
  String get menuBullet1 => '21 задача (завтрак / обед / ужин на 7 дней)';

  @override
  String get menuBullet2 => '1 заметка «Список покупок» с чек-листом';

  @override
  String get menuBullet3 => 'Рецепты подгрузятся по тапу и сохранятся в связанные заметки';

  @override
  String get menuRegenerate => 'Перегенерировать';

  @override
  String get menuImportBtn => 'Импортировать в задачи';

  @override
  String menuImportedCount(int n) {
    return 'Меню импортировано · $n задач';
  }

  @override
  String get menuNew => 'Новое меню';

  @override
  String menuImportedHint(String tag) {
    return 'Тег #$tag группирует все эти записи. Тапни блюдо — открой задачу. Нажми «Получить рецепт» на любом блюде — рецепт сохранится в связанной заметке.';
  }

  @override
  String menuServings(int n) {
    return '$n порций';
  }

  @override
  String menuDailyCalories(int n) {
    return '~$n ккал в день';
  }

  @override
  String get menuOpenRecipe => 'Открыть';

  @override
  String get menuGetRecipe => 'Получить рецепт';

  @override
  String get habitsTitle => 'Микро-привычки';

  @override
  String get habitsIntentError => 'Опиши, какую привычку хочешь освоить.';

  @override
  String habitsDayOf(int day, int total, String intent) {
    return 'День $day из $total · челлендж «$intent»';
  }

  @override
  String habitsImported(String intent, int n) {
    return 'Челлендж «$intent» добавлен — $n мини-задач в Задачах.';
  }

  @override
  String habitsImportError(String error) {
    return 'Не удалось импортировать челлендж: $error';
  }

  @override
  String get habitsGenerating => 'AI подбирает крошечные шаги…';

  @override
  String get habitsImporting => 'Создаю задачи в Noetica…';

  @override
  String habitsBullet1(int n) {
    return '$n задач — по одной на день, от лёгкой к закрепляющей';
  }

  @override
  String get habitsBullet2 => 'Каждое действие ≤ 2 минут реального усилия';

  @override
  String get habitsBullet3 => 'Появятся в Задачах в секциях «Сегодня» / «Завтра» / …';

  @override
  String habitsDaysMini(int n) {
    return '$n дней · по одной мини-задаче';
  }

  @override
  String habitsAddTasks(int n) {
    return 'Добавить $n задач';
  }

  @override
  String get coachMorningTitle => 'Утренний план';

  @override
  String get coachEveningTitle => 'Вечерний разбор';

  @override
  String get coachRefresh => 'Обновить';

  @override
  String get coachError => 'Не удалось получить совет';

  @override
  String get coachRetry => 'Повторить';

  @override
  String get coachFocus => 'Фокус дня';

  @override
  String get coachPlanToday => 'План на сегодня';

  @override
  String get coachMotivation => 'Мотивация';

  @override
  String get coachDayResults => 'Итоги дня';

  @override
  String get coachSummary => 'Резюме';

  @override
  String get coachWins => 'Что получилось';

  @override
  String get coachImprove => 'Что улучшить';

  @override
  String get coachTomorrow => 'На завтра';

  @override
  String get reflectionResult => 'Что получилось / результат';

  @override
  String get reflectionDifficulties => 'Что мешало / сложности';

  @override
  String get reflectionMinutes => 'Сколько потратил, мин';

  @override
  String get reflectionCanSkip => 'Можно пропустить';

  @override
  String get toolsTitle => 'Ассистент';

  @override
  String get toolsAvailable => 'Доступно';

  @override
  String get toolsSoon => 'Скоро';

  @override
  String get toolsDescriptionFull => 'AI собирает готовые планы и раскладывает их по твоим дням, осям и тегам. Меню на неделю, программа тренировок, учебный курс — всё попадает в Календарь и Задачи как обычные записи.';

  @override
  String toolsOpening(String title) {
    return 'Открываю «$title»…';
  }

  @override
  String toolsComingSoon(String title) {
    return 'Скоро: «$title»';
  }

  @override
  String authLoginError(String error) {
    return 'Не удалось войти: $error';
  }

  @override
  String get authWait => 'Подождите…';

  @override
  String get authLoginGoogle => 'Войти через Google';

  @override
  String get authSyncHint => 'Ваши данные синхронизируются между устройствами под одним Google-аккаунтом. Без входа приложение не работает.';

  @override
  String get dayCalendar => 'Календарь';

  @override
  String get dayPlanTask => 'Запланировать задачу';

  @override
  String get dayEmpty => 'В этот день ничего не закрыто и не запланировано.';

  @override
  String get dayNoEntries => 'Без записей.';

  @override
  String get dayToday => 'Сегодня';

  @override
  String get dayYesterday => 'Вчера';

  @override
  String get dayTomorrow => 'Завтра';

  @override
  String get dayMonths => 'янв,фев,мар,апр,мая,июн,июл,авг,сен,окт,ноя,дек';

  @override
  String get dayWeekdays => 'пн,вт,ср,чт,пт,сб,вс';

  @override
  String dayDone(int n) {
    return '✓ Выполнено ($n)';
  }

  @override
  String dayDeadlines(int n) {
    return '⏳ Дедлайны ($n)';
  }

  @override
  String daySummaryClosed(int n, int xp) {
    return '$n закрыто · +$xp XP';
  }

  @override
  String daySummaryDeadline(int n) {
    return '$n дедлайн';
  }

  @override
  String get untitled => '(без названия)';

  @override
  String get weeklyTitle => 'Недельный обзор';

  @override
  String get weeklyAxis => 'Ось';

  @override
  String get weeklyCompleted => 'Завершено';

  @override
  String get weeklyXP => 'Опыт';

  @override
  String get weeklyTasks => 'Задач';

  @override
  String get weeklyNotes => 'Заметок';

  @override
  String get weeklyStreak => 'Стрик';

  @override
  String get weeklyBestDay => 'Лучший день';

  @override
  String get weeklyWorstDay => 'Слабый день';

  @override
  String get weeklyHighlights => 'Главное за неделю';

  @override
  String get weeklyAdvice => 'Совет на следующую';

  @override
  String get weeklyNoData => 'Недостаточно данных';

  @override
  String get weeklyDays => 'пн,вт,ср,чт,пт,сб,вс';

  @override
  String get weeklyMonths => 'янв,фев,мар,апр,мая,июн,июл,авг,сен,окт,ноя,дек';

  @override
  String get weeklyDone => 'выполнено';

  @override
  String get weeklyCreated => 'создано';

  @override
  String get weeklyGenerating => 'AI анализирует неделю…';

  @override
  String get weeklyShare => 'Поделиться';

  @override
  String get weeklyClose => 'Закрыть';

  @override
  String get weeklyTotal => 'итого';

  @override
  String get weeklyReflTitle => 'Итог недели';

  @override
  String get weeklyReflSubtitle => 'Заглянем коротко: что было, что нет, и куда дальше.';

  @override
  String get weeklyWinsLabel => 'Что получилось';

  @override
  String get weeklyLossesLabel => 'Что не получилось';

  @override
  String get weeklyFocusLabel => 'Куда смотрю на следующую';

  @override
  String get weeklyMoodLabel => 'Самочувствие';

  @override
  String get weeklyLater => 'Позже';

  @override
  String get weeklySubmit => 'Записать';

  @override
  String get weeklyCustomHint => 'Своё (необязательно)';

  @override
  String weeklySaveError(String error) {
    return 'Не сохранилось: $error';
  }

  @override
  String weeklyMoodSummary(int n) {
    return 'самочувствие $n/5';
  }

  @override
  String get weeklyWin1 => 'выполнил план';

  @override
  String get weeklyWin2 => 'новые привычки';

  @override
  String get weeklyWin3 => 'продвинулся в проекте';

  @override
  String get weeklyWin4 => 'отдых был';

  @override
  String get weeklyWin5 => 'дисциплина держалась';

  @override
  String get weeklyWin6 => 'разобрался в новой теме';

  @override
  String get weeklyWin7 => 'хорошие отношения';

  @override
  String get weeklyLoss1 => 'прокрастинация';

  @override
  String get weeklyLoss2 => 'усталость';

  @override
  String get weeklyLoss3 => 'отвлечения';

  @override
  String get weeklyLoss4 => 'не уделил время важному';

  @override
  String get weeklyLoss5 => 'выгорание';

  @override
  String get weeklyLoss6 => 'болел';

  @override
  String get weeklyLoss7 => 'конфликты';

  @override
  String get weeklyFocus1 => 'добить незавершённое';

  @override
  String get weeklyFocus2 => 'новая привычка';

  @override
  String get weeklyFocus3 => 'фокус на главном';

  @override
  String get weeklyFocus4 => 'отдых';

  @override
  String get weeklyFocus5 => 'учёба';

  @override
  String get weeklyFocus6 => 'спорт';

  @override
  String get weeklyFocus7 => 'отношения';

  @override
  String epochPeak(int n) {
    return 'ЭПОХА $n · ПИК';
  }

  @override
  String get epochPostpone => 'Отложить';

  @override
  String get epochTreeFull => 'Ты заполнил древо.';

  @override
  String epochTwoPaths(int n) {
    return 'Два пути дальше — можешь обновить сам набор осей и начать Эпоху $n с чистого листа, либо остаться в текущем фокусе и взять следующий, более трудный тир задач.';
  }

  @override
  String get epochNewEpoch => 'Новая эпоха';

  @override
  String epochNewEpochSub(int n) {
    return 'Перерисовать ветви — Эпоха $n. XP и уровень остаются.';
  }

  @override
  String get epochGoDeeper => 'Углубиться';

  @override
  String epochGoDeeperSub(int n) {
    return 'Тир $n в той же Эпохе — задачи станут сложнее, древо обнулится.';
  }

  @override
  String get graphBranchGoals => 'Цели';

  @override
  String get graphBranchConstraints => 'Ограничения';

  @override
  String get graphBranchHighlights => 'Достижения';

  @override
  String get graphBranchReflections => 'Рефлексии';

  @override
  String get graphBranchPreferences => 'Предпочтения';

  @override
  String get graphFilterAll => 'Все';

  @override
  String get graphFilterNotes => 'Заметки';

  @override
  String get graphFilterTasks => 'Задачи';

  @override
  String get graphFilterBookmarks => 'Закладки';

  @override
  String get graphFilterDaily => 'Дневник';

  @override
  String get graphFilterKnowledge => 'Знания о себе';

  @override
  String get pomodoroStop => 'Стоп';

  @override
  String get pomodoroSeries => 'Серия фокус-сессий';

  @override
  String get pomodoroSeriesReset => 'Серия фокус-сессий — нажми чтобы сбросить';

  @override
  String get pomodoroSettings => 'Настройки';

  @override
  String get pomodoroFocusMin => 'Фокус, мин';

  @override
  String get pomodoroShortBreak => 'Короткий отдых, мин';

  @override
  String get pomodoroLongBreak => 'Длинный отдых';

  @override
  String get pomodoroAutoStart => 'Авто-старт следующей фазы';

  @override
  String get pomodoroAutoStartSub => 'После окончания фокуса/отдыха таймер продолжается сам';

  @override
  String get pomodoroSoundVibro => 'Звук + вибрация';

  @override
  String get pomodoroSoundVibroSub => 'Системный «дзынь» и хаптик при смене фазы (уведомление приходит в любом случае)';

  @override
  String get graphCentreLabel => 'я';

  @override
  String get graphGoalsHint => 'Что хочешь достичь';

  @override
  String get graphConstraintsHint => 'Что мешает или ограничивает';

  @override
  String get graphHighlightsHint => 'Что уже получилось';

  @override
  String get graphReflectionsHint => 'Заметки о пройденном';

  @override
  String get graphDelete => 'Удалить';

  @override
  String get graphSearchHint => 'Поиск по базе знаний…';

  @override
  String get graphKnowledgeBase => 'База знаний';

  @override
  String get graphSearchTooltip => 'Поиск';

  @override
  String get graphDailyTooltip => 'Дневник';

  @override
  String get graphShowRecipes => 'Показывать рецепты';

  @override
  String get graphHideRecipes => 'Скрывать рецепты';

  @override
  String get graphGlobalTooltip => 'Глобальный граф';

  @override
  String get graphNewNote => 'Новая заметка';

  @override
  String get graphResetView => 'Сбросить вид';

  @override
  String get graphShuffle => 'Перемешать';

  @override
  String get graphEmptyTitle1 => 'Записывай';

  @override
  String get graphEmptyBody1 => 'Заметки, задачи, дневник — всё становится узлами графа.';

  @override
  String get graphEmptyTitle2 => 'Связывай';

  @override
  String get graphEmptyBody2 => 'Упоминай [[заголовок]] в тексте — Noetica построит ребро.';

  @override
  String get graphEmptyTitle3 => 'Изучай';

  @override
  String get graphEmptyBody3 => 'Граф покажет, какие темы пересекаются и где пусто.';

  @override
  String get graphEmptyTitle4 => 'О себе';

  @override
  String get graphEmptyBody4 => 'Цели, ограничения, достижения — эти ветки помогут AI.';

  @override
  String get graphEmptyTitle5 => 'Первая запись';

  @override
  String get graphEmptyBody5 => 'Нажми +, чтобы создать заметку и увидеть граф в действии.';

  @override
  String get graphEmptyTitle6 => 'Теги';

  @override
  String get graphEmptyBody6 => 'Добавляй теги к записям — они тоже станут узлами.';

  @override
  String get graphResetFilter => 'Сбросить фильтр';

  @override
  String get graphEmptyAllTitle => 'База знаний пока пуста';

  @override
  String get graphEmptyAllBody => 'Создайте первую заметку или задачу — они появятся здесь как узлы графа.';

  @override
  String get graphEmptyAllAction => 'Создать запись';

  @override
  String get graphEmptyNotesTitle => 'Заметок пока нет';

  @override
  String get graphEmptyNotesBody => 'Заметки будут видны как отдельные узлы. Связи появляются автоматически, когда в теле есть [[ссылка]] на другую заметку.';

  @override
  String get graphEmptyNotesAction => 'Создать заметку';

  @override
  String get graphEmptyTasksTitle => 'Задач в графе нет';

  @override
  String get graphEmptyTasksBody => 'Создайте задачу через «+» или сгенерируйте план задач из вашей цели.';

  @override
  String get graphEmptyBookmarksTitle => 'Закладок пока нет';

  @override
  String get graphEmptyBookmarksBody => 'Долгое нажатие на узел графа добавит его в закладки.';

  @override
  String get graphEmptyDailyTitle => 'Дневник пуст';

  @override
  String get graphEmptyDailyBody => 'Тапните иконку календаря в шапке, чтобы создать запись на сегодня.';

  @override
  String get graphEmptyKnowledgeTitle => 'Знания о себе пусты';

  @override
  String get graphEmptyKnowledgeBody => 'Заполните цели, ограничения и достижения через тапы по веткам графа — это даст AI больше контекста для генерации планов.';

  @override
  String get editListAdd => 'Добавить';

  @override
  String get editListRemove => 'Удалить';

  @override
  String get editListSave => 'Сохранить';

  @override
  String get graphConnections => 'связей';

  @override
  String get selfBranchesTooltip => 'Ветви';

  @override
  String get selfSettingsTooltip => 'Настройки';

  @override
  String get selfTreeBranches => 'ДРЕВО · ВЕТКИ';

  @override
  String get selfGeneratePlan => 'Сгенерировать план';

  @override
  String get selfScoreExplain => 'Очки начисляются за выполнение задач, привязанных к осям. Со временем затухают — пентаграмма отражает тебя за последний месяц.';

  @override
  String selfEpochArchive(int n) {
    return 'ЭПОХА $n · АРХИВ';
  }

  @override
  String get selfArchiveReadonly => 'Древо этой эпохи на момент перехода. Только просмотр.';

  @override
  String get selfArchiveEmpty => 'Архив этой эпохи пустой — она завершилась до того, как мы начали записывать историю. Будущие переходы сохранятся целиком.';

  @override
  String get selfArchiveBranches => 'ВЕТВИ ТОЙ ЭПОХИ';

  @override
  String get selfEpochLabel => 'ЭПОХА';

  @override
  String selfEpochShort(String epoch) {
    return 'Э$epoch';
  }

  @override
  String selfEpochTierShort(String epoch, String tier) {
    return 'Э$epoch.$tier';
  }

  @override
  String get selfLevelLabel => 'УРОВЕНЬ';

  @override
  String get selfStreakLabel => 'СТРИК';

  @override
  String selfStreakDays(int n) {
    return '$n д.';
  }

  @override
  String get selfReadyTransition => 'Готов к переходу — тапни, чтобы открыть';

  @override
  String get selfStreakBroken => 'Стрик прервался. Закрой одну задачу сегодня — начнём заново.';

  @override
  String axisEpochPrefix(String n) {
    return 'Э$n';
  }

  @override
  String get axisState => 'СОСТОЯНИЕ';

  @override
  String get axisCompletedByAxis => 'ВЫПОЛНЕНО ПО ОСИ';

  @override
  String get axisNoTasks => 'Здесь появятся выполненные задачи, привязанные к этой оси.';

  @override
  String get axesOnboardingFirst => 'Сначала пройди онбординг.';

  @override
  String get axesYes => 'Да';

  @override
  String get axesAxis => 'Ось';

  @override
  String get axesDone => 'Готово';

  @override
  String get dashNoActiveTasks => 'Активных задач нет — отдохни или создай новую.';

  @override
  String get dashDone => 'Готово';

  @override
  String get dashPostpone => 'Отложить';

  @override
  String get dashFocusTimer => 'Запустить таймер фокуса';

  @override
  String get dashPostponeBy => 'ОТЛОЖИТЬ НА';

  @override
  String get dashViewPentagram => 'Посмотреть свою пентаграмму';

  @override
  String get heatmapWeekdays => 'Пн,,Ср,,Пт,,';

  @override
  String get heatmapMonths => 'янв,фев,мар,апр,май,июн,июл,авг,сен,окт,ноя,дек';

  @override
  String heatmapEmptyYear(int year) {
    return 'в $year году пока пусто';
  }

  @override
  String heatmapYearSummary(String total, int year) {
    return '$total закрыто в $year — тапни день';
  }

  @override
  String get heatmapLess => 'меньше';

  @override
  String get heatmapMore => 'больше';

  @override
  String get miniTreeEmpty => 'Древо появится после первой ветви';

  @override
  String miniTreeXp(int xp) {
    return 'всего $xp XP · тап — древо целиком';
  }

  @override
  String pulseStreakDay(int n) {
    return '$n день';
  }

  @override
  String pulseStreakDays(int n) {
    return '$n дня';
  }

  @override
  String pulseStreakDaysMany(int n) {
    return '$n дней';
  }

  @override
  String get notesQuickHint => 'Быстрая заметка…';

  @override
  String get notesSearchHint => 'Поиск';

  @override
  String get notesNotFound => 'Ничего не найдено';

  @override
  String get notesEmptyHint => 'Запиши мысль одной строкой выше или открой полный редактор кнопкой «+».';

  @override
  String get notesNotFoundHint => 'Попробуй другой запрос.';

  @override
  String get calMonths => 'Январь,Февраль,Март,Апрель,Май,Июнь,Июль,Август,Сентябрь,Октябрь,Ноябрь,Декабрь';

  @override
  String get calWeekdays => 'Пн,Вт,Ср,Чт,Пт,Сб,Вс';

  @override
  String get calToday => 'Сегодня';

  @override
  String get calPlanDay => 'Запланировать на этот день';

  @override
  String get calNothingRecorded => 'Ничего не записано.';

  @override
  String get calMonthsShort => 'янв,фев,мар,мая,июн,июл,авг,сен,окт,ноя,дек';

  @override
  String get calDaysShort => 'пн,вт,ср,чт,пт,сб,вс';

  @override
  String get calTodayPrefix => 'Сегодня';

  @override
  String get calYesterday => 'Вчера';

  @override
  String get calTomorrow => 'Завтра';

  @override
  String get calDayEmpty => 'В этот день ничего не записано.';

  @override
  String get taskOverdue => 'Просрочено';

  @override
  String get taskNoTasks => 'Задач нет — все выполнены или не созданы.';

  @override
  String get settingsSync => 'Синхронизация';

  @override
  String get settingsSyncSub => 'Google Drive для бэкапа';

  @override
  String get settingsExportSub => 'JSON в буфер обмена';

  @override
  String get settingsImportSub => 'Вставить JSON';

  @override
  String get settingsAboutSub => 'Версия, лицензии';

  @override
  String get roadmapTitle => 'AI-План';

  @override
  String get roadmapGenerateFirst => 'Сгенерируй первый план';

  @override
  String get roadmapAxis => 'Ось';

  @override
  String get roadmapGoal => 'Цель';

  @override
  String get roadmapGenerate => 'Сгенерировать';

  @override
  String get roadmapWeek1 => 'Неделя 1';

  @override
  String get roadmapWeek2 => 'Неделя 2';

  @override
  String get roadmapWeek3 => 'Неделя 3';

  @override
  String get roadmapWeek4 => 'Неделя 4';

  @override
  String get roadmapError => 'Ошибка';

  @override
  String get homeMore => 'Ещё';

  @override
  String get onboardingActiveHours => 'Активные часы';

  @override
  String get menuRecipeSteps => 'ШАГИ РЕЦЕПТА';

  @override
  String get menuGenerateRecipe => 'Сгенерировать рецепт';

  @override
  String get entryUntitled => 'Без названия';

  @override
  String get axisTileFocusTasks => 'фокусных задач';

  @override
  String get backendsNoKey => 'ключ не задан';

  @override
  String get editListAddItem => 'Добавить';

  @override
  String get editListHint => 'Новый пункт';

  @override
  String get editListAddFirst => 'Добавить первую запись';

  @override
  String get entryTaskDone => '✓ задача';

  @override
  String get entryTask => 'задача';

  @override
  String get backendsActive => 'Активный';

  @override
  String get debugFillAxes => 'Заполнить все оси до 100%';

  @override
  String get debugFillAxesSub => 'Создаёт синтетические задачи, чтобы пентагон встал на пик';

  @override
  String get debugFillAxesDone => 'Готово. Открой «Я» — оверлей должен появиться.';

  @override
  String get debugResetAck => 'Сбросить ack эпохи';

  @override
  String get debugResetAckSub => 'Обнуляет epochAckedAt — оверлей снова пустит при пике';

  @override
  String get debugResetAckDone => 'Ack сброшен.';

  @override
  String get debugBumpEpoch => 'Форсировать +1 эпоху';

  @override
  String get debugBumpEpochDone => 'Эпоха увеличена.';

  @override
  String get debugResetEpoch => 'Сбросить эпоху на 1';

  @override
  String get debugResetEpochSub => 'Полный откат прогрессии до Эпохи 1';

  @override
  String get debugResetEpochDone => 'Сброс до Эпохи 1.';

  @override
  String get roadmapRegenerate => 'Перегенерировать';

  @override
  String get roadmapFailed => 'Не получилось';

  @override
  String get roadmapGenericError => 'Что-то пошло не так';

  @override
  String get roadmapBack => 'Назад';

  @override
  String get roadmapToday => 'сегодня';

  @override
  String get roadmapTomorrow => 'завтра';

  @override
  String roadmapInDays(int n) {
    return 'через $n дн.';
  }

  @override
  String roadmapDueDate(String date) {
    return 'до $date';
  }

  @override
  String get roadmapFromOnboarding => 'Из онбординга';

  @override
  String get pomodoroStopAction => 'Стоп';

  @override
  String get pomodoroGoAction => 'Поехали';

  @override
  String get onboardGoals => 'поправить здоровье,сменить профессию,выучить новое,стать дисциплинированнее,развить отношения,найти баланс,запустить проект';

  @override
  String get onboardInterests => 'учёба,код,дизайн,спорт,медитация,чтение,музыка,языки,кулинария,отношения,финансы,творчество,карьера,семья';

  @override
  String get onboardTimePrefix => 'Время';

  @override
  String get onboardPainPrefix => 'Что мешает';

  @override
  String get onboardComfortTime => 'Удобное время';

  @override
  String get onboardNameHint => 'Имя';

  @override
  String get onboardCustomValue => 'Своё значение';

  @override
  String get onboardVolumeMini => 'мини-объём, по чуть-чуть';

  @override
  String get onboardVolumeComfort => 'комфортный темп';

  @override
  String get onboardVolumeSerious => 'серьёзная вовлечённость';

  @override
  String get onboardVolumeAlmost => 'почти второй джоб';

  @override
  String get onboardVolumeMax => 'максимальный режим';

  @override
  String onboardPainSummary(String pain) {
    return 'Что мешает: $pain.';
  }

  @override
  String onboardTimeSummary(String time) {
    return 'Удобное время: $time.';
  }

  @override
  String get pulseDeadlineLabel => 'Дедлайн';

  @override
  String get pluralTaskOne => 'задача';

  @override
  String get pluralTaskFew => 'задачи';

  @override
  String get pluralTaskMany => 'задач';

  @override
  String get pluralDeadlineOne => 'дедлайн';

  @override
  String get pluralDeadlineFew => 'дедлайна';

  @override
  String get pluralDeadlineMany => 'дедлайнов';

  @override
  String get pluralNoteOne => 'заметка';

  @override
  String get pluralNoteFew => 'заметки';

  @override
  String get pluralNoteMany => 'заметок';

  @override
  String get pluralBranchOne => 'ветвь';

  @override
  String get pluralBranchFew => 'ветви';

  @override
  String get pluralBranchMany => 'ветвей';

  @override
  String get heatmapNothing => 'ничего';

  @override
  String miniTreeBest(String symbol, String name, int level) {
    return 'лучшая: $symbol $name · L$level';
  }

  @override
  String get timeJustNow => 'только что';

  @override
  String get timeNow => 'сейчас';

  @override
  String timeAgoFmt(int value, String unit) {
    return '$value $unit назад';
  }

  @override
  String timeInFmt(int value, String unit) {
    return 'через $value $unit';
  }

  @override
  String get timeRightAfter => 'сразу после';

  @override
  String timePlusFmt(int value, String unit) {
    return '+ $value $unit';
  }

  @override
  String get pluralDayOne => 'день';

  @override
  String get pluralDayFew => 'дня';

  @override
  String get pluralDayMany => 'дней';

  @override
  String get pluralHourOne => 'час';

  @override
  String get pluralHourFew => 'часа';

  @override
  String get pluralHourMany => 'часов';

  @override
  String get pluralMinuteOne => 'минута';

  @override
  String get pluralMinuteFew => 'минуты';

  @override
  String get pluralMinuteMany => 'минут';

  @override
  String get pluralMonthOne => 'месяц';

  @override
  String get pluralMonthFew => 'месяца';

  @override
  String get pluralMonthMany => 'месяцев';

  @override
  String get pluralYearOne => 'год';

  @override
  String get pluralYearFew => 'года';

  @override
  String get pluralYearMany => 'лет';

  @override
  String get pomodoroFocus => 'Фокус';

  @override
  String get pomodoroBreak => 'Короткий отдых';

  @override
  String pomodoroLongBreakHint(int min) {
    return 'Длинный отдых $min мин';
  }

  @override
  String pomodoroShortBreakHint(int min) {
    return 'Короткий отдых $min мин';
  }

  @override
  String pomodoroNextFocusAuto(int min) {
    return 'Поехали — следующий фокус $min мин';
  }

  @override
  String get pomodoroNextFocusManual => 'Запусти следующий фокус когда готов';

  @override
  String get pomodoroTimeToRest => 'Время передохнуть';

  @override
  String get pomodoroBackToFocus => 'Возвращаемся к фокусу';

  @override
  String get pomodoroReadyAgain => 'Готов снова работать?';

  @override
  String get notifChannelName => 'Дедлайны и напоминания';

  @override
  String get notifChannelDesc => 'Напоминания о приближающихся и просроченных задачах.';

  @override
  String get notifWindowsHint => 'Тосты Windows + иконка в трее. Чтобы напоминания приходили, не закрывай приложение полностью — сворачивай в трей (крестик это и делает).';

  @override
  String get notifUnsupported => 'Эта платформа не поддерживается.';

  @override
  String get notifMorningTitle => 'Утренний план';

  @override
  String get notifMorningBody => 'Загляни в AI-коуч — спланируй свой день';

  @override
  String get notifEveningTitle => 'Вечерний разбор';

  @override
  String get notifEveningBody => 'Подведём итоги дня — что получилось, что улучшить?';

  @override
  String get notifDeadlineTomorrow => 'Завтра дедлайн';

  @override
  String get notifDeadlineToday => 'Сегодня дедлайн';

  @override
  String get notifDeadlinePassed => 'Дедлайн прошёл';

  @override
  String get notifWeeklyTitle => 'Время недельной рефлексии';

  @override
  String get notifWeeklyBody => 'Заглянем как прошла неделя?';

  @override
  String get trayOpen => 'Открыть Noetica';

  @override
  String get trayExit => 'Выйти';

  @override
  String get genMenuGoal => 'Цель питания';

  @override
  String get genMenuClassic => 'Сбалансированно';

  @override
  String get genMenuLoseWeight => 'Похудение';

  @override
  String get genMenuHealth => 'Здоровье';

  @override
  String get genMenuMuscle => 'Набор мышц';

  @override
  String get genMenuEnergy => 'Энергия / спорт';

  @override
  String get genMenuServings => 'Порций';

  @override
  String get genMenuStart => 'Старт меню';

  @override
  String get genMenuAxis => 'Ось роста';

  @override
  String get genMenuAxisHelp => '21 задача добавится к выбранной оси и будет давать XP при отметке «выполнено».';

  @override
  String get genMenuRestrictions => 'Ограничения (опционально)';

  @override
  String get genMenuRestrictionsHint => 'без глютена; без свинины; вегетарианец';

  @override
  String get genMenuNotes => 'Доп. пожелания (опционально)';

  @override
  String get genMenuNotesHint => 'минимум готовки в будни; больше рыбы; быстрые завтраки';

  @override
  String get genHabitIntent => 'Какую привычку хочешь освоить?';

  @override
  String get genHabitIntentHint => 'хочу засыпать раньше · перестать залипать в телефон утром · пить больше воды';

  @override
  String get genHabitDays => 'Сколько дней';

  @override
  String get genHabitAxis => 'Ось роста';

  @override
  String get genHabitAxisHelp => 'Все мини-задачи получат XP от выполнения и будут расти вместе с этой осью.';

  @override
  String get genHabitNotes => 'Доп. пожелания (опционально)';

  @override
  String get genHabitNotesHint => 'буду делать утром · уже пробовал, не получалось · хочу без приложений';

  @override
  String get genMenuTitle => 'Меню недели';

  @override
  String get genMenuDesc => '7 дней × завтрак / обед / ужин с КБЖУ под твою цель питания.';

  @override
  String get genMenuBullet1 => '21 задача на оси «Тело» с дедлайнами';

  @override
  String get genMenuBullet2 => 'Список покупок отдельной заметкой-чеклистом';

  @override
  String get genMenuBullet3 => 'Полные рецепты подгружаются по тапу';

  @override
  String get genTrainingTitle => 'План тренировок';

  @override
  String get genTrainingDesc => 'Программа на 4 недели под цель: сила, выносливость, рекомпозиция.';

  @override
  String get genTrainingBullet1 => 'Учитывает доступное оборудование';

  @override
  String get genTrainingBullet2 => 'Каждое занятие — задача с подходами в подзадачах';

  @override
  String get genStudyTitle => 'Учебный план';

  @override
  String get genStudyDesc => 'Декомпозиция «выучить X» на занятия с заметками-конспектами.';

  @override
  String get genStudyBullet1 => 'Уроки = задачи на оси «Разум»';

  @override
  String get genStudyBullet2 => 'Конспекты — заметки, связанные [[wiki-ссылками]]';

  @override
  String get genHabitsTitle => 'Микро-привычки';

  @override
  String get genHabitsDesc => '7-дневный челлендж из коротких ежедневных задач.';

  @override
  String get genHabitsBullet1 => 'Каждое действие ≤ 2 минут — реально доходишь';

  @override
  String get genHabitsBullet2 => 'Подбираем под выбранную ось, идут по нарастающей';

  @override
  String get genHabitsBullet3 => 'Появятся в Задачах с дедлайнами по дням';

  @override
  String get reflectionBlocked => 'Не пошло';

  @override
  String get menuGoalLoseWeight => 'Похудение';

  @override
  String get menuGoalHealth => 'Здоровье';

  @override
  String get menuGoalMuscle => 'Набор мышц';

  @override
  String get menuGoalEnergy => 'Энергия / спорт';

  @override
  String get menuGoalClassic => 'Классическое сбалансированное';

  @override
  String get apiErrNotLoggedIn => 'Не выполнен вход в Google. Перезайдите и попробуйте снова.';

  @override
  String apiErrServerUnreachable(String details) {
    return 'Не удалось связаться с сервером: $details';
  }

  @override
  String get apiErrSessionExpired => 'Сессия истекла. Зайдите через Google ещё раз.';

  @override
  String apiErrInvalidJson(String details) {
    return 'Сервер вернул некорректный JSON: $details';
  }

  @override
  String get validationRequired => 'Поле обязательно';

  @override
  String validationRange(int min, int max) {
    return 'Должно быть от $min до $max';
  }

  @override
  String get backendDefault => 'По умолчанию';

  @override
  String get backendCantDeleteLast => 'Нельзя удалить единственный бэкенд. Сначала добавь другой.';

  @override
  String menuRecipePrefix(String name) {
    return 'Рецепт: $name';
  }

  @override
  String get menuRecipeNotGenerated => 'Рецепт ещё не сгенерирован';

  @override
  String menuSummary(String goal, int servings, String range) {
    return '$goal · $servings порций · $range';
  }

  @override
  String get androidChannelName => 'Дедлайны и напоминания';

  @override
  String get androidChannelDesc => 'Напоминания о приближающихся и просроченных задачах.';

  @override
  String get interestSport => 'Спорт';

  @override
  String get interestReading => 'Чтение';

  @override
  String get interestLanguages => 'Изучение языков';

  @override
  String get interestProgramming => 'Программирование';

  @override
  String get interestMusic => 'Музыка';

  @override
  String get interestDrawing => 'Рисование';

  @override
  String get interestMeditation => 'Медитация';

  @override
  String get interestFriendship => 'Дружба';

  @override
  String get interestFamily => 'Семья';

  @override
  String get interestFinance => 'Финансы';

  @override
  String get interestCareer => 'Карьера';

  @override
  String get interestBusiness => 'Предпринимательство';

  @override
  String get interestNutrition => 'Питание';

  @override
  String get interestSleep => 'Сон';

  @override
  String get interestTravel => 'Путешествия';

  @override
  String get interestWriting => 'Письмо';

  @override
  String get interestCrafts => 'Ремесла';

  @override
  String get skillNovice => 'Новичок';

  @override
  String get skillLearning => 'Учусь';

  @override
  String get skillConfident => 'Уверенно';

  @override
  String get skillExpert => 'Эксперт';

  @override
  String get onboardAxisBody => 'Тело';

  @override
  String get onboardAxisMind => 'Ум';

  @override
  String get onboardAxisWork => 'Дело';

  @override
  String get onboardAxisRelations => 'Связи';

  @override
  String get onboardAxisSoul => 'Душа';

  @override
  String menuMacroLine(int cal, int p, int f, int c) {
    return '$cal ккал · $pб/$fж/$cу';
  }

  @override
  String get backendUrlEmpty => 'URL не должен быть пустым.';
}
