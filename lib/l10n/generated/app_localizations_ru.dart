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
  String get roadmapGenerating => 'Это занимает 5–15 секунд';

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
  String get pulseDeadline => 'ДЕДЛАЙН';

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
  String onboardHoursWeek(int h) {
    return '$h ч/нед';
  }

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
}
