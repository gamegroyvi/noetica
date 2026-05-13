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
}
