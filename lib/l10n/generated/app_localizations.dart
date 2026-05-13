import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'NOETICA'**
  String get appTitle;

  /// No description provided for @tabDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас'**
  String get tabDashboard;

  /// No description provided for @tabSelf.
  ///
  /// In ru, this message translates to:
  /// **'Я'**
  String get tabSelf;

  /// No description provided for @tabTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get tabTasks;

  /// No description provided for @tabMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get tabMore;

  /// No description provided for @navJournal.
  ///
  /// In ru, this message translates to:
  /// **'Журнал'**
  String get navJournal;

  /// No description provided for @navCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get navCalendar;

  /// No description provided for @navKnowledge.
  ///
  /// In ru, this message translates to:
  /// **'Граф'**
  String get navKnowledge;

  /// No description provided for @navAssistant.
  ///
  /// In ru, this message translates to:
  /// **'Ассистент'**
  String get navAssistant;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @navPomodoro.
  ///
  /// In ru, this message translates to:
  /// **'Помодоро'**
  String get navPomodoro;

  /// No description provided for @navRoadmap.
  ///
  /// In ru, this message translates to:
  /// **'AI-План'**
  String get navRoadmap;

  /// No description provided for @navCoach.
  ///
  /// In ru, this message translates to:
  /// **'AI Коуч'**
  String get navCoach;

  /// No description provided for @sectionNow.
  ///
  /// In ru, this message translates to:
  /// **'СЕЙЧАС'**
  String get sectionNow;

  /// No description provided for @sectionToday.
  ///
  /// In ru, this message translates to:
  /// **'СЕГОДНЯ'**
  String get sectionToday;

  /// No description provided for @sectionPulse.
  ///
  /// In ru, this message translates to:
  /// **'ПУЛЬС'**
  String get sectionPulse;

  /// No description provided for @sectionRecent.
  ///
  /// In ru, this message translates to:
  /// **'ПОСЛЕДНЕЕ'**
  String get sectionRecent;

  /// No description provided for @sectionOverdue.
  ///
  /// In ru, this message translates to:
  /// **'ПРОСРОЧЕНО'**
  String get sectionOverdue;

  /// No description provided for @sectionTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'ЗАВТРА'**
  String get sectionTomorrow;

  /// No description provided for @sectionThisWeek.
  ///
  /// In ru, this message translates to:
  /// **'НА ЭТОЙ НЕДЕЛЕ'**
  String get sectionThisWeek;

  /// No description provided for @sectionLater.
  ///
  /// In ru, this message translates to:
  /// **'ПОЗЖЕ'**
  String get sectionLater;

  /// No description provided for @sectionDone.
  ///
  /// In ru, this message translates to:
  /// **'ГОТОВО'**
  String get sectionDone;

  /// No description provided for @sectionHeatmap.
  ///
  /// In ru, this message translates to:
  /// **'АКТИВНОСТЬ'**
  String get sectionHeatmap;

  /// No description provided for @sectionTree.
  ///
  /// In ru, this message translates to:
  /// **'ДРЕВО'**
  String get sectionTree;

  /// No description provided for @sectionRecentlyClosed.
  ///
  /// In ru, this message translates to:
  /// **'НЕДАВНО ЗАКРЫТО'**
  String get sectionRecentlyClosed;

  /// No description provided for @linkCalendar.
  ///
  /// In ru, this message translates to:
  /// **'календарь →'**
  String get linkCalendar;

  /// No description provided for @linkAll.
  ///
  /// In ru, this message translates to:
  /// **'все →'**
  String get linkAll;

  /// No description provided for @linkTasks.
  ///
  /// In ru, this message translates to:
  /// **'задачи →'**
  String get linkTasks;

  /// No description provided for @freeDay.
  ///
  /// In ru, this message translates to:
  /// **'свободный день'**
  String get freeDay;

  /// No description provided for @filterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get filterAll;

  /// No description provided for @filterOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открытые'**
  String get filterOpen;

  /// No description provided for @filterOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просроч.'**
  String get filterOverdue;

  /// No description provided for @filterDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get filterDone;

  /// No description provided for @actionSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get actionDelete;

  /// No description provided for @actionUndo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get actionUndo;

  /// No description provided for @actionDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get actionDone;

  /// No description provided for @actionAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get actionAdd;

  /// No description provided for @actionEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get actionEdit;

  /// No description provided for @actionSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get actionSearch;

  /// No description provided for @actionExport.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт'**
  String get actionExport;

  /// No description provided for @actionImport.
  ///
  /// In ru, this message translates to:
  /// **'Импорт'**
  String get actionImport;

  /// No description provided for @taskNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая запись'**
  String get taskNew;

  /// No description provided for @taskComplete.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get taskComplete;

  /// No description provided for @taskSubtasks.
  ///
  /// In ru, this message translates to:
  /// **'Подзадачи'**
  String get taskSubtasks;

  /// No description provided for @taskDueDate.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайн'**
  String get taskDueDate;

  /// No description provided for @taskXp.
  ///
  /// In ru, this message translates to:
  /// **'XP'**
  String get taskXp;

  /// No description provided for @editorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок'**
  String get editorTitle;

  /// No description provided for @editorBody.
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get editorBody;

  /// No description provided for @editorTags.
  ///
  /// In ru, this message translates to:
  /// **'Теги'**
  String get editorTags;

  /// No description provided for @editorAddTag.
  ///
  /// In ru, this message translates to:
  /// **'добавить тег…'**
  String get editorAddTag;

  /// No description provided for @editorAxes.
  ///
  /// In ru, this message translates to:
  /// **'Оси'**
  String get editorAxes;

  /// No description provided for @editorBacklinks.
  ///
  /// In ru, this message translates to:
  /// **'Сюда ссылаются'**
  String get editorBacklinks;

  /// No description provided for @editorSubtasks.
  ///
  /// In ru, this message translates to:
  /// **'Подзадачи'**
  String get editorSubtasks;

  /// No description provided for @selfBranches.
  ///
  /// In ru, this message translates to:
  /// **'Ветви'**
  String get selfBranches;

  /// No description provided for @selfSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get selfSettings;

  /// No description provided for @selfEpoch.
  ///
  /// In ru, this message translates to:
  /// **'Эпоха'**
  String get selfEpoch;

  /// No description provided for @selfLevel.
  ///
  /// In ru, this message translates to:
  /// **'Уровень'**
  String get selfLevel;

  /// No description provided for @selfStreak.
  ///
  /// In ru, this message translates to:
  /// **'Стрик'**
  String get selfStreak;

  /// No description provided for @selfNewEpoch.
  ///
  /// In ru, this message translates to:
  /// **'Новая эпоха'**
  String get selfNewEpoch;

  /// No description provided for @selfDeepen.
  ///
  /// In ru, this message translates to:
  /// **'Углубиться'**
  String get selfDeepen;

  /// No description provided for @axisBody.
  ///
  /// In ru, this message translates to:
  /// **'Тело'**
  String get axisBody;

  /// No description provided for @axisMind.
  ///
  /// In ru, this message translates to:
  /// **'Ум'**
  String get axisMind;

  /// No description provided for @axisWork.
  ///
  /// In ru, this message translates to:
  /// **'Дело'**
  String get axisWork;

  /// No description provided for @axisSocial.
  ///
  /// In ru, this message translates to:
  /// **'Связи'**
  String get axisSocial;

  /// No description provided for @axisSoul.
  ///
  /// In ru, this message translates to:
  /// **'Душа'**
  String get axisSoul;

  /// No description provided for @onboardingName.
  ///
  /// In ru, this message translates to:
  /// **'Как тебя зовут?'**
  String get onboardingName;

  /// No description provided for @onboardingGoals.
  ///
  /// In ru, this message translates to:
  /// **'Какие у тебя цели?'**
  String get onboardingGoals;

  /// No description provided for @onboardingInterests.
  ///
  /// In ru, this message translates to:
  /// **'Что тебе интересно?'**
  String get onboardingInterests;

  /// No description provided for @onboardingHours.
  ///
  /// In ru, this message translates to:
  /// **'Сколько часов в неделю?'**
  String get onboardingHours;

  /// No description provided for @onboardingContinue.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get onboardingContinue;

  /// No description provided for @onboardingFinish.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get onboardingFinish;

  /// No description provided for @pomodoroTitle.
  ///
  /// In ru, this message translates to:
  /// **'Помодоро'**
  String get pomodoroTitle;

  /// No description provided for @pomodoroStart.
  ///
  /// In ru, this message translates to:
  /// **'Старт'**
  String get pomodoroStart;

  /// No description provided for @pomodoroPause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get pomodoroPause;

  /// No description provided for @pomodoroReset.
  ///
  /// In ru, this message translates to:
  /// **'Сброс'**
  String get pomodoroReset;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get settingsAbout;

  /// No description provided for @settingsAccount.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get settingsAccount;

  /// No description provided for @settingsExport.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт данных'**
  String get settingsExport;

  /// No description provided for @settingsImport.
  ///
  /// In ru, this message translates to:
  /// **'Импорт данных'**
  String get settingsImport;

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsTheme;

  /// No description provided for @settingsDarkMode.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get settingsDarkMode;

  /// No description provided for @settingsLightMode.
  ///
  /// In ru, this message translates to:
  /// **'Светлая тема'**
  String get settingsLightMode;

  /// No description provided for @knowledgeEmpty.
  ///
  /// In ru, this message translates to:
  /// **'База знаний пока пуста'**
  String get knowledgeEmpty;

  /// No description provided for @knowledgeEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте первую заметку или задачу — они появятся здесь как узлы графа.'**
  String get knowledgeEmptyHint;

  /// No description provided for @knowledgeCreateEntry.
  ///
  /// In ru, this message translates to:
  /// **'Создать запись'**
  String get knowledgeCreateEntry;

  /// No description provided for @knowledgeGoals.
  ///
  /// In ru, this message translates to:
  /// **'Цели'**
  String get knowledgeGoals;

  /// No description provided for @knowledgeConstraints.
  ///
  /// In ru, this message translates to:
  /// **'Ограничения'**
  String get knowledgeConstraints;

  /// No description provided for @knowledgeHighlights.
  ///
  /// In ru, this message translates to:
  /// **'Достижения'**
  String get knowledgeHighlights;

  /// No description provided for @knowledgeReflections.
  ///
  /// In ru, this message translates to:
  /// **'Рефлексии'**
  String get knowledgeReflections;

  /// No description provided for @knowledgePreferences.
  ///
  /// In ru, this message translates to:
  /// **'Предпочтения'**
  String get knowledgePreferences;

  /// No description provided for @calendarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get calendarTitle;

  /// No description provided for @notesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Журнал'**
  String get notesTitle;

  /// No description provided for @deleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Запись удалена'**
  String get deleteConfirm;

  /// No description provided for @deleteUndone.
  ///
  /// In ru, this message translates to:
  /// **'Восстановлено'**
  String get deleteUndone;

  /// No description provided for @emptyTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задач пока нет'**
  String get emptyTasks;

  /// No description provided for @emptyNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметок пока нет'**
  String get emptyNotes;

  /// No description provided for @greetingMorning.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро'**
  String get greetingMorning;

  /// No description provided for @greetingDay.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день'**
  String get greetingDay;

  /// No description provided for @greetingEvening.
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In ru, this message translates to:
  /// **'Доброй ночи'**
  String get greetingNight;

  /// No description provided for @reflectionHow.
  ///
  /// In ru, this message translates to:
  /// **'Как прошло?'**
  String get reflectionHow;

  /// No description provided for @reflectionEasy.
  ///
  /// In ru, this message translates to:
  /// **'Легко'**
  String get reflectionEasy;

  /// No description provided for @reflectionNormal.
  ///
  /// In ru, this message translates to:
  /// **'Нормально'**
  String get reflectionNormal;

  /// No description provided for @reflectionHard.
  ///
  /// In ru, this message translates to:
  /// **'Сложно'**
  String get reflectionHard;

  /// No description provided for @reflectionSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get reflectionSkip;

  /// No description provided for @weeklyReflection.
  ///
  /// In ru, this message translates to:
  /// **'Недельная рефлексия'**
  String get weeklyReflection;

  /// No description provided for @daysTotalStreak.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{0 дней} =1{1 день} few{{count} дня} other{{count} дней}}'**
  String daysTotalStreak(int count);

  /// No description provided for @sortSmart.
  ///
  /// In ru, this message translates to:
  /// **'Умная'**
  String get sortSmart;

  /// No description provided for @sortDueAsc.
  ///
  /// In ru, this message translates to:
  /// **'Срок ↑'**
  String get sortDueAsc;

  /// No description provided for @sortCreatedDesc.
  ///
  /// In ru, this message translates to:
  /// **'Свежие'**
  String get sortCreatedDesc;

  /// No description provided for @sortXpDesc.
  ///
  /// In ru, this message translates to:
  /// **'Тяжёлые сверху'**
  String get sortXpDesc;

  /// No description provided for @tooltipSort.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get tooltipSort;

  /// No description provided for @tooltipSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get tooltipSettings;

  /// No description provided for @noDate.
  ///
  /// In ru, this message translates to:
  /// **'Без даты'**
  String get noDate;

  /// No description provided for @allAxes.
  ///
  /// In ru, this message translates to:
  /// **'Все оси'**
  String get allAxes;

  /// No description provided for @noAxis.
  ///
  /// In ru, this message translates to:
  /// **'Без оси'**
  String get noAxis;

  /// No description provided for @expandPlans.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть планы'**
  String get expandPlans;

  /// No description provided for @collapsePlans.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть планы'**
  String get collapsePlans;

  /// No description provided for @weeklyMenu.
  ///
  /// In ru, this message translates to:
  /// **'Меню недели'**
  String get weeklyMenu;

  /// No description provided for @tasksInPlan.
  ///
  /// In ru, this message translates to:
  /// **'{count} {count, plural, =1{задача} few{задачи} other{задач}} в плане'**
  String tasksInPlan(int count);

  /// No description provided for @plansCount.
  ///
  /// In ru, this message translates to:
  /// **'Планы ({count})'**
  String plansCount(int count);

  /// No description provided for @emptyFilterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Под фильтр ничего не попало'**
  String get emptyFilterTitle;

  /// No description provided for @emptyFilterHint.
  ///
  /// In ru, this message translates to:
  /// **'Сбрось фильтры или поменяй сортировку, чтобы увидеть остальные задачи.'**
  String get emptyFilterHint;

  /// No description provided for @emptyTasksTitle.
  ///
  /// In ru, this message translates to:
  /// **'Задач нет'**
  String get emptyTasksTitle;

  /// No description provided for @emptyTasksHint.
  ///
  /// In ru, this message translates to:
  /// **'Создай задачу через «+». Привяжи её к осям — выполнение начислит очки в пентаграмму.'**
  String get emptyTasksHint;

  /// No description provided for @sectionAccount.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get sectionAccount;

  /// No description provided for @sectionProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get sectionProfile;

  /// No description provided for @sectionAxes.
  ///
  /// In ru, this message translates to:
  /// **'Оси роста'**
  String get sectionAxes;

  /// No description provided for @sectionNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get sectionNotifications;

  /// No description provided for @sectionBackend.
  ///
  /// In ru, this message translates to:
  /// **'Бэкенд'**
  String get sectionBackend;

  /// No description provided for @sectionData.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get sectionData;

  /// No description provided for @sectionAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get sectionAbout;

  /// No description provided for @sectionDeveloper.
  ///
  /// In ru, this message translates to:
  /// **'⚙ Разработчик'**
  String get sectionDeveloper;

  /// No description provided for @settingsLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get settingsLogout;

  /// No description provided for @settingsSyncNow.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать сейчас'**
  String get settingsSyncNow;

  /// No description provided for @settingsSyncHint.
  ///
  /// In ru, this message translates to:
  /// **'Стянуть данные с облака и отправить локальные изменения'**
  String get settingsSyncHint;

  /// No description provided for @settingsNotLoggedIn.
  ///
  /// In ru, this message translates to:
  /// **'Не выполнен вход'**
  String get settingsNotLoggedIn;

  /// No description provided for @settingsNotLoggedInHint.
  ///
  /// In ru, this message translates to:
  /// **'Перезапустите приложение, чтобы войти.'**
  String get settingsNotLoggedInHint;

  /// No description provided for @settingsNoName.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get settingsNoName;

  /// No description provided for @settingsNoGoal.
  ///
  /// In ru, this message translates to:
  /// **'Цель не указана'**
  String get settingsNoGoal;

  /// No description provided for @settingsRegenAxes.
  ///
  /// In ru, this message translates to:
  /// **'Перегенерировать оси'**
  String get settingsRegenAxes;

  /// No description provided for @settingsRegenAxesNoInterests.
  ///
  /// In ru, this message translates to:
  /// **'Добавь интересы в профиле, чтобы AI собрал оси'**
  String get settingsRegenAxesNoInterests;

  /// No description provided for @settingsRegenAxesHint.
  ///
  /// In ru, this message translates to:
  /// **'AI пересоберёт оси по {count} интересам'**
  String settingsRegenAxesHint(int count);

  /// No description provided for @settingsNotificationsUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления здесь не поддерживаются'**
  String get settingsNotificationsUnsupported;

  /// No description provided for @settingsLocalNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Локальные уведомления'**
  String get settingsLocalNotifications;

  /// No description provided for @settingsLocalNotificationsHint.
  ///
  /// In ru, this message translates to:
  /// **'За 1 день, утром, и через час после дедлайна'**
  String get settingsLocalNotificationsHint;

  /// No description provided for @settingsMorningReminder.
  ///
  /// In ru, this message translates to:
  /// **'Утреннее напоминание'**
  String get settingsMorningReminder;

  /// No description provided for @settingsCoachReminders.
  ///
  /// In ru, this message translates to:
  /// **'AI-коуч напоминания'**
  String get settingsCoachReminders;

  /// No description provided for @settingsCoachRemindersHint.
  ///
  /// In ru, this message translates to:
  /// **'Утренний план и вечерний разбор'**
  String get settingsCoachRemindersHint;

  /// No description provided for @settingsEveningReview.
  ///
  /// In ru, this message translates to:
  /// **'Вечерний разбор'**
  String get settingsEveningReview;

  /// No description provided for @settingsExportJson.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт в JSON'**
  String get settingsExportJson;

  /// No description provided for @settingsExportJsonHint.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить профиль, оси и записи в файл'**
  String get settingsExportJsonHint;

  /// No description provided for @settingsImportJson.
  ///
  /// In ru, this message translates to:
  /// **'Импорт из JSON'**
  String get settingsImportJson;

  /// No description provided for @settingsImportJsonHint.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить данные из буфера обмена'**
  String get settingsImportJsonHint;

  /// No description provided for @settingsEraseAll.
  ///
  /// In ru, this message translates to:
  /// **'Стереть все данные'**
  String get settingsEraseAll;

  /// No description provided for @settingsEraseAllHint.
  ///
  /// In ru, this message translates to:
  /// **'Возврат к экрану онбординга'**
  String get settingsEraseAllHint;

  /// No description provided for @settingsSourceCode.
  ///
  /// In ru, this message translates to:
  /// **'Исходный код'**
  String get settingsSourceCode;

  /// No description provided for @settingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'v0.1.0 — minimalist growth tracker'**
  String get settingsVersion;

  /// No description provided for @dialogImportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Импорт данных'**
  String get dialogImportTitle;

  /// No description provided for @dialogImportBody.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте JSON экспорта из буфера обмена. Существующие данные объединятся с импортом (entry ID используется для дедупликации).'**
  String get dialogImportBody;

  /// No description provided for @dialogPasteClipboard.
  ///
  /// In ru, this message translates to:
  /// **'Вставить из буфера'**
  String get dialogPasteClipboard;

  /// No description provided for @dialogEraseTitle.
  ///
  /// In ru, this message translates to:
  /// **'Стереть все данные?'**
  String get dialogEraseTitle;

  /// No description provided for @dialogEraseBody.
  ///
  /// In ru, this message translates to:
  /// **'Удалятся профиль, оси, задачи, заметки и настройки. Действие необратимо.'**
  String get dialogEraseBody;

  /// No description provided for @dialogErase.
  ///
  /// In ru, this message translates to:
  /// **'Стереть'**
  String get dialogErase;

  /// No description provided for @dialogLogoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get dialogLogoutTitle;

  /// No description provided for @dialogLogoutBody.
  ///
  /// In ru, this message translates to:
  /// **'Локальные данные останутся на устройстве. Чтобы они снова синхронизировались, войдите тем же Google-аккаунтом.'**
  String get dialogLogoutBody;

  /// No description provided for @snackExportSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранён: {path}'**
  String snackExportSaved(String path);

  /// No description provided for @snackCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get snackCopy;

  /// No description provided for @snackExportError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось экспортировать: {error}'**
  String snackExportError(String error);

  /// No description provided for @snackClipboardEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Буфер обмена пуст.'**
  String get snackClipboardEmpty;

  /// No description provided for @snackImportSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Импортировано {count} записей.'**
  String snackImportSuccess(int count);

  /// No description provided for @snackImportError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось импортировать: {error}'**
  String snackImportError(String error);

  /// No description provided for @snackEraseError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось стереть: {error}'**
  String snackEraseError(String error);

  /// No description provided for @snackSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация…'**
  String get snackSyncing;

  /// No description provided for @snackSyncDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово. Данные подтянуты с облака.'**
  String get snackSyncDone;

  /// No description provided for @snackSyncError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось: {error}'**
  String snackSyncError(String error);

  /// No description provided for @snackLogoutError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выйти: {error}'**
  String snackLogoutError(String error);

  /// No description provided for @loadingBackends.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get loadingBackends;

  /// No description provided for @loadingBackendsHint.
  ///
  /// In ru, this message translates to:
  /// **'Подгружаем список бэкендов…'**
  String get loadingBackendsHint;

  /// No description provided for @reflectionDidNotGo.
  ///
  /// In ru, this message translates to:
  /// **'Не пошло'**
  String get reflectionDidNotGo;

  /// No description provided for @reflectionDifficult.
  ///
  /// In ru, this message translates to:
  /// **'Сложно'**
  String get reflectionDifficult;

  /// No description provided for @reflectionOk.
  ///
  /// In ru, this message translates to:
  /// **'Норм'**
  String get reflectionOk;

  /// No description provided for @reflectionEasyShort.
  ///
  /// In ru, this message translates to:
  /// **'Легко'**
  String get reflectionEasyShort;

  /// No description provided for @entryKindTask.
  ///
  /// In ru, this message translates to:
  /// **'Задача'**
  String get entryKindTask;

  /// No description provided for @entryKindNote.
  ///
  /// In ru, this message translates to:
  /// **'Заметка'**
  String get entryKindNote;

  /// No description provided for @entryKindHabit.
  ///
  /// In ru, this message translates to:
  /// **'Привычка'**
  String get entryKindHabit;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return SEn();
    case 'ru': return SRu();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
