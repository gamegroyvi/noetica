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
  /// **'Название'**
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
  /// **'Эпоха {n}'**
  String selfEpoch(int n);

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
  /// **'Интересы'**
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
  /// **'Начать фокус'**
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
  /// **'Импорт из буфера'**
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
  /// **'Норм'**
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

  /// No description provided for @editorSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить запись: {error}'**
  String editorSaveError(String error);

  /// No description provided for @editorDeletedMsg.
  ///
  /// In ru, this message translates to:
  /// **'«{title}» удалена'**
  String editorDeletedMsg(String title);

  /// No description provided for @editorHintTask.
  ///
  /// In ru, this message translates to:
  /// **'Что нужно сделать?'**
  String get editorHintTask;

  /// No description provided for @editorNewEntry.
  ///
  /// In ru, this message translates to:
  /// **'Новая запись'**
  String get editorNewEntry;

  /// No description provided for @editorEntry.
  ///
  /// In ru, this message translates to:
  /// **'Запись'**
  String get editorEntry;

  /// No description provided for @editorExpand.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть'**
  String get editorExpand;

  /// No description provided for @editorClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get editorClose;

  /// No description provided for @editorParams.
  ///
  /// In ru, this message translates to:
  /// **'Параметры'**
  String get editorParams;

  /// No description provided for @editorMakeTask.
  ///
  /// In ru, this message translates to:
  /// **'Сделать задачей'**
  String get editorMakeTask;

  /// No description provided for @editorTaskModeHint.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайн и XP при выполнении'**
  String get editorTaskModeHint;

  /// No description provided for @editorNoteModeHint.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию — заметка'**
  String get editorNoteModeHint;

  /// No description provided for @editorNoDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Без дедлайна'**
  String get editorNoDeadline;

  /// No description provided for @editorXpOnComplete.
  ///
  /// In ru, this message translates to:
  /// **'XP при выполнении'**
  String get editorXpOnComplete;

  /// No description provided for @editorAddAxesHint.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавь оси в онбординге.'**
  String get editorAddAxesHint;

  /// No description provided for @editorUntitled.
  ///
  /// In ru, this message translates to:
  /// **'(без названия)'**
  String get editorUntitled;

  /// No description provided for @editorBacklinksCount.
  ///
  /// In ru, this message translates to:
  /// **'Сюда ссылаются ({count})'**
  String editorBacklinksCount(int count);

  /// No description provided for @editorSubtasksProgress.
  ///
  /// In ru, this message translates to:
  /// **'Подзадачи — {done}/{total}'**
  String editorSubtasksProgress(int done, int total);

  /// No description provided for @editorBodyHint.
  ///
  /// In ru, this message translates to:
  /// **'Что у тебя на уме?\nФорматирование: жирный, курсив, заголовки, чек-листы, [[ссылки на заметки]].'**
  String get editorBodyHint;

  /// No description provided for @editorToolH1.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок 1'**
  String get editorToolH1;

  /// No description provided for @editorToolH2.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок 2'**
  String get editorToolH2;

  /// No description provided for @editorToolH3.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок 3'**
  String get editorToolH3;

  /// No description provided for @editorToolBold.
  ///
  /// In ru, this message translates to:
  /// **'Жирный'**
  String get editorToolBold;

  /// No description provided for @editorToolItalic.
  ///
  /// In ru, this message translates to:
  /// **'Курсив'**
  String get editorToolItalic;

  /// No description provided for @editorToolStrike.
  ///
  /// In ru, this message translates to:
  /// **'Зачёркнутый'**
  String get editorToolStrike;

  /// No description provided for @editorToolCode.
  ///
  /// In ru, this message translates to:
  /// **'Код'**
  String get editorToolCode;

  /// No description provided for @editorToolBullet.
  ///
  /// In ru, this message translates to:
  /// **'Маркированный список'**
  String get editorToolBullet;

  /// No description provided for @editorToolNumber.
  ///
  /// In ru, this message translates to:
  /// **'Нумерованный список'**
  String get editorToolNumber;

  /// No description provided for @editorToolCheckbox.
  ///
  /// In ru, this message translates to:
  /// **'Чек-лист'**
  String get editorToolCheckbox;

  /// No description provided for @editorToolQuote.
  ///
  /// In ru, this message translates to:
  /// **'Цитата'**
  String get editorToolQuote;

  /// No description provided for @editorToolLink.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка'**
  String get editorToolLink;

  /// No description provided for @editorToolWikiLink.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на заметку'**
  String get editorToolWikiLink;

  /// No description provided for @editorToolTag.
  ///
  /// In ru, this message translates to:
  /// **'Тег'**
  String get editorToolTag;

  /// No description provided for @editorWikiLinkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на заметку'**
  String get editorWikiLinkTitle;

  /// No description provided for @editorWikiLinkHint.
  ///
  /// In ru, this message translates to:
  /// **'Начни печатать название…'**
  String get editorWikiLinkHint;

  /// No description provided for @editorCreateNote.
  ///
  /// In ru, this message translates to:
  /// **'Создать «{title}»'**
  String editorCreateNote(String title);

  /// No description provided for @calendarNoTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задач нет'**
  String get calendarNoTasks;

  /// No description provided for @calendarPlanTask.
  ///
  /// In ru, this message translates to:
  /// **'Запланировать задачу'**
  String get calendarPlanTask;

  /// No description provided for @calendarDeadlines.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайны'**
  String get calendarDeadlines;

  /// No description provided for @notesSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск заметок…'**
  String get notesSearch;

  /// No description provided for @notesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Заметок пока нет'**
  String get notesEmpty;

  /// No description provided for @notesNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая заметка'**
  String get notesNew;

  /// No description provided for @calendarNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get calendarNotes;

  /// No description provided for @dashboardOverdue.
  ///
  /// In ru, this message translates to:
  /// **'просрочена · {date}'**
  String dashboardOverdue(String date);

  /// No description provided for @dashboardDueBy.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String dashboardDueBy(String date);

  /// No description provided for @dashboardPostpone15m.
  ///
  /// In ru, this message translates to:
  /// **'+15 мин'**
  String get dashboardPostpone15m;

  /// No description provided for @dashboardPostpone1h.
  ///
  /// In ru, this message translates to:
  /// **'+1 час'**
  String get dashboardPostpone1h;

  /// No description provided for @dashboardPostpone1d.
  ///
  /// In ru, this message translates to:
  /// **'+1 день'**
  String get dashboardPostpone1d;

  /// No description provided for @dashboardPostpone3d.
  ///
  /// In ru, this message translates to:
  /// **'+3 дня'**
  String get dashboardPostpone3d;

  /// No description provided for @dashboardTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'завтра {time}'**
  String dashboardTomorrow(String time);

  /// No description provided for @dashboardYesterday.
  ///
  /// In ru, this message translates to:
  /// **'вчера {time}'**
  String dashboardYesterday(String time);

  /// No description provided for @dashboardReflectPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Заглянем коротко на пройденное?'**
  String get dashboardReflectPrompt;

  /// No description provided for @dashboardGreetingAnon.
  ///
  /// In ru, this message translates to:
  /// **'Привет'**
  String get dashboardGreetingAnon;

  /// No description provided for @dashboardGreeting.
  ///
  /// In ru, this message translates to:
  /// **'Привет, {name}'**
  String dashboardGreeting(String name);

  /// No description provided for @dashboardOnboardingHint.
  ///
  /// In ru, this message translates to:
  /// **'С чего начнём? Выбери действие ниже — это разово, потом дашборд оживёт твоими записями.'**
  String get dashboardOnboardingHint;

  /// No description provided for @dashboardRoadmapNoGoal.
  ///
  /// In ru, this message translates to:
  /// **'AI разложит твою цель на 4–10 конкретных задач, привязанных к осям пентаграммы.'**
  String get dashboardRoadmapNoGoal;

  /// No description provided for @dashboardRoadmapWithGoal.
  ///
  /// In ru, this message translates to:
  /// **'AI разложит «{goal}» на 4–10 задач. Поле уже заполнено — можно редактировать.'**
  String dashboardRoadmapWithGoal(String goal);

  /// No description provided for @dashboardGraphHint.
  ///
  /// In ru, this message translates to:
  /// **'Граф второго мозга: цели, ограничения, рефлексии и заметки. Тапни ветку — отредактируй.'**
  String get dashboardGraphHint;

  /// No description provided for @dashboardNoteHint.
  ///
  /// In ru, this message translates to:
  /// **'Лёгкий старт: пара мыслей, наблюдение или идея. Заметку можно потом превратить в задачу.'**
  String get dashboardNoteHint;

  /// No description provided for @dashboardRoadmapTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерируй план задач'**
  String get dashboardRoadmapTitle;

  /// No description provided for @dashboardGenerate.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать'**
  String get dashboardGenerate;

  /// No description provided for @dashboardGraphTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заглянь в базу знаний'**
  String get dashboardGraphTitle;

  /// No description provided for @dashboardOpenGraph.
  ///
  /// In ru, this message translates to:
  /// **'Открыть граф'**
  String get dashboardOpenGraph;

  /// No description provided for @dashboardNoteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Запиши первую заметку'**
  String get dashboardNoteTitle;

  /// No description provided for @dashboardCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get dashboardCreate;

  /// No description provided for @dashboardWeekPassed.
  ///
  /// In ru, this message translates to:
  /// **'Прошла неделя'**
  String get dashboardWeekPassed;

  /// No description provided for @pomodoroFocusDone.
  ///
  /// In ru, this message translates to:
  /// **'Фокус завершён'**
  String get pomodoroFocusDone;

  /// No description provided for @pomodoroBreakDone.
  ///
  /// In ru, this message translates to:
  /// **'Отдых завершён'**
  String get pomodoroBreakDone;

  /// No description provided for @pomodoroLongBreakBody.
  ///
  /// In ru, this message translates to:
  /// **'Время длинного отдыха {min} мин — нажми «Поехали», когда готов.'**
  String pomodoroLongBreakBody(int min);

  /// No description provided for @pomodoroShortBreakBody.
  ///
  /// In ru, this message translates to:
  /// **'Короткий отдых {min} мин — нажми «Поехали», когда готов.'**
  String pomodoroShortBreakBody(int min);

  /// No description provided for @pomodoroNextFocusBody.
  ///
  /// In ru, this message translates to:
  /// **'Следующий фокус {min} мин — нажми «Поехали», когда готов.'**
  String pomodoroNextFocusBody(int min);

  /// No description provided for @selfEpochNoData.
  ///
  /// In ru, this message translates to:
  /// **'Эпоха {n} · нет данных'**
  String selfEpochNoData(int n);

  /// No description provided for @selfToNextLevel.
  ///
  /// In ru, this message translates to:
  /// **'до L{level}: {xp} xp'**
  String selfToNextLevel(int level, int xp);

  /// No description provided for @selfTreeHint.
  ///
  /// In ru, this message translates to:
  /// **'Древо вырастает от 3 ветвей. Добавь хотя бы 3 ветви, чтобы увидеть древо.'**
  String get selfTreeHint;

  /// No description provided for @axesSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить: {error}'**
  String axesSaveError(String error);

  /// No description provided for @axesAiDrawing.
  ///
  /// In ru, this message translates to:
  /// **'AI рисует новые ветви…'**
  String get axesAiDrawing;

  /// No description provided for @axesRegenError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось перегенерировать: {error}'**
  String axesRegenError(String error);

  /// No description provided for @axesProfileUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Профиль обновлён. Хочешь сразу перегенерировать ветви?'**
  String get axesProfileUpdated;

  /// No description provided for @axesAiRedrawHint.
  ///
  /// In ru, this message translates to:
  /// **'AI перерисует набор с новыми вводными'**
  String get axesAiRedrawHint;

  /// No description provided for @axesDragHint.
  ///
  /// In ru, this message translates to:
  /// **'Перетаскивай, переименовывай, добавляй или удаляй (от {min} до {max}). Чтобы AI перерисовал ветви с нуля — Меню → «Перегенерировать».'**
  String axesDragHint(int min, int max);

  /// No description provided for @axesMaxBranches.
  ///
  /// In ru, this message translates to:
  /// **'Максимум {max} ветвей'**
  String axesMaxBranches(int max);

  /// No description provided for @axesRemoveTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get axesRemoveTooltip;

  /// No description provided for @axesMinBranches.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 3 ветви'**
  String get axesMinBranches;

  /// No description provided for @axesNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Тело'**
  String get axesNameHint;

  /// No description provided for @axesAiNewSet.
  ///
  /// In ru, this message translates to:
  /// **'AI составит новый набор. Опиши, что хочешь изменить'**
  String get axesAiNewSet;

  /// No description provided for @axesAiExample.
  ///
  /// In ru, this message translates to:
  /// **'например: больше про здоровье и творчество'**
  String get axesAiExample;

  /// No description provided for @axisXpTotal.
  ///
  /// In ru, this message translates to:
  /// **'XP ВСЕГО'**
  String get axisXpTotal;

  /// No description provided for @axisToEpoch.
  ///
  /// In ru, this message translates to:
  /// **'ДО Э{n}'**
  String axisToEpoch(int n);

  /// No description provided for @axisLevelHint.
  ///
  /// In ru, this message translates to:
  /// **'Уровень L{level} — от всех закрытых задач. Эпоха Э{epoch} — от XP именно этой оси, растёт и после того как древо заполнено на 100 %.'**
  String axisLevelHint(int level, int epoch);

  /// No description provided for @pomodoroCompleted.
  ///
  /// In ru, this message translates to:
  /// **'✦ {n}'**
  String pomodoroCompleted(int n);

  /// No description provided for @pomodoroLongBreakEvery.
  ///
  /// In ru, this message translates to:
  /// **'Длинный отдых каждые N фокусов'**
  String get pomodoroLongBreakEvery;

  /// No description provided for @knowledgeContextHint.
  ///
  /// In ru, this message translates to:
  /// **'Кратко: кто ты, чем занят, что важно'**
  String get knowledgeContextHint;

  /// No description provided for @knowledgePrefHint.
  ///
  /// In ru, this message translates to:
  /// **'ключ: значение'**
  String get knowledgePrefHint;

  /// No description provided for @navBranches.
  ///
  /// In ru, this message translates to:
  /// **'Ветви'**
  String get navBranches;

  /// No description provided for @settingsMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get settingsMore;

  /// No description provided for @settingsOnboardAgain.
  ///
  /// In ru, this message translates to:
  /// **'Пройти онбординг заново'**
  String get settingsOnboardAgain;

  /// No description provided for @settingsOnboardAgainHint.
  ///
  /// In ru, this message translates to:
  /// **'Обновить интересы, боли, цели и пересобрать ветви'**
  String get settingsOnboardAgainHint;

  /// No description provided for @settingsAddBranch.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ветвь'**
  String get settingsAddBranch;

  /// No description provided for @editorSymbol.
  ///
  /// In ru, this message translates to:
  /// **'Символ'**
  String get editorSymbol;

  /// No description provided for @roadmapMinAxes.
  ///
  /// In ru, this message translates to:
  /// **'Нужно минимум 3 оси, чтобы построить план.'**
  String get roadmapMinAxes;

  /// No description provided for @roadmapImported.
  ///
  /// In ru, this message translates to:
  /// **'Импортировано задач: {n}'**
  String roadmapImported(int n);

  /// No description provided for @roadmapImportError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось импортировать: {error}'**
  String roadmapImportError(String error);

  /// No description provided for @roadmapGoalHint.
  ///
  /// In ru, this message translates to:
  /// **'Чем конкретнее — тем точнее план. Например: «Хочу пробежать полумарафон через 3 месяца, текущая форма средняя».'**
  String get roadmapGoalHint;

  /// No description provided for @roadmapInputHint.
  ///
  /// In ru, this message translates to:
  /// **'Чего хочешь достичь?'**
  String get roadmapInputHint;

  /// No description provided for @roadmapNeedAxes.
  ///
  /// In ru, this message translates to:
  /// **'Нужно хотя бы 3 оси. Добавь их на вкладке «Я».'**
  String get roadmapNeedAxes;

  /// No description provided for @roadmapGenerating.
  ///
  /// In ru, this message translates to:
  /// **'Генерируем план…'**
  String get roadmapGenerating;

  /// No description provided for @roadmapImportBtn.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать ({n})'**
  String roadmapImportBtn(int n);

  /// No description provided for @pomodoroRunning.
  ///
  /// In ru, this message translates to:
  /// **'Pomodoro запущен'**
  String get pomodoroRunning;

  /// No description provided for @pomodoroFocusStarted.
  ///
  /// In ru, this message translates to:
  /// **'Фокус {min} мин: {title}'**
  String pomodoroFocusStarted(int min, String title);

  /// No description provided for @axisXpForAxis.
  ///
  /// In ru, this message translates to:
  /// **'+{xp} XP'**
  String axisXpForAxis(int xp);

  /// No description provided for @dashboardXpToday.
  ///
  /// In ru, this message translates to:
  /// **'XP СЕГОДНЯ'**
  String get dashboardXpToday;

  /// No description provided for @dashboardXpWeek.
  ///
  /// In ru, this message translates to:
  /// **'{xp} за неделю'**
  String dashboardXpWeek(int xp);

  /// No description provided for @dashboardBestAxis.
  ///
  /// In ru, this message translates to:
  /// **'{name} · +{xp} XP'**
  String dashboardBestAxis(String name, int xp);

  /// No description provided for @dashboardDescribeGoal.
  ///
  /// In ru, this message translates to:
  /// **'Опиши цель'**
  String get dashboardDescribeGoal;

  /// No description provided for @dashboardOverdueCount.
  ///
  /// In ru, this message translates to:
  /// **'{n} просрочено'**
  String dashboardOverdueCount(int n);

  /// No description provided for @dashboardTodayCount.
  ///
  /// In ru, this message translates to:
  /// **'{n} на сегодня'**
  String dashboardTodayCount(int n);

  /// No description provided for @dashboardThinking.
  ///
  /// In ru, this message translates to:
  /// **'Думаю над планом…'**
  String get dashboardThinking;

  /// No description provided for @aboutApp.
  ///
  /// In ru, this message translates to:
  /// **'О тебе'**
  String get aboutApp;

  /// No description provided for @knowledgePrefs.
  ///
  /// In ru, this message translates to:
  /// **'Предпочтения'**
  String get knowledgePrefs;

  /// No description provided for @actionClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get actionClear;

  /// No description provided for @roadmapHorizon.
  ///
  /// In ru, this message translates to:
  /// **'Горизонт'**
  String get roadmapHorizon;

  /// No description provided for @roadmapWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get roadmapWeek;

  /// No description provided for @roadmapMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get roadmapMonth;

  /// No description provided for @roadmapQuarter.
  ///
  /// In ru, this message translates to:
  /// **'Квартал'**
  String get roadmapQuarter;

  /// No description provided for @roadmapTaskCount.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во задач'**
  String get roadmapTaskCount;

  /// No description provided for @pomodoroTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Pomodoro'**
  String get pomodoroTooltip;

  /// No description provided for @pulseStreak.
  ///
  /// In ru, this message translates to:
  /// **'СТРИК'**
  String get pulseStreak;

  /// No description provided for @pulseStartToday.
  ///
  /// In ru, this message translates to:
  /// **'начни сегодня'**
  String get pulseStartToday;

  /// No description provided for @pulseQuiet.
  ///
  /// In ru, this message translates to:
  /// **'пока тихо'**
  String get pulseQuiet;

  /// No description provided for @pulseBestAxis.
  ///
  /// In ru, this message translates to:
  /// **'ЛУЧШАЯ ОСЬ'**
  String get pulseBestAxis;

  /// No description provided for @pulseNoData.
  ///
  /// In ru, this message translates to:
  /// **'нет данных'**
  String get pulseNoData;

  /// No description provided for @pulseDeadline.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String pulseDeadline(String date);

  /// No description provided for @pulseNoDeadline.
  ///
  /// In ru, this message translates to:
  /// **'нет дедлайнов'**
  String get pulseNoDeadline;

  /// No description provided for @pulseDeadlineHours.
  ///
  /// In ru, this message translates to:
  /// **'{h}ч'**
  String pulseDeadlineHours(int h);

  /// No description provided for @pulseDeadlineDays.
  ///
  /// In ru, this message translates to:
  /// **'{d}д'**
  String pulseDeadlineDays(int d);

  /// No description provided for @onboardQ1.
  ///
  /// In ru, this message translates to:
  /// **'Привет. Я твой ассистент роста. Как тебя зовут?'**
  String get onboardQ1;

  /// No description provided for @onboardQ2.
  ///
  /// In ru, this message translates to:
  /// **'Окей, {name}. Чего ты хочешь достичь в ближайший год?'**
  String onboardQ2(String name);

  /// No description provided for @onboardQ2NoName.
  ///
  /// In ru, this message translates to:
  /// **'Чего ты хочешь достичь в ближайший год?'**
  String get onboardQ2NoName;

  /// No description provided for @onboardQ3.
  ///
  /// In ru, this message translates to:
  /// **'В каких сферах ты уже что-то делаешь? Выбери 3–8.'**
  String get onboardQ3;

  /// No description provided for @onboardQ4.
  ///
  /// In ru, this message translates to:
  /// **'Сколько часов в неделю реально готов уделять?'**
  String get onboardQ4;

  /// No description provided for @onboardHoursWeek.
  ///
  /// In ru, this message translates to:
  /// **'ч/нед'**
  String get onboardHoursWeek;

  /// No description provided for @onboardWeeklyTime.
  ///
  /// In ru, this message translates to:
  /// **'В неделю на развитие: ~{h} ч'**
  String onboardWeeklyTime(int h);

  /// No description provided for @onboardSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить профиль: {error}'**
  String onboardSaveError(String error);

  /// No description provided for @onboardSelectOne.
  ///
  /// In ru, this message translates to:
  /// **'Выбери хотя бы одну'**
  String get onboardSelectOne;

  /// No description provided for @onboardSelectMore.
  ///
  /// In ru, this message translates to:
  /// **'Выбери ещё {n}'**
  String onboardSelectMore(int n);

  /// No description provided for @onboardCustomOpen.
  ///
  /// In ru, this message translates to:
  /// **'× своё'**
  String get onboardCustomOpen;

  /// No description provided for @onboardCustomClosed.
  ///
  /// In ru, this message translates to:
  /// **'+ своё'**
  String get onboardCustomClosed;

  /// No description provided for @onboardHoursLabel.
  ///
  /// In ru, this message translates to:
  /// **'{h} ч'**
  String onboardHoursLabel(int h);

  /// No description provided for @onboardLevelNovice.
  ///
  /// In ru, this message translates to:
  /// **'новичок'**
  String get onboardLevelNovice;

  /// No description provided for @onboardLevelLearning.
  ///
  /// In ru, this message translates to:
  /// **'учусь'**
  String get onboardLevelLearning;

  /// No description provided for @onboardLevelConfident.
  ///
  /// In ru, this message translates to:
  /// **'уверенно'**
  String get onboardLevelConfident;

  /// No description provided for @onboardLevelExpert.
  ///
  /// In ru, this message translates to:
  /// **'эксперт'**
  String get onboardLevelExpert;

  /// No description provided for @onboardProfileName.
  ///
  /// In ru, this message translates to:
  /// **'Зовут {name}.'**
  String onboardProfileName(String name);

  /// No description provided for @onboardProfileGoal.
  ///
  /// In ru, this message translates to:
  /// **'Цель: {goal}.'**
  String onboardProfileGoal(String goal);

  /// No description provided for @onboardProfileNow.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас: {text}.'**
  String onboardProfileNow(String text);

  /// No description provided for @onboardProfileHours.
  ///
  /// In ru, this message translates to:
  /// **'Готов уделять около {h} ч/нед.'**
  String onboardProfileHours(int h);

  /// No description provided for @actionNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get actionNext;

  /// No description provided for @onboardPlanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сразу набросать план?'**
  String get onboardPlanTitle;

  /// No description provided for @onboardPlanBody.
  ///
  /// In ru, this message translates to:
  /// **'AI разложит «{goal}» на 4–10 конкретных задач, привязанных к осям, которые ты только что собрала. Промпт уже заполнен — можно отредактировать, прежде чем запускать генерацию.'**
  String onboardPlanBody(String goal);

  /// No description provided for @actionLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get actionLater;

  /// No description provided for @onboardFillAxes.
  ///
  /// In ru, this message translates to:
  /// **'Заполни хотя бы 3 оси, чтобы пентаграмма имела смысл'**
  String get onboardFillAxes;

  /// No description provided for @onboardTooManyAxes.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много осей: оставь не больше 8, иначе будет хаос'**
  String get onboardTooManyAxes;

  /// No description provided for @onboardSaveAxesError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить оси: {error}'**
  String onboardSaveAxesError(String error);

  /// No description provided for @onboardRegenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Перегенерация осей'**
  String get onboardRegenTitle;

  /// No description provided for @onboardDescribeAxes.
  ///
  /// In ru, this message translates to:
  /// **'Опиши свои оси роста'**
  String get onboardDescribeAxes;

  /// No description provided for @onboardAiGenerating.
  ///
  /// In ru, this message translates to:
  /// **'AI придумывает оси…'**
  String get onboardAiGenerating;

  /// No description provided for @onboardYourAxes.
  ///
  /// In ru, this message translates to:
  /// **'Твои личные оси'**
  String get onboardYourAxes;

  /// No description provided for @onboardAxesHint.
  ///
  /// In ru, this message translates to:
  /// **'От 3 до 8 направлений, по которым ты хочешь расти. К ним будут привязываться задачи и заметки. Их можно изменить позже.'**
  String get onboardAxesHint;

  /// No description provided for @onboardAiError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось связаться с AI: {error}. Ниже — запасные оси, отредактируй как хочешь.'**
  String onboardAiError(String error);

  /// No description provided for @onboardAiDrawingAxes.
  ///
  /// In ru, this message translates to:
  /// **'Из {n} твоих направлений AI рисует персональную пентаграмму…'**
  String onboardAiDrawingAxes(int n);

  /// No description provided for @onboardAiGenerated.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировано на {model}. Переименуй, убери лишние, добавь свои. От 3 до 8.'**
  String onboardAiGenerated(String model);

  /// No description provided for @onboardRegenBtn.
  ///
  /// In ru, this message translates to:
  /// **'Перегенерировать оси'**
  String get onboardRegenBtn;

  /// No description provided for @onboardWaitSeconds.
  ///
  /// In ru, this message translates to:
  /// **'Это занимает 5–25 секунд'**
  String get onboardWaitSeconds;

  /// No description provided for @onboardAddAxis.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ось'**
  String get onboardAddAxis;

  /// No description provided for @onboardCreatePentagram.
  ///
  /// In ru, this message translates to:
  /// **'Создать пентаграмму'**
  String get onboardCreatePentagram;

  /// No description provided for @onboardAxisHint.
  ///
  /// In ru, this message translates to:
  /// **'Название оси (#{n})'**
  String onboardAxisHint(int n);

  /// No description provided for @onboardAxesUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Оси обновлены'**
  String get onboardAxesUpdated;

  /// No description provided for @onboardAxesMigrated.
  ///
  /// In ru, this message translates to:
  /// **'Оси обновлены, перенесено {n} связей с задачами'**
  String onboardAxesMigrated(int n);

  /// No description provided for @backendsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Бэкенды'**
  String get backendsTitle;

  /// No description provided for @backendsAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get backendsAdd;

  /// No description provided for @backendsError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String backendsError(String error);

  /// No description provided for @backendsHint.
  ///
  /// In ru, this message translates to:
  /// **'Активный бэкенд используется для AI, синхронизации и входа. Можно держать несколько (например, прод и личный сервер) и переключаться без перезапуска.'**
  String get backendsHint;

  /// No description provided for @backendsDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бэкенд?'**
  String get backendsDeleteTitle;

  /// No description provided for @backendsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить: {error}'**
  String backendsSaveError(String error);

  /// No description provided for @backendsPinging.
  ///
  /// In ru, this message translates to:
  /// **'Пингую…'**
  String get backendsPinging;

  /// No description provided for @backendsOnline.
  ///
  /// In ru, this message translates to:
  /// **'Бэкенд отвечает'**
  String get backendsOnline;

  /// No description provided for @backendsOffline.
  ///
  /// In ru, this message translates to:
  /// **'Не отвечает: {error}'**
  String backendsOffline(String error);

  /// No description provided for @backendsPing.
  ///
  /// In ru, this message translates to:
  /// **'Пинг'**
  String get backendsPing;

  /// No description provided for @backendsMakeActive.
  ///
  /// In ru, this message translates to:
  /// **'Сделать активным'**
  String get backendsMakeActive;

  /// No description provided for @backendsEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get backendsEdit;

  /// No description provided for @backendsLastOne.
  ///
  /// In ru, this message translates to:
  /// **'Должен остаться хотя бы один бэкенд'**
  String get backendsLastOne;

  /// No description provided for @backendsNewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый бэкенд'**
  String get backendsNewTitle;

  /// No description provided for @backendsEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить бэкенд'**
  String get backendsEditTitle;

  /// No description provided for @backendsName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get backendsName;

  /// No description provided for @backendsNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Прод · Локалка · Запасной'**
  String get backendsNameHint;

  /// No description provided for @backendsUrlError.
  ///
  /// In ru, this message translates to:
  /// **'Введите валидный URL начинающийся с http(s)://'**
  String get backendsUrlError;

  /// No description provided for @menuTitle.
  ///
  /// In ru, this message translates to:
  /// **'Меню недели'**
  String get menuTitle;

  /// No description provided for @menuNewConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать новое меню?'**
  String get menuNewConfirmTitle;

  /// No description provided for @menuNewConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Текущие задачи и рецепты останутся в базе знаний — их можно найти по тегу menu/… или открыть по ссылке.\n\nФорма генерации откроется заново.'**
  String get menuNewConfirmBody;

  /// No description provided for @actionCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get actionCreate;

  /// No description provided for @menuBreakfast.
  ///
  /// In ru, this message translates to:
  /// **'Завтрак'**
  String get menuBreakfast;

  /// No description provided for @menuLunch.
  ///
  /// In ru, this message translates to:
  /// **'Обед'**
  String get menuLunch;

  /// No description provided for @menuDinner.
  ///
  /// In ru, this message translates to:
  /// **'Ужин'**
  String get menuDinner;

  /// No description provided for @menuSnack.
  ///
  /// In ru, this message translates to:
  /// **'Перекус'**
  String get menuSnack;

  /// No description provided for @menuRecipeStubTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рецепт: {name}'**
  String menuRecipeStubTitle(String name);

  /// No description provided for @menuRecipeStubBody.
  ///
  /// In ru, this message translates to:
  /// **'_Рецепт ещё не сгенерирован._\n\nОткрой меню недели → нажми «Получить рецепт» рядом с этим блюдом.'**
  String get menuRecipeStubBody;

  /// No description provided for @menuShoppingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Список покупок · меню {range}'**
  String menuShoppingTitle(String range);

  /// No description provided for @menuShoppingHeader.
  ///
  /// In ru, this message translates to:
  /// **'Список покупок на неделю'**
  String get menuShoppingHeader;

  /// No description provided for @menuGoalServings.
  ///
  /// In ru, this message translates to:
  /// **'Цель: {goal} · {n} порций'**
  String menuGoalServings(String goal, int n);

  /// No description provided for @menuImportError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось импортировать меню: {error}'**
  String menuImportError(String error);

  /// No description provided for @menuIngredients.
  ///
  /// In ru, this message translates to:
  /// **'ИНГРЕДИЕНТЫ'**
  String get menuIngredients;

  /// No description provided for @menuFullRecipe.
  ///
  /// In ru, this message translates to:
  /// **'Полный рецепт: [[{link}]]'**
  String menuFullRecipe(String link);

  /// No description provided for @menuGenerating.
  ///
  /// In ru, this message translates to:
  /// **'AI составляет меню…'**
  String get menuGenerating;

  /// No description provided for @menuImporting.
  ///
  /// In ru, this message translates to:
  /// **'Создаю задачи и список покупок…'**
  String get menuImporting;

  /// No description provided for @menuDateRange.
  ///
  /// In ru, this message translates to:
  /// **'7 дней с {from} по {to}'**
  String menuDateRange(String from, String to);

  /// No description provided for @menuWhatCreated.
  ///
  /// In ru, this message translates to:
  /// **'Что я создам'**
  String get menuWhatCreated;

  /// No description provided for @menuBullet1.
  ///
  /// In ru, this message translates to:
  /// **'21 задача (завтрак / обед / ужин на 7 дней)'**
  String get menuBullet1;

  /// No description provided for @menuBullet2.
  ///
  /// In ru, this message translates to:
  /// **'1 заметка «Список покупок» с чек-листом'**
  String get menuBullet2;

  /// No description provided for @menuBullet3.
  ///
  /// In ru, this message translates to:
  /// **'Рецепты подгрузятся по тапу и сохранятся в связанные заметки'**
  String get menuBullet3;

  /// No description provided for @menuRegenerate.
  ///
  /// In ru, this message translates to:
  /// **'Перегенерировать'**
  String get menuRegenerate;

  /// No description provided for @menuImportBtn.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать в задачи'**
  String get menuImportBtn;

  /// No description provided for @menuImportedCount.
  ///
  /// In ru, this message translates to:
  /// **'Меню импортировано · {n} задач'**
  String menuImportedCount(int n);

  /// No description provided for @menuNew.
  ///
  /// In ru, this message translates to:
  /// **'Новое меню'**
  String get menuNew;

  /// No description provided for @menuImportedHint.
  ///
  /// In ru, this message translates to:
  /// **'Тег #{tag} группирует все эти записи. Тапни блюдо — открой задачу. Нажми «Получить рецепт» на любом блюде — рецепт сохранится в связанной заметке.'**
  String menuImportedHint(String tag);

  /// No description provided for @menuServings.
  ///
  /// In ru, this message translates to:
  /// **'{n} порций'**
  String menuServings(int n);

  /// No description provided for @menuDailyCalories.
  ///
  /// In ru, this message translates to:
  /// **'~{n} ккал в день'**
  String menuDailyCalories(int n);

  /// No description provided for @menuOpenRecipe.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get menuOpenRecipe;

  /// No description provided for @menuGetRecipe.
  ///
  /// In ru, this message translates to:
  /// **'Получить рецепт'**
  String get menuGetRecipe;

  /// No description provided for @habitsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Микро-привычки'**
  String get habitsTitle;

  /// No description provided for @habitsIntentError.
  ///
  /// In ru, this message translates to:
  /// **'Опиши, какую привычку хочешь освоить.'**
  String get habitsIntentError;

  /// No description provided for @habitsDayOf.
  ///
  /// In ru, this message translates to:
  /// **'День {day} из {total} · челлендж «{intent}»'**
  String habitsDayOf(int day, int total, String intent);

  /// No description provided for @habitsImported.
  ///
  /// In ru, this message translates to:
  /// **'Челлендж «{intent}» добавлен — {n} мини-задач в Задачах.'**
  String habitsImported(String intent, int n);

  /// No description provided for @habitsImportError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось импортировать челлендж: {error}'**
  String habitsImportError(String error);

  /// No description provided for @habitsGenerating.
  ///
  /// In ru, this message translates to:
  /// **'AI подбирает крошечные шаги…'**
  String get habitsGenerating;

  /// No description provided for @habitsImporting.
  ///
  /// In ru, this message translates to:
  /// **'Создаю задачи в Noetica…'**
  String get habitsImporting;

  /// No description provided for @habitsBullet1.
  ///
  /// In ru, this message translates to:
  /// **'{n} задач — по одной на день, от лёгкой к закрепляющей'**
  String habitsBullet1(int n);

  /// No description provided for @habitsBullet2.
  ///
  /// In ru, this message translates to:
  /// **'Каждое действие ≤ 2 минут реального усилия'**
  String get habitsBullet2;

  /// No description provided for @habitsBullet3.
  ///
  /// In ru, this message translates to:
  /// **'Появятся в Задачах в секциях «Сегодня» / «Завтра» / …'**
  String get habitsBullet3;

  /// No description provided for @habitsDaysMini.
  ///
  /// In ru, this message translates to:
  /// **'{n} дней · по одной мини-задаче'**
  String habitsDaysMini(int n);

  /// No description provided for @habitsAddTasks.
  ///
  /// In ru, this message translates to:
  /// **'Добавить {n} задач'**
  String habitsAddTasks(int n);

  /// No description provided for @coachMorningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Утренний план'**
  String get coachMorningTitle;

  /// No description provided for @coachEveningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вечерний разбор'**
  String get coachEveningTitle;

  /// No description provided for @coachRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get coachRefresh;

  /// No description provided for @coachError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить совет'**
  String get coachError;

  /// No description provided for @coachRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get coachRetry;

  /// No description provided for @coachFocus.
  ///
  /// In ru, this message translates to:
  /// **'Фокус дня'**
  String get coachFocus;

  /// No description provided for @coachPlanToday.
  ///
  /// In ru, this message translates to:
  /// **'План на сегодня'**
  String get coachPlanToday;

  /// No description provided for @coachMotivation.
  ///
  /// In ru, this message translates to:
  /// **'Мотивация'**
  String get coachMotivation;

  /// No description provided for @coachDayResults.
  ///
  /// In ru, this message translates to:
  /// **'Итоги дня'**
  String get coachDayResults;

  /// No description provided for @coachSummary.
  ///
  /// In ru, this message translates to:
  /// **'Резюме'**
  String get coachSummary;

  /// No description provided for @coachWins.
  ///
  /// In ru, this message translates to:
  /// **'Что получилось'**
  String get coachWins;

  /// No description provided for @coachImprove.
  ///
  /// In ru, this message translates to:
  /// **'Что улучшить'**
  String get coachImprove;

  /// No description provided for @coachTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'На завтра'**
  String get coachTomorrow;

  /// No description provided for @reflectionResult.
  ///
  /// In ru, this message translates to:
  /// **'Что получилось / результат'**
  String get reflectionResult;

  /// No description provided for @reflectionDifficulties.
  ///
  /// In ru, this message translates to:
  /// **'Что мешало / сложности'**
  String get reflectionDifficulties;

  /// No description provided for @reflectionMinutes.
  ///
  /// In ru, this message translates to:
  /// **'Сколько потратил, мин'**
  String get reflectionMinutes;

  /// No description provided for @reflectionCanSkip.
  ///
  /// In ru, this message translates to:
  /// **'Можно пропустить'**
  String get reflectionCanSkip;

  /// No description provided for @toolsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ассистент'**
  String get toolsTitle;

  /// No description provided for @toolsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступно'**
  String get toolsAvailable;

  /// No description provided for @toolsSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро'**
  String get toolsSoon;

  /// No description provided for @toolsDescriptionFull.
  ///
  /// In ru, this message translates to:
  /// **'AI собирает готовые планы и раскладывает их по твоим дням, осям и тегам. Меню на неделю, программа тренировок, учебный курс — всё попадает в Календарь и Задачи как обычные записи.'**
  String get toolsDescriptionFull;

  /// No description provided for @toolsOpening.
  ///
  /// In ru, this message translates to:
  /// **'Открываю «{title}»…'**
  String toolsOpening(String title);

  /// No description provided for @toolsComingSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро: «{title}»'**
  String toolsComingSoon(String title);

  /// No description provided for @authLoginError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось войти: {error}'**
  String authLoginError(String error);

  /// No description provided for @authWait.
  ///
  /// In ru, this message translates to:
  /// **'Подождите…'**
  String get authWait;

  /// No description provided for @authLoginGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get authLoginGoogle;

  /// No description provided for @authSyncHint.
  ///
  /// In ru, this message translates to:
  /// **'Ваши данные синхронизируются между устройствами под одним Google-аккаунтом. Без входа приложение не работает.'**
  String get authSyncHint;

  /// No description provided for @dayCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get dayCalendar;

  /// No description provided for @dayPlanTask.
  ///
  /// In ru, this message translates to:
  /// **'Запланировать задачу'**
  String get dayPlanTask;

  /// No description provided for @dayEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В этот день ничего не закрыто и не запланировано.'**
  String get dayEmpty;

  /// No description provided for @dayNoEntries.
  ///
  /// In ru, this message translates to:
  /// **'Без записей.'**
  String get dayNoEntries;

  /// No description provided for @dayToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get dayYesterday;

  /// No description provided for @dayTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get dayTomorrow;

  /// No description provided for @dayMonths.
  ///
  /// In ru, this message translates to:
  /// **'янв,фев,мар,апр,мая,июн,июл,авг,сен,окт,ноя,дек'**
  String get dayMonths;

  /// No description provided for @dayWeekdays.
  ///
  /// In ru, this message translates to:
  /// **'пн,вт,ср,чт,пт,сб,вс'**
  String get dayWeekdays;

  /// No description provided for @dayDone.
  ///
  /// In ru, this message translates to:
  /// **'✓ Выполнено ({n})'**
  String dayDone(int n);

  /// No description provided for @dayDeadlines.
  ///
  /// In ru, this message translates to:
  /// **'⏳ Дедлайны ({n})'**
  String dayDeadlines(int n);

  /// No description provided for @daySummaryClosed.
  ///
  /// In ru, this message translates to:
  /// **'{n} закрыто · +{xp} XP'**
  String daySummaryClosed(int n, int xp);

  /// No description provided for @daySummaryDeadline.
  ///
  /// In ru, this message translates to:
  /// **'{n} дедлайн'**
  String daySummaryDeadline(int n);

  /// No description provided for @untitled.
  ///
  /// In ru, this message translates to:
  /// **'(без названия)'**
  String get untitled;

  /// No description provided for @weeklyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Недельный обзор'**
  String get weeklyTitle;

  /// No description provided for @weeklyAxis.
  ///
  /// In ru, this message translates to:
  /// **'Ось'**
  String get weeklyAxis;

  /// No description provided for @weeklyCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершено'**
  String get weeklyCompleted;

  /// No description provided for @weeklyXP.
  ///
  /// In ru, this message translates to:
  /// **'Опыт'**
  String get weeklyXP;

  /// No description provided for @weeklyTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задач'**
  String get weeklyTasks;

  /// No description provided for @weeklyNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметок'**
  String get weeklyNotes;

  /// No description provided for @weeklyStreak.
  ///
  /// In ru, this message translates to:
  /// **'Стрик'**
  String get weeklyStreak;

  /// No description provided for @weeklyBestDay.
  ///
  /// In ru, this message translates to:
  /// **'Лучший день'**
  String get weeklyBestDay;

  /// No description provided for @weeklyWorstDay.
  ///
  /// In ru, this message translates to:
  /// **'Слабый день'**
  String get weeklyWorstDay;

  /// No description provided for @weeklyHighlights.
  ///
  /// In ru, this message translates to:
  /// **'Главное за неделю'**
  String get weeklyHighlights;

  /// No description provided for @weeklyAdvice.
  ///
  /// In ru, this message translates to:
  /// **'Совет на следующую'**
  String get weeklyAdvice;

  /// No description provided for @weeklyNoData.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно данных'**
  String get weeklyNoData;

  /// No description provided for @weeklyDays.
  ///
  /// In ru, this message translates to:
  /// **'пн,вт,ср,чт,пт,сб,вс'**
  String get weeklyDays;

  /// No description provided for @weeklyMonths.
  ///
  /// In ru, this message translates to:
  /// **'янв,фев,мар,апр,мая,июн,июл,авг,сен,окт,ноя,дек'**
  String get weeklyMonths;

  /// No description provided for @weeklyDone.
  ///
  /// In ru, this message translates to:
  /// **'выполнено'**
  String get weeklyDone;

  /// No description provided for @weeklyCreated.
  ///
  /// In ru, this message translates to:
  /// **'создано'**
  String get weeklyCreated;

  /// No description provided for @weeklyGenerating.
  ///
  /// In ru, this message translates to:
  /// **'AI анализирует неделю…'**
  String get weeklyGenerating;

  /// No description provided for @weeklyShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get weeklyShare;

  /// No description provided for @weeklyClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get weeklyClose;

  /// No description provided for @weeklyTotal.
  ///
  /// In ru, this message translates to:
  /// **'итого'**
  String get weeklyTotal;

  /// No description provided for @weeklyReflTitle.
  ///
  /// In ru, this message translates to:
  /// **'Итог недели'**
  String get weeklyReflTitle;

  /// No description provided for @weeklyReflSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Заглянем коротко: что было, что нет, и куда дальше.'**
  String get weeklyReflSubtitle;

  /// No description provided for @weeklyWinsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Что получилось'**
  String get weeklyWinsLabel;

  /// No description provided for @weeklyLossesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Что не получилось'**
  String get weeklyLossesLabel;

  /// No description provided for @weeklyFocusLabel.
  ///
  /// In ru, this message translates to:
  /// **'Куда смотрю на следующую'**
  String get weeklyFocusLabel;

  /// No description provided for @weeklyMoodLabel.
  ///
  /// In ru, this message translates to:
  /// **'Самочувствие'**
  String get weeklyMoodLabel;

  /// No description provided for @weeklyLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get weeklyLater;

  /// No description provided for @weeklySubmit.
  ///
  /// In ru, this message translates to:
  /// **'Записать'**
  String get weeklySubmit;

  /// No description provided for @weeklyCustomHint.
  ///
  /// In ru, this message translates to:
  /// **'Своё (необязательно)'**
  String get weeklyCustomHint;

  /// No description provided for @weeklySaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не сохранилось: {error}'**
  String weeklySaveError(String error);

  /// No description provided for @weeklyMoodSummary.
  ///
  /// In ru, this message translates to:
  /// **'самочувствие {n}/5'**
  String weeklyMoodSummary(int n);

  /// No description provided for @weeklyWin1.
  ///
  /// In ru, this message translates to:
  /// **'выполнил план'**
  String get weeklyWin1;

  /// No description provided for @weeklyWin2.
  ///
  /// In ru, this message translates to:
  /// **'новые привычки'**
  String get weeklyWin2;

  /// No description provided for @weeklyWin3.
  ///
  /// In ru, this message translates to:
  /// **'продвинулся в проекте'**
  String get weeklyWin3;

  /// No description provided for @weeklyWin4.
  ///
  /// In ru, this message translates to:
  /// **'отдых был'**
  String get weeklyWin4;

  /// No description provided for @weeklyWin5.
  ///
  /// In ru, this message translates to:
  /// **'дисциплина держалась'**
  String get weeklyWin5;

  /// No description provided for @weeklyWin6.
  ///
  /// In ru, this message translates to:
  /// **'разобрался в новой теме'**
  String get weeklyWin6;

  /// No description provided for @weeklyWin7.
  ///
  /// In ru, this message translates to:
  /// **'хорошие отношения'**
  String get weeklyWin7;

  /// No description provided for @weeklyLoss1.
  ///
  /// In ru, this message translates to:
  /// **'прокрастинация'**
  String get weeklyLoss1;

  /// No description provided for @weeklyLoss2.
  ///
  /// In ru, this message translates to:
  /// **'усталость'**
  String get weeklyLoss2;

  /// No description provided for @weeklyLoss3.
  ///
  /// In ru, this message translates to:
  /// **'отвлечения'**
  String get weeklyLoss3;

  /// No description provided for @weeklyLoss4.
  ///
  /// In ru, this message translates to:
  /// **'не уделил время важному'**
  String get weeklyLoss4;

  /// No description provided for @weeklyLoss5.
  ///
  /// In ru, this message translates to:
  /// **'выгорание'**
  String get weeklyLoss5;

  /// No description provided for @weeklyLoss6.
  ///
  /// In ru, this message translates to:
  /// **'болел'**
  String get weeklyLoss6;

  /// No description provided for @weeklyLoss7.
  ///
  /// In ru, this message translates to:
  /// **'конфликты'**
  String get weeklyLoss7;

  /// No description provided for @weeklyFocus1.
  ///
  /// In ru, this message translates to:
  /// **'добить незавершённое'**
  String get weeklyFocus1;

  /// No description provided for @weeklyFocus2.
  ///
  /// In ru, this message translates to:
  /// **'новая привычка'**
  String get weeklyFocus2;

  /// No description provided for @weeklyFocus3.
  ///
  /// In ru, this message translates to:
  /// **'фокус на главном'**
  String get weeklyFocus3;

  /// No description provided for @weeklyFocus4.
  ///
  /// In ru, this message translates to:
  /// **'отдых'**
  String get weeklyFocus4;

  /// No description provided for @weeklyFocus5.
  ///
  /// In ru, this message translates to:
  /// **'учёба'**
  String get weeklyFocus5;

  /// No description provided for @weeklyFocus6.
  ///
  /// In ru, this message translates to:
  /// **'спорт'**
  String get weeklyFocus6;

  /// No description provided for @weeklyFocus7.
  ///
  /// In ru, this message translates to:
  /// **'отношения'**
  String get weeklyFocus7;

  /// No description provided for @epochPeak.
  ///
  /// In ru, this message translates to:
  /// **'ЭПОХА {n} · ПИК'**
  String epochPeak(int n);

  /// No description provided for @epochPostpone.
  ///
  /// In ru, this message translates to:
  /// **'Отложить'**
  String get epochPostpone;

  /// No description provided for @epochTreeFull.
  ///
  /// In ru, this message translates to:
  /// **'Ты заполнил древо.'**
  String get epochTreeFull;

  /// No description provided for @epochTwoPaths.
  ///
  /// In ru, this message translates to:
  /// **'Два пути дальше — можешь обновить сам набор осей и начать Эпоху {n} с чистого листа, либо остаться в текущем фокусе и взять следующий, более трудный тир задач.'**
  String epochTwoPaths(int n);

  /// No description provided for @epochNewEpoch.
  ///
  /// In ru, this message translates to:
  /// **'Новая эпоха'**
  String get epochNewEpoch;

  /// No description provided for @epochNewEpochSub.
  ///
  /// In ru, this message translates to:
  /// **'Перерисовать ветви — Эпоха {n}. XP и уровень остаются.'**
  String epochNewEpochSub(int n);

  /// No description provided for @epochGoDeeper.
  ///
  /// In ru, this message translates to:
  /// **'Углубиться'**
  String get epochGoDeeper;

  /// No description provided for @epochGoDeeperSub.
  ///
  /// In ru, this message translates to:
  /// **'Тир {n} в той же Эпохе — задачи станут сложнее, древо обнулится.'**
  String epochGoDeeperSub(int n);

  /// No description provided for @graphBranchGoals.
  ///
  /// In ru, this message translates to:
  /// **'Цели'**
  String get graphBranchGoals;

  /// No description provided for @graphBranchConstraints.
  ///
  /// In ru, this message translates to:
  /// **'Ограничения'**
  String get graphBranchConstraints;

  /// No description provided for @graphBranchHighlights.
  ///
  /// In ru, this message translates to:
  /// **'Достижения'**
  String get graphBranchHighlights;

  /// No description provided for @graphBranchReflections.
  ///
  /// In ru, this message translates to:
  /// **'Рефлексии'**
  String get graphBranchReflections;

  /// No description provided for @graphBranchPreferences.
  ///
  /// In ru, this message translates to:
  /// **'Предпочтения'**
  String get graphBranchPreferences;

  /// No description provided for @graphFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get graphFilterAll;

  /// No description provided for @graphFilterNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get graphFilterNotes;

  /// No description provided for @graphFilterTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get graphFilterTasks;

  /// No description provided for @graphFilterBookmarks.
  ///
  /// In ru, this message translates to:
  /// **'Закладки'**
  String get graphFilterBookmarks;

  /// No description provided for @graphFilterDaily.
  ///
  /// In ru, this message translates to:
  /// **'Дневник'**
  String get graphFilterDaily;

  /// No description provided for @graphFilterKnowledge.
  ///
  /// In ru, this message translates to:
  /// **'Знания о себе'**
  String get graphFilterKnowledge;

  /// No description provided for @pomodoroStop.
  ///
  /// In ru, this message translates to:
  /// **'Стоп'**
  String get pomodoroStop;

  /// No description provided for @pomodoroSeries.
  ///
  /// In ru, this message translates to:
  /// **'Серия фокус-сессий'**
  String get pomodoroSeries;

  /// No description provided for @pomodoroSeriesReset.
  ///
  /// In ru, this message translates to:
  /// **'Серия фокус-сессий — нажми чтобы сбросить'**
  String get pomodoroSeriesReset;

  /// No description provided for @pomodoroSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get pomodoroSettings;

  /// No description provided for @pomodoroFocusMin.
  ///
  /// In ru, this message translates to:
  /// **'Фокус, мин'**
  String get pomodoroFocusMin;

  /// No description provided for @pomodoroShortBreak.
  ///
  /// In ru, this message translates to:
  /// **'Короткий отдых, мин'**
  String get pomodoroShortBreak;

  /// No description provided for @pomodoroLongBreak.
  ///
  /// In ru, this message translates to:
  /// **'Длинный отдых'**
  String get pomodoroLongBreak;

  /// No description provided for @pomodoroAutoStart.
  ///
  /// In ru, this message translates to:
  /// **'Авто-старт следующей фазы'**
  String get pomodoroAutoStart;

  /// No description provided for @pomodoroAutoStartSub.
  ///
  /// In ru, this message translates to:
  /// **'После окончания фокуса/отдыха таймер продолжается сам'**
  String get pomodoroAutoStartSub;

  /// No description provided for @pomodoroSoundVibro.
  ///
  /// In ru, this message translates to:
  /// **'Звук + вибрация'**
  String get pomodoroSoundVibro;

  /// No description provided for @pomodoroSoundVibroSub.
  ///
  /// In ru, this message translates to:
  /// **'Системный «дзынь» и хаптик при смене фазы (уведомление приходит в любом случае)'**
  String get pomodoroSoundVibroSub;

  /// No description provided for @graphCentreLabel.
  ///
  /// In ru, this message translates to:
  /// **'я'**
  String get graphCentreLabel;

  /// No description provided for @graphGoalsHint.
  ///
  /// In ru, this message translates to:
  /// **'Что хочешь достичь'**
  String get graphGoalsHint;

  /// No description provided for @graphConstraintsHint.
  ///
  /// In ru, this message translates to:
  /// **'Что мешает или ограничивает'**
  String get graphConstraintsHint;

  /// No description provided for @graphHighlightsHint.
  ///
  /// In ru, this message translates to:
  /// **'Что уже получилось'**
  String get graphHighlightsHint;

  /// No description provided for @graphReflectionsHint.
  ///
  /// In ru, this message translates to:
  /// **'Заметки о пройденном'**
  String get graphReflectionsHint;

  /// No description provided for @graphDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get graphDelete;

  /// No description provided for @graphSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по базе знаний…'**
  String get graphSearchHint;

  /// No description provided for @graphKnowledgeBase.
  ///
  /// In ru, this message translates to:
  /// **'База знаний'**
  String get graphKnowledgeBase;

  /// No description provided for @graphSearchTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get graphSearchTooltip;

  /// No description provided for @graphDailyTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Дневник'**
  String get graphDailyTooltip;

  /// No description provided for @graphShowRecipes.
  ///
  /// In ru, this message translates to:
  /// **'Показывать рецепты'**
  String get graphShowRecipes;

  /// No description provided for @graphHideRecipes.
  ///
  /// In ru, this message translates to:
  /// **'Скрывать рецепты'**
  String get graphHideRecipes;

  /// No description provided for @graphGlobalTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Глобальный граф'**
  String get graphGlobalTooltip;

  /// No description provided for @graphNewNote.
  ///
  /// In ru, this message translates to:
  /// **'Новая заметка'**
  String get graphNewNote;

  /// No description provided for @graphResetView.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить вид'**
  String get graphResetView;

  /// No description provided for @graphShuffle.
  ///
  /// In ru, this message translates to:
  /// **'Перемешать'**
  String get graphShuffle;

  /// No description provided for @graphEmptyTitle1.
  ///
  /// In ru, this message translates to:
  /// **'Записывай'**
  String get graphEmptyTitle1;

  /// No description provided for @graphEmptyBody1.
  ///
  /// In ru, this message translates to:
  /// **'Заметки, задачи, дневник — всё становится узлами графа.'**
  String get graphEmptyBody1;

  /// No description provided for @graphEmptyTitle2.
  ///
  /// In ru, this message translates to:
  /// **'Связывай'**
  String get graphEmptyTitle2;

  /// No description provided for @graphEmptyBody2.
  ///
  /// In ru, this message translates to:
  /// **'Упоминай [[заголовок]] в тексте — Noetica построит ребро.'**
  String get graphEmptyBody2;

  /// No description provided for @graphEmptyTitle3.
  ///
  /// In ru, this message translates to:
  /// **'Изучай'**
  String get graphEmptyTitle3;

  /// No description provided for @graphEmptyBody3.
  ///
  /// In ru, this message translates to:
  /// **'Граф покажет, какие темы пересекаются и где пусто.'**
  String get graphEmptyBody3;

  /// No description provided for @graphEmptyTitle4.
  ///
  /// In ru, this message translates to:
  /// **'О себе'**
  String get graphEmptyTitle4;

  /// No description provided for @graphEmptyBody4.
  ///
  /// In ru, this message translates to:
  /// **'Цели, ограничения, достижения — эти ветки помогут AI.'**
  String get graphEmptyBody4;

  /// No description provided for @graphEmptyTitle5.
  ///
  /// In ru, this message translates to:
  /// **'Первая запись'**
  String get graphEmptyTitle5;

  /// No description provided for @graphEmptyBody5.
  ///
  /// In ru, this message translates to:
  /// **'Нажми +, чтобы создать заметку и увидеть граф в действии.'**
  String get graphEmptyBody5;

  /// No description provided for @graphEmptyTitle6.
  ///
  /// In ru, this message translates to:
  /// **'Теги'**
  String get graphEmptyTitle6;

  /// No description provided for @graphEmptyBody6.
  ///
  /// In ru, this message translates to:
  /// **'Добавляй теги к записям — они тоже станут узлами.'**
  String get graphEmptyBody6;

  /// No description provided for @graphResetFilter.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтр'**
  String get graphResetFilter;

  /// No description provided for @graphEmptyAllTitle.
  ///
  /// In ru, this message translates to:
  /// **'База знаний пока пуста'**
  String get graphEmptyAllTitle;

  /// No description provided for @graphEmptyAllBody.
  ///
  /// In ru, this message translates to:
  /// **'Создайте первую заметку или задачу — они появятся здесь как узлы графа.'**
  String get graphEmptyAllBody;

  /// No description provided for @graphEmptyAllAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать запись'**
  String get graphEmptyAllAction;

  /// No description provided for @graphEmptyNotesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заметок пока нет'**
  String get graphEmptyNotesTitle;

  /// No description provided for @graphEmptyNotesBody.
  ///
  /// In ru, this message translates to:
  /// **'Заметки будут видны как отдельные узлы. Связи появляются автоматически, когда в теле есть [[ссылка]] на другую заметку.'**
  String get graphEmptyNotesBody;

  /// No description provided for @graphEmptyNotesAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать заметку'**
  String get graphEmptyNotesAction;

  /// No description provided for @graphEmptyTasksTitle.
  ///
  /// In ru, this message translates to:
  /// **'Задач в графе нет'**
  String get graphEmptyTasksTitle;

  /// No description provided for @graphEmptyTasksBody.
  ///
  /// In ru, this message translates to:
  /// **'Создайте задачу через «+» или сгенерируйте план задач из вашей цели.'**
  String get graphEmptyTasksBody;

  /// No description provided for @graphEmptyBookmarksTitle.
  ///
  /// In ru, this message translates to:
  /// **'Закладок пока нет'**
  String get graphEmptyBookmarksTitle;

  /// No description provided for @graphEmptyBookmarksBody.
  ///
  /// In ru, this message translates to:
  /// **'Долгое нажатие на узел графа добавит его в закладки.'**
  String get graphEmptyBookmarksBody;

  /// No description provided for @graphEmptyDailyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дневник пуст'**
  String get graphEmptyDailyTitle;

  /// No description provided for @graphEmptyDailyBody.
  ///
  /// In ru, this message translates to:
  /// **'Тапните иконку календаря в шапке, чтобы создать запись на сегодня.'**
  String get graphEmptyDailyBody;

  /// No description provided for @graphEmptyKnowledgeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Знания о себе пусты'**
  String get graphEmptyKnowledgeTitle;

  /// No description provided for @graphEmptyKnowledgeBody.
  ///
  /// In ru, this message translates to:
  /// **'Заполните цели, ограничения и достижения через тапы по веткам графа — это даст AI больше контекста для генерации планов.'**
  String get graphEmptyKnowledgeBody;

  /// No description provided for @editListAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get editListAdd;

  /// No description provided for @editListRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get editListRemove;

  /// No description provided for @editListSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get editListSave;

  /// No description provided for @graphConnections.
  ///
  /// In ru, this message translates to:
  /// **'связей'**
  String get graphConnections;

  /// No description provided for @selfBranchesTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Ветви'**
  String get selfBranchesTooltip;

  /// No description provided for @selfSettingsTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get selfSettingsTooltip;

  /// No description provided for @selfTreeBranches.
  ///
  /// In ru, this message translates to:
  /// **'ДРЕВО · ВЕТКИ'**
  String get selfTreeBranches;

  /// No description provided for @selfGeneratePlan.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать план'**
  String get selfGeneratePlan;

  /// No description provided for @selfScoreExplain.
  ///
  /// In ru, this message translates to:
  /// **'Очки начисляются за выполнение задач, привязанных к осям. Со временем затухают — пентаграмма отражает тебя за последний месяц.'**
  String get selfScoreExplain;

  /// No description provided for @selfEpochArchive.
  ///
  /// In ru, this message translates to:
  /// **'ЭПОХА {n} · АРХИВ'**
  String selfEpochArchive(int n);

  /// No description provided for @selfArchiveReadonly.
  ///
  /// In ru, this message translates to:
  /// **'Древо этой эпохи на момент перехода. Только просмотр.'**
  String get selfArchiveReadonly;

  /// No description provided for @selfArchiveEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Архив этой эпохи пустой — она завершилась до того, как мы начали записывать историю. Будущие переходы сохранятся целиком.'**
  String get selfArchiveEmpty;

  /// No description provided for @selfArchiveBranches.
  ///
  /// In ru, this message translates to:
  /// **'ВЕТВИ ТОЙ ЭПОХИ'**
  String get selfArchiveBranches;

  /// No description provided for @selfEpochLabel.
  ///
  /// In ru, this message translates to:
  /// **'ЭПОХА'**
  String get selfEpochLabel;

  /// No description provided for @selfEpochShort.
  ///
  /// In ru, this message translates to:
  /// **'Э{epoch}'**
  String selfEpochShort(String epoch);

  /// No description provided for @selfEpochTierShort.
  ///
  /// In ru, this message translates to:
  /// **'Э{epoch}.{tier}'**
  String selfEpochTierShort(String epoch, String tier);

  /// No description provided for @selfLevelLabel.
  ///
  /// In ru, this message translates to:
  /// **'УРОВЕНЬ'**
  String get selfLevelLabel;

  /// No description provided for @selfStreakLabel.
  ///
  /// In ru, this message translates to:
  /// **'СТРИК'**
  String get selfStreakLabel;

  /// No description provided for @selfStreakDays.
  ///
  /// In ru, this message translates to:
  /// **'{n} д.'**
  String selfStreakDays(int n);

  /// No description provided for @selfReadyTransition.
  ///
  /// In ru, this message translates to:
  /// **'Готов к переходу — тапни, чтобы открыть'**
  String get selfReadyTransition;

  /// No description provided for @selfStreakBroken.
  ///
  /// In ru, this message translates to:
  /// **'Стрик прервался. Закрой одну задачу сегодня — начнём заново.'**
  String get selfStreakBroken;

  /// No description provided for @axisEpochPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Э{n}'**
  String axisEpochPrefix(String n);

  /// No description provided for @axisState.
  ///
  /// In ru, this message translates to:
  /// **'СОСТОЯНИЕ'**
  String get axisState;

  /// No description provided for @axisCompletedByAxis.
  ///
  /// In ru, this message translates to:
  /// **'ВЫПОЛНЕНО ПО ОСИ'**
  String get axisCompletedByAxis;

  /// No description provided for @axisNoTasks.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся выполненные задачи, привязанные к этой оси.'**
  String get axisNoTasks;

  /// No description provided for @axesOnboardingFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала пройди онбординг.'**
  String get axesOnboardingFirst;

  /// No description provided for @axesYes.
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get axesYes;

  /// No description provided for @axesAxis.
  ///
  /// In ru, this message translates to:
  /// **'Ось'**
  String get axesAxis;

  /// No description provided for @axesDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get axesDone;

  /// No description provided for @dashNoActiveTasks.
  ///
  /// In ru, this message translates to:
  /// **'Активных задач нет — отдохни или создай новую.'**
  String get dashNoActiveTasks;

  /// No description provided for @dashDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get dashDone;

  /// No description provided for @dashPostpone.
  ///
  /// In ru, this message translates to:
  /// **'Отложить'**
  String get dashPostpone;

  /// No description provided for @dashFocusTimer.
  ///
  /// In ru, this message translates to:
  /// **'Запустить таймер фокуса'**
  String get dashFocusTimer;

  /// No description provided for @dashPostponeBy.
  ///
  /// In ru, this message translates to:
  /// **'ОТЛОЖИТЬ НА'**
  String get dashPostponeBy;

  /// No description provided for @dashViewPentagram.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть свою пентаграмму'**
  String get dashViewPentagram;

  /// No description provided for @heatmapWeekdays.
  ///
  /// In ru, this message translates to:
  /// **'Пн,,Ср,,Пт,,'**
  String get heatmapWeekdays;

  /// No description provided for @heatmapMonths.
  ///
  /// In ru, this message translates to:
  /// **'янв,фев,мар,апр,май,июн,июл,авг,сен,окт,ноя,дек'**
  String get heatmapMonths;

  /// No description provided for @heatmapEmptyYear.
  ///
  /// In ru, this message translates to:
  /// **'в {year} году пока пусто'**
  String heatmapEmptyYear(int year);

  /// No description provided for @heatmapYearSummary.
  ///
  /// In ru, this message translates to:
  /// **'{total} закрыто в {year} — тапни день'**
  String heatmapYearSummary(String total, int year);

  /// No description provided for @heatmapLess.
  ///
  /// In ru, this message translates to:
  /// **'меньше'**
  String get heatmapLess;

  /// No description provided for @heatmapMore.
  ///
  /// In ru, this message translates to:
  /// **'больше'**
  String get heatmapMore;

  /// No description provided for @miniTreeEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Древо появится после первой ветви'**
  String get miniTreeEmpty;

  /// No description provided for @miniTreeXp.
  ///
  /// In ru, this message translates to:
  /// **'всего {xp} XP · тап — древо целиком'**
  String miniTreeXp(int xp);

  /// No description provided for @pulseStreakDay.
  ///
  /// In ru, this message translates to:
  /// **'{n} день'**
  String pulseStreakDay(int n);

  /// No description provided for @pulseStreakDays.
  ///
  /// In ru, this message translates to:
  /// **'{n} дня'**
  String pulseStreakDays(int n);

  /// No description provided for @pulseStreakDaysMany.
  ///
  /// In ru, this message translates to:
  /// **'{n} дней'**
  String pulseStreakDaysMany(int n);

  /// No description provided for @notesQuickHint.
  ///
  /// In ru, this message translates to:
  /// **'Быстрая заметка…'**
  String get notesQuickHint;

  /// No description provided for @notesSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get notesSearchHint;

  /// No description provided for @notesNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get notesNotFound;

  /// No description provided for @notesEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Запиши мысль одной строкой выше или открой полный редактор кнопкой «+».'**
  String get notesEmptyHint;

  /// No description provided for @notesNotFoundHint.
  ///
  /// In ru, this message translates to:
  /// **'Попробуй другой запрос.'**
  String get notesNotFoundHint;

  /// No description provided for @calMonths.
  ///
  /// In ru, this message translates to:
  /// **'Январь,Февраль,Март,Апрель,Май,Июнь,Июль,Август,Сентябрь,Октябрь,Ноябрь,Декабрь'**
  String get calMonths;

  /// No description provided for @calWeekdays.
  ///
  /// In ru, this message translates to:
  /// **'Пн,Вт,Ср,Чт,Пт,Сб,Вс'**
  String get calWeekdays;

  /// No description provided for @calToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get calToday;

  /// No description provided for @calPlanDay.
  ///
  /// In ru, this message translates to:
  /// **'Запланировать на этот день'**
  String get calPlanDay;

  /// No description provided for @calNothingRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не записано.'**
  String get calNothingRecorded;

  /// No description provided for @calMonthsShort.
  ///
  /// In ru, this message translates to:
  /// **'янв,фев,мар,мая,июн,июл,авг,сен,окт,ноя,дек'**
  String get calMonthsShort;

  /// No description provided for @calDaysShort.
  ///
  /// In ru, this message translates to:
  /// **'пн,вт,ср,чт,пт,сб,вс'**
  String get calDaysShort;

  /// No description provided for @calTodayPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get calTodayPrefix;

  /// No description provided for @calYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get calYesterday;

  /// No description provided for @calTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get calTomorrow;

  /// No description provided for @calDayEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В этот день ничего не записано.'**
  String get calDayEmpty;

  /// No description provided for @taskOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get taskOverdue;

  /// No description provided for @taskNoTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задач нет — все выполнены или не созданы.'**
  String get taskNoTasks;

  /// No description provided for @settingsSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get settingsSync;

  /// No description provided for @settingsSyncSub.
  ///
  /// In ru, this message translates to:
  /// **'Google Drive для бэкапа'**
  String get settingsSyncSub;

  /// No description provided for @settingsExportSub.
  ///
  /// In ru, this message translates to:
  /// **'JSON в буфер обмена'**
  String get settingsExportSub;

  /// No description provided for @settingsImportSub.
  ///
  /// In ru, this message translates to:
  /// **'Вставить JSON'**
  String get settingsImportSub;

  /// No description provided for @settingsAboutSub.
  ///
  /// In ru, this message translates to:
  /// **'Версия, лицензии'**
  String get settingsAboutSub;

  /// No description provided for @roadmapTitle.
  ///
  /// In ru, this message translates to:
  /// **'AI-План'**
  String get roadmapTitle;

  /// No description provided for @roadmapGenerateFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерируй первый план'**
  String get roadmapGenerateFirst;

  /// No description provided for @roadmapAxis.
  ///
  /// In ru, this message translates to:
  /// **'Ось'**
  String get roadmapAxis;

  /// No description provided for @roadmapGoal.
  ///
  /// In ru, this message translates to:
  /// **'Цель'**
  String get roadmapGoal;

  /// No description provided for @roadmapGenerate.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать'**
  String get roadmapGenerate;

  /// No description provided for @roadmapWeek1.
  ///
  /// In ru, this message translates to:
  /// **'Неделя 1'**
  String get roadmapWeek1;

  /// No description provided for @roadmapWeek2.
  ///
  /// In ru, this message translates to:
  /// **'Неделя 2'**
  String get roadmapWeek2;

  /// No description provided for @roadmapWeek3.
  ///
  /// In ru, this message translates to:
  /// **'Неделя 3'**
  String get roadmapWeek3;

  /// No description provided for @roadmapWeek4.
  ///
  /// In ru, this message translates to:
  /// **'Неделя 4'**
  String get roadmapWeek4;

  /// No description provided for @roadmapError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get roadmapError;

  /// No description provided for @homeMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get homeMore;

  /// No description provided for @onboardingActiveHours.
  ///
  /// In ru, this message translates to:
  /// **'Активные часы'**
  String get onboardingActiveHours;

  /// No description provided for @menuRecipeSteps.
  ///
  /// In ru, this message translates to:
  /// **'ШАГИ РЕЦЕПТА'**
  String get menuRecipeSteps;

  /// No description provided for @menuGenerateRecipe.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать рецепт'**
  String get menuGenerateRecipe;

  /// No description provided for @entryUntitled.
  ///
  /// In ru, this message translates to:
  /// **'Без названия'**
  String get entryUntitled;

  /// No description provided for @axisTileFocusTasks.
  ///
  /// In ru, this message translates to:
  /// **'фокусных задач'**
  String get axisTileFocusTasks;

  /// No description provided for @backendsNoKey.
  ///
  /// In ru, this message translates to:
  /// **'ключ не задан'**
  String get backendsNoKey;

  /// No description provided for @editListAddItem.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get editListAddItem;

  /// No description provided for @editListHint.
  ///
  /// In ru, this message translates to:
  /// **'Новый пункт'**
  String get editListHint;

  /// No description provided for @editListAddFirst.
  ///
  /// In ru, this message translates to:
  /// **'Добавить первую запись'**
  String get editListAddFirst;

  /// No description provided for @entryTaskDone.
  ///
  /// In ru, this message translates to:
  /// **'✓ задача'**
  String get entryTaskDone;

  /// No description provided for @entryTask.
  ///
  /// In ru, this message translates to:
  /// **'задача'**
  String get entryTask;

  /// No description provided for @backendsActive.
  ///
  /// In ru, this message translates to:
  /// **'Активный'**
  String get backendsActive;

  /// No description provided for @debugFillAxes.
  ///
  /// In ru, this message translates to:
  /// **'Заполнить все оси до 100%'**
  String get debugFillAxes;

  /// No description provided for @debugFillAxesSub.
  ///
  /// In ru, this message translates to:
  /// **'Создаёт синтетические задачи, чтобы пентагон встал на пик'**
  String get debugFillAxesSub;

  /// No description provided for @debugFillAxesDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово. Открой «Я» — оверлей должен появиться.'**
  String get debugFillAxesDone;

  /// No description provided for @debugResetAck.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить ack эпохи'**
  String get debugResetAck;

  /// No description provided for @debugResetAckSub.
  ///
  /// In ru, this message translates to:
  /// **'Обнуляет epochAckedAt — оверлей снова пустит при пике'**
  String get debugResetAckSub;

  /// No description provided for @debugResetAckDone.
  ///
  /// In ru, this message translates to:
  /// **'Ack сброшен.'**
  String get debugResetAckDone;

  /// No description provided for @debugBumpEpoch.
  ///
  /// In ru, this message translates to:
  /// **'Форсировать +1 эпоху'**
  String get debugBumpEpoch;

  /// No description provided for @debugBumpEpochDone.
  ///
  /// In ru, this message translates to:
  /// **'Эпоха увеличена.'**
  String get debugBumpEpochDone;

  /// No description provided for @debugResetEpoch.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить эпоху на 1'**
  String get debugResetEpoch;

  /// No description provided for @debugResetEpochSub.
  ///
  /// In ru, this message translates to:
  /// **'Полный откат прогрессии до Эпохи 1'**
  String get debugResetEpochSub;

  /// No description provided for @debugResetEpochDone.
  ///
  /// In ru, this message translates to:
  /// **'Сброс до Эпохи 1.'**
  String get debugResetEpochDone;

  /// No description provided for @roadmapRegenerate.
  ///
  /// In ru, this message translates to:
  /// **'Перегенерировать'**
  String get roadmapRegenerate;

  /// No description provided for @roadmapFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось'**
  String get roadmapFailed;

  /// No description provided for @roadmapGenericError.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get roadmapGenericError;

  /// No description provided for @roadmapBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get roadmapBack;

  /// No description provided for @roadmapToday.
  ///
  /// In ru, this message translates to:
  /// **'сегодня'**
  String get roadmapToday;

  /// No description provided for @roadmapTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'завтра'**
  String get roadmapTomorrow;

  /// No description provided for @roadmapInDays.
  ///
  /// In ru, this message translates to:
  /// **'через {n} дн.'**
  String roadmapInDays(int n);

  /// No description provided for @roadmapDueDate.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String roadmapDueDate(String date);

  /// No description provided for @roadmapFromOnboarding.
  ///
  /// In ru, this message translates to:
  /// **'Из онбординга'**
  String get roadmapFromOnboarding;

  /// No description provided for @pomodoroStopAction.
  ///
  /// In ru, this message translates to:
  /// **'Стоп'**
  String get pomodoroStopAction;

  /// No description provided for @pomodoroGoAction.
  ///
  /// In ru, this message translates to:
  /// **'Поехали'**
  String get pomodoroGoAction;

  /// No description provided for @onboardGoals.
  ///
  /// In ru, this message translates to:
  /// **'поправить здоровье,сменить профессию,выучить новое,стать дисциплинированнее,развить отношения,найти баланс,запустить проект'**
  String get onboardGoals;

  /// No description provided for @onboardInterests.
  ///
  /// In ru, this message translates to:
  /// **'учёба,код,дизайн,спорт,медитация,чтение,музыка,языки,кулинария,отношения,финансы,творчество,карьера,семья'**
  String get onboardInterests;

  /// No description provided for @onboardTimePrefix.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get onboardTimePrefix;

  /// No description provided for @onboardPainPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Что мешает'**
  String get onboardPainPrefix;

  /// No description provided for @onboardComfortTime.
  ///
  /// In ru, this message translates to:
  /// **'Удобное время'**
  String get onboardComfortTime;

  /// No description provided for @onboardNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get onboardNameHint;

  /// No description provided for @onboardCustomValue.
  ///
  /// In ru, this message translates to:
  /// **'Своё значение'**
  String get onboardCustomValue;

  /// No description provided for @onboardVolumeMini.
  ///
  /// In ru, this message translates to:
  /// **'мини-объём, по чуть-чуть'**
  String get onboardVolumeMini;

  /// No description provided for @onboardVolumeComfort.
  ///
  /// In ru, this message translates to:
  /// **'комфортный темп'**
  String get onboardVolumeComfort;

  /// No description provided for @onboardVolumeSerious.
  ///
  /// In ru, this message translates to:
  /// **'серьёзная вовлечённость'**
  String get onboardVolumeSerious;

  /// No description provided for @onboardVolumeAlmost.
  ///
  /// In ru, this message translates to:
  /// **'почти второй джоб'**
  String get onboardVolumeAlmost;

  /// No description provided for @onboardVolumeMax.
  ///
  /// In ru, this message translates to:
  /// **'максимальный режим'**
  String get onboardVolumeMax;

  /// No description provided for @onboardPainSummary.
  ///
  /// In ru, this message translates to:
  /// **'Что мешает: {pain}.'**
  String onboardPainSummary(String pain);

  /// No description provided for @onboardTimeSummary.
  ///
  /// In ru, this message translates to:
  /// **'Удобное время: {time}.'**
  String onboardTimeSummary(String time);

  /// No description provided for @pulseDeadlineLabel.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайн'**
  String get pulseDeadlineLabel;

  /// No description provided for @pluralTaskOne.
  ///
  /// In ru, this message translates to:
  /// **'задача'**
  String get pluralTaskOne;

  /// No description provided for @pluralTaskFew.
  ///
  /// In ru, this message translates to:
  /// **'задачи'**
  String get pluralTaskFew;

  /// No description provided for @pluralTaskMany.
  ///
  /// In ru, this message translates to:
  /// **'задач'**
  String get pluralTaskMany;

  /// No description provided for @pluralDeadlineOne.
  ///
  /// In ru, this message translates to:
  /// **'дедлайн'**
  String get pluralDeadlineOne;

  /// No description provided for @pluralDeadlineFew.
  ///
  /// In ru, this message translates to:
  /// **'дедлайна'**
  String get pluralDeadlineFew;

  /// No description provided for @pluralDeadlineMany.
  ///
  /// In ru, this message translates to:
  /// **'дедлайнов'**
  String get pluralDeadlineMany;

  /// No description provided for @pluralNoteOne.
  ///
  /// In ru, this message translates to:
  /// **'заметка'**
  String get pluralNoteOne;

  /// No description provided for @pluralNoteFew.
  ///
  /// In ru, this message translates to:
  /// **'заметки'**
  String get pluralNoteFew;

  /// No description provided for @pluralNoteMany.
  ///
  /// In ru, this message translates to:
  /// **'заметок'**
  String get pluralNoteMany;

  /// No description provided for @pluralBranchOne.
  ///
  /// In ru, this message translates to:
  /// **'ветвь'**
  String get pluralBranchOne;

  /// No description provided for @pluralBranchFew.
  ///
  /// In ru, this message translates to:
  /// **'ветви'**
  String get pluralBranchFew;

  /// No description provided for @pluralBranchMany.
  ///
  /// In ru, this message translates to:
  /// **'ветвей'**
  String get pluralBranchMany;

  /// No description provided for @heatmapNothing.
  ///
  /// In ru, this message translates to:
  /// **'ничего'**
  String get heatmapNothing;

  /// No description provided for @miniTreeBest.
  ///
  /// In ru, this message translates to:
  /// **'лучшая: {symbol} {name} · L{level}'**
  String miniTreeBest(String symbol, String name, int level);

  /// No description provided for @timeJustNow.
  ///
  /// In ru, this message translates to:
  /// **'только что'**
  String get timeJustNow;

  /// No description provided for @timeNow.
  ///
  /// In ru, this message translates to:
  /// **'сейчас'**
  String get timeNow;

  /// No description provided for @timeAgoFmt.
  ///
  /// In ru, this message translates to:
  /// **'{value} {unit} назад'**
  String timeAgoFmt(int value, String unit);

  /// No description provided for @timeInFmt.
  ///
  /// In ru, this message translates to:
  /// **'через {value} {unit}'**
  String timeInFmt(int value, String unit);

  /// No description provided for @timeRightAfter.
  ///
  /// In ru, this message translates to:
  /// **'сразу после'**
  String get timeRightAfter;

  /// No description provided for @timePlusFmt.
  ///
  /// In ru, this message translates to:
  /// **'+ {value} {unit}'**
  String timePlusFmt(int value, String unit);

  /// No description provided for @pluralDayOne.
  ///
  /// In ru, this message translates to:
  /// **'день'**
  String get pluralDayOne;

  /// No description provided for @pluralDayFew.
  ///
  /// In ru, this message translates to:
  /// **'дня'**
  String get pluralDayFew;

  /// No description provided for @pluralDayMany.
  ///
  /// In ru, this message translates to:
  /// **'дней'**
  String get pluralDayMany;

  /// No description provided for @pluralHourOne.
  ///
  /// In ru, this message translates to:
  /// **'час'**
  String get pluralHourOne;

  /// No description provided for @pluralHourFew.
  ///
  /// In ru, this message translates to:
  /// **'часа'**
  String get pluralHourFew;

  /// No description provided for @pluralHourMany.
  ///
  /// In ru, this message translates to:
  /// **'часов'**
  String get pluralHourMany;

  /// No description provided for @pluralMinuteOne.
  ///
  /// In ru, this message translates to:
  /// **'минута'**
  String get pluralMinuteOne;

  /// No description provided for @pluralMinuteFew.
  ///
  /// In ru, this message translates to:
  /// **'минуты'**
  String get pluralMinuteFew;

  /// No description provided for @pluralMinuteMany.
  ///
  /// In ru, this message translates to:
  /// **'минут'**
  String get pluralMinuteMany;

  /// No description provided for @pluralMonthOne.
  ///
  /// In ru, this message translates to:
  /// **'месяц'**
  String get pluralMonthOne;

  /// No description provided for @pluralMonthFew.
  ///
  /// In ru, this message translates to:
  /// **'месяца'**
  String get pluralMonthFew;

  /// No description provided for @pluralMonthMany.
  ///
  /// In ru, this message translates to:
  /// **'месяцев'**
  String get pluralMonthMany;

  /// No description provided for @pluralYearOne.
  ///
  /// In ru, this message translates to:
  /// **'год'**
  String get pluralYearOne;

  /// No description provided for @pluralYearFew.
  ///
  /// In ru, this message translates to:
  /// **'года'**
  String get pluralYearFew;

  /// No description provided for @pluralYearMany.
  ///
  /// In ru, this message translates to:
  /// **'лет'**
  String get pluralYearMany;

  /// No description provided for @pomodoroFocus.
  ///
  /// In ru, this message translates to:
  /// **'Фокус'**
  String get pomodoroFocus;

  /// No description provided for @pomodoroBreak.
  ///
  /// In ru, this message translates to:
  /// **'Короткий отдых'**
  String get pomodoroBreak;

  /// No description provided for @pomodoroLongBreakHint.
  ///
  /// In ru, this message translates to:
  /// **'Длинный отдых {min} мин'**
  String pomodoroLongBreakHint(int min);

  /// No description provided for @pomodoroShortBreakHint.
  ///
  /// In ru, this message translates to:
  /// **'Короткий отдых {min} мин'**
  String pomodoroShortBreakHint(int min);

  /// No description provided for @pomodoroNextFocusAuto.
  ///
  /// In ru, this message translates to:
  /// **'Поехали — следующий фокус {min} мин'**
  String pomodoroNextFocusAuto(int min);

  /// No description provided for @pomodoroNextFocusManual.
  ///
  /// In ru, this message translates to:
  /// **'Запусти следующий фокус когда готов'**
  String get pomodoroNextFocusManual;

  /// No description provided for @pomodoroTimeToRest.
  ///
  /// In ru, this message translates to:
  /// **'Время передохнуть'**
  String get pomodoroTimeToRest;

  /// No description provided for @pomodoroBackToFocus.
  ///
  /// In ru, this message translates to:
  /// **'Возвращаемся к фокусу'**
  String get pomodoroBackToFocus;

  /// No description provided for @pomodoroReadyAgain.
  ///
  /// In ru, this message translates to:
  /// **'Готов снова работать?'**
  String get pomodoroReadyAgain;

  /// No description provided for @notifChannelName.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайны и напоминания'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания о приближающихся и просроченных задачах.'**
  String get notifChannelDesc;

  /// No description provided for @notifWindowsHint.
  ///
  /// In ru, this message translates to:
  /// **'Тосты Windows + иконка в трее. Чтобы напоминания приходили, не закрывай приложение полностью — сворачивай в трей (крестик это и делает).'**
  String get notifWindowsHint;

  /// No description provided for @notifUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Эта платформа не поддерживается.'**
  String get notifUnsupported;

  /// No description provided for @notifMorningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Утренний план'**
  String get notifMorningTitle;

  /// No description provided for @notifMorningBody.
  ///
  /// In ru, this message translates to:
  /// **'Загляни в AI-коуч — спланируй свой день'**
  String get notifMorningBody;

  /// No description provided for @notifEveningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вечерний разбор'**
  String get notifEveningTitle;

  /// No description provided for @notifEveningBody.
  ///
  /// In ru, this message translates to:
  /// **'Подведём итоги дня — что получилось, что улучшить?'**
  String get notifEveningBody;

  /// No description provided for @notifDeadlineTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра дедлайн'**
  String get notifDeadlineTomorrow;

  /// No description provided for @notifDeadlineToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня дедлайн'**
  String get notifDeadlineToday;

  /// No description provided for @notifDeadlinePassed.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайн прошёл'**
  String get notifDeadlinePassed;

  /// No description provided for @notifWeeklyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Время недельной рефлексии'**
  String get notifWeeklyTitle;

  /// No description provided for @notifWeeklyBody.
  ///
  /// In ru, this message translates to:
  /// **'Заглянем как прошла неделя?'**
  String get notifWeeklyBody;

  /// No description provided for @trayOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть Noetica'**
  String get trayOpen;

  /// No description provided for @trayExit.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get trayExit;

  /// No description provided for @genMenuGoal.
  ///
  /// In ru, this message translates to:
  /// **'Цель питания'**
  String get genMenuGoal;

  /// No description provided for @genMenuClassic.
  ///
  /// In ru, this message translates to:
  /// **'Сбалансированно'**
  String get genMenuClassic;

  /// No description provided for @genMenuLoseWeight.
  ///
  /// In ru, this message translates to:
  /// **'Похудение'**
  String get genMenuLoseWeight;

  /// No description provided for @genMenuHealth.
  ///
  /// In ru, this message translates to:
  /// **'Здоровье'**
  String get genMenuHealth;

  /// No description provided for @genMenuMuscle.
  ///
  /// In ru, this message translates to:
  /// **'Набор мышц'**
  String get genMenuMuscle;

  /// No description provided for @genMenuEnergy.
  ///
  /// In ru, this message translates to:
  /// **'Энергия / спорт'**
  String get genMenuEnergy;

  /// No description provided for @genMenuServings.
  ///
  /// In ru, this message translates to:
  /// **'Порций'**
  String get genMenuServings;

  /// No description provided for @genMenuStart.
  ///
  /// In ru, this message translates to:
  /// **'Старт меню'**
  String get genMenuStart;

  /// No description provided for @genMenuAxis.
  ///
  /// In ru, this message translates to:
  /// **'Ось роста'**
  String get genMenuAxis;

  /// No description provided for @genMenuAxisHelp.
  ///
  /// In ru, this message translates to:
  /// **'21 задача добавится к выбранной оси и будет давать XP при отметке «выполнено».'**
  String get genMenuAxisHelp;

  /// No description provided for @genMenuRestrictions.
  ///
  /// In ru, this message translates to:
  /// **'Ограничения (опционально)'**
  String get genMenuRestrictions;

  /// No description provided for @genMenuRestrictionsHint.
  ///
  /// In ru, this message translates to:
  /// **'без глютена; без свинины; вегетарианец'**
  String get genMenuRestrictionsHint;

  /// No description provided for @genMenuNotes.
  ///
  /// In ru, this message translates to:
  /// **'Доп. пожелания (опционально)'**
  String get genMenuNotes;

  /// No description provided for @genMenuNotesHint.
  ///
  /// In ru, this message translates to:
  /// **'минимум готовки в будни; больше рыбы; быстрые завтраки'**
  String get genMenuNotesHint;

  /// No description provided for @genHabitIntent.
  ///
  /// In ru, this message translates to:
  /// **'Какую привычку хочешь освоить?'**
  String get genHabitIntent;

  /// No description provided for @genHabitIntentHint.
  ///
  /// In ru, this message translates to:
  /// **'хочу засыпать раньше · перестать залипать в телефон утром · пить больше воды'**
  String get genHabitIntentHint;

  /// No description provided for @genHabitDays.
  ///
  /// In ru, this message translates to:
  /// **'Сколько дней'**
  String get genHabitDays;

  /// No description provided for @genHabitAxis.
  ///
  /// In ru, this message translates to:
  /// **'Ось роста'**
  String get genHabitAxis;

  /// No description provided for @genHabitAxisHelp.
  ///
  /// In ru, this message translates to:
  /// **'Все мини-задачи получат XP от выполнения и будут расти вместе с этой осью.'**
  String get genHabitAxisHelp;

  /// No description provided for @genHabitNotes.
  ///
  /// In ru, this message translates to:
  /// **'Доп. пожелания (опционально)'**
  String get genHabitNotes;

  /// No description provided for @genHabitNotesHint.
  ///
  /// In ru, this message translates to:
  /// **'буду делать утром · уже пробовал, не получалось · хочу без приложений'**
  String get genHabitNotesHint;

  /// No description provided for @genMenuTitle.
  ///
  /// In ru, this message translates to:
  /// **'Меню недели'**
  String get genMenuTitle;

  /// No description provided for @genMenuDesc.
  ///
  /// In ru, this message translates to:
  /// **'7 дней × завтрак / обед / ужин с КБЖУ под твою цель питания.'**
  String get genMenuDesc;

  /// No description provided for @genMenuBullet1.
  ///
  /// In ru, this message translates to:
  /// **'21 задача на оси «Тело» с дедлайнами'**
  String get genMenuBullet1;

  /// No description provided for @genMenuBullet2.
  ///
  /// In ru, this message translates to:
  /// **'Список покупок отдельной заметкой-чеклистом'**
  String get genMenuBullet2;

  /// No description provided for @genMenuBullet3.
  ///
  /// In ru, this message translates to:
  /// **'Полные рецепты подгружаются по тапу'**
  String get genMenuBullet3;

  /// No description provided for @genTrainingTitle.
  ///
  /// In ru, this message translates to:
  /// **'План тренировок'**
  String get genTrainingTitle;

  /// No description provided for @genTrainingDesc.
  ///
  /// In ru, this message translates to:
  /// **'Программа на 4 недели под цель: сила, выносливость, рекомпозиция.'**
  String get genTrainingDesc;

  /// No description provided for @genTrainingBullet1.
  ///
  /// In ru, this message translates to:
  /// **'Учитывает доступное оборудование'**
  String get genTrainingBullet1;

  /// No description provided for @genTrainingBullet2.
  ///
  /// In ru, this message translates to:
  /// **'Каждое занятие — задача с подходами в подзадачах'**
  String get genTrainingBullet2;

  /// No description provided for @genStudyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Учебный план'**
  String get genStudyTitle;

  /// No description provided for @genStudyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Декомпозиция «выучить X» на занятия с заметками-конспектами.'**
  String get genStudyDesc;

  /// No description provided for @genStudyBullet1.
  ///
  /// In ru, this message translates to:
  /// **'Уроки = задачи на оси «Разум»'**
  String get genStudyBullet1;

  /// No description provided for @genStudyBullet2.
  ///
  /// In ru, this message translates to:
  /// **'Конспекты — заметки, связанные [[wiki-ссылками]]'**
  String get genStudyBullet2;

  /// No description provided for @genHabitsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Микро-привычки'**
  String get genHabitsTitle;

  /// No description provided for @genHabitsDesc.
  ///
  /// In ru, this message translates to:
  /// **'7-дневный челлендж из коротких ежедневных задач.'**
  String get genHabitsDesc;

  /// No description provided for @genHabitsBullet1.
  ///
  /// In ru, this message translates to:
  /// **'Каждое действие ≤ 2 минут — реально доходишь'**
  String get genHabitsBullet1;

  /// No description provided for @genHabitsBullet2.
  ///
  /// In ru, this message translates to:
  /// **'Подбираем под выбранную ось, идут по нарастающей'**
  String get genHabitsBullet2;

  /// No description provided for @genHabitsBullet3.
  ///
  /// In ru, this message translates to:
  /// **'Появятся в Задачах с дедлайнами по дням'**
  String get genHabitsBullet3;

  /// No description provided for @reflectionBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Не пошло'**
  String get reflectionBlocked;

  /// No description provided for @menuGoalLoseWeight.
  ///
  /// In ru, this message translates to:
  /// **'Похудение'**
  String get menuGoalLoseWeight;

  /// No description provided for @menuGoalHealth.
  ///
  /// In ru, this message translates to:
  /// **'Здоровье'**
  String get menuGoalHealth;

  /// No description provided for @menuGoalMuscle.
  ///
  /// In ru, this message translates to:
  /// **'Набор мышц'**
  String get menuGoalMuscle;

  /// No description provided for @menuGoalEnergy.
  ///
  /// In ru, this message translates to:
  /// **'Энергия / спорт'**
  String get menuGoalEnergy;

  /// No description provided for @menuGoalClassic.
  ///
  /// In ru, this message translates to:
  /// **'Классическое сбалансированное'**
  String get menuGoalClassic;

  /// No description provided for @apiErrNotLoggedIn.
  ///
  /// In ru, this message translates to:
  /// **'Не выполнен вход в Google. Перезайдите и попробуйте снова.'**
  String get apiErrNotLoggedIn;

  /// No description provided for @apiErrServerUnreachable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось связаться с сервером: {details}'**
  String apiErrServerUnreachable(String details);

  /// No description provided for @apiErrSessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Зайдите через Google ещё раз.'**
  String get apiErrSessionExpired;

  /// No description provided for @apiErrInvalidJson.
  ///
  /// In ru, this message translates to:
  /// **'Сервер вернул некорректный JSON: {details}'**
  String apiErrInvalidJson(String details);

  /// No description provided for @validationRequired.
  ///
  /// In ru, this message translates to:
  /// **'Поле обязательно'**
  String get validationRequired;

  /// No description provided for @validationRange.
  ///
  /// In ru, this message translates to:
  /// **'Должно быть от {min} до {max}'**
  String validationRange(int min, int max);

  /// No description provided for @backendDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get backendDefault;

  /// No description provided for @backendCantDeleteLast.
  ///
  /// In ru, this message translates to:
  /// **'Нельзя удалить единственный бэкенд. Сначала добавь другой.'**
  String get backendCantDeleteLast;

  /// No description provided for @menuRecipePrefix.
  ///
  /// In ru, this message translates to:
  /// **'Рецепт: {name}'**
  String menuRecipePrefix(String name);

  /// No description provided for @menuRecipeNotGenerated.
  ///
  /// In ru, this message translates to:
  /// **'Рецепт ещё не сгенерирован'**
  String get menuRecipeNotGenerated;

  /// No description provided for @menuSummary.
  ///
  /// In ru, this message translates to:
  /// **'{goal} · {servings} порций · {range}'**
  String menuSummary(String goal, int servings, String range);

  /// No description provided for @androidChannelName.
  ///
  /// In ru, this message translates to:
  /// **'Дедлайны и напоминания'**
  String get androidChannelName;

  /// No description provided for @androidChannelDesc.
  ///
  /// In ru, this message translates to:
  /// **'Напоминания о приближающихся и просроченных задачах.'**
  String get androidChannelDesc;

  /// No description provided for @interestSport.
  ///
  /// In ru, this message translates to:
  /// **'Спорт'**
  String get interestSport;

  /// No description provided for @interestReading.
  ///
  /// In ru, this message translates to:
  /// **'Чтение'**
  String get interestReading;

  /// No description provided for @interestLanguages.
  ///
  /// In ru, this message translates to:
  /// **'Изучение языков'**
  String get interestLanguages;

  /// No description provided for @interestProgramming.
  ///
  /// In ru, this message translates to:
  /// **'Программирование'**
  String get interestProgramming;

  /// No description provided for @interestMusic.
  ///
  /// In ru, this message translates to:
  /// **'Музыка'**
  String get interestMusic;

  /// No description provided for @interestDrawing.
  ///
  /// In ru, this message translates to:
  /// **'Рисование'**
  String get interestDrawing;

  /// No description provided for @interestMeditation.
  ///
  /// In ru, this message translates to:
  /// **'Медитация'**
  String get interestMeditation;

  /// No description provided for @interestFriendship.
  ///
  /// In ru, this message translates to:
  /// **'Дружба'**
  String get interestFriendship;

  /// No description provided for @interestFamily.
  ///
  /// In ru, this message translates to:
  /// **'Семья'**
  String get interestFamily;

  /// No description provided for @interestFinance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get interestFinance;

  /// No description provided for @interestCareer.
  ///
  /// In ru, this message translates to:
  /// **'Карьера'**
  String get interestCareer;

  /// No description provided for @interestBusiness.
  ///
  /// In ru, this message translates to:
  /// **'Предпринимательство'**
  String get interestBusiness;

  /// No description provided for @interestNutrition.
  ///
  /// In ru, this message translates to:
  /// **'Питание'**
  String get interestNutrition;

  /// No description provided for @interestSleep.
  ///
  /// In ru, this message translates to:
  /// **'Сон'**
  String get interestSleep;

  /// No description provided for @interestTravel.
  ///
  /// In ru, this message translates to:
  /// **'Путешествия'**
  String get interestTravel;

  /// No description provided for @interestWriting.
  ///
  /// In ru, this message translates to:
  /// **'Письмо'**
  String get interestWriting;

  /// No description provided for @interestCrafts.
  ///
  /// In ru, this message translates to:
  /// **'Ремесла'**
  String get interestCrafts;

  /// No description provided for @skillNovice.
  ///
  /// In ru, this message translates to:
  /// **'Новичок'**
  String get skillNovice;

  /// No description provided for @skillLearning.
  ///
  /// In ru, this message translates to:
  /// **'Учусь'**
  String get skillLearning;

  /// No description provided for @skillConfident.
  ///
  /// In ru, this message translates to:
  /// **'Уверенно'**
  String get skillConfident;

  /// No description provided for @skillExpert.
  ///
  /// In ru, this message translates to:
  /// **'Эксперт'**
  String get skillExpert;

  /// No description provided for @onboardAxisBody.
  ///
  /// In ru, this message translates to:
  /// **'Тело'**
  String get onboardAxisBody;

  /// No description provided for @onboardAxisMind.
  ///
  /// In ru, this message translates to:
  /// **'Ум'**
  String get onboardAxisMind;

  /// No description provided for @onboardAxisWork.
  ///
  /// In ru, this message translates to:
  /// **'Дело'**
  String get onboardAxisWork;

  /// No description provided for @onboardAxisRelations.
  ///
  /// In ru, this message translates to:
  /// **'Связи'**
  String get onboardAxisRelations;

  /// No description provided for @onboardAxisSoul.
  ///
  /// In ru, this message translates to:
  /// **'Душа'**
  String get onboardAxisSoul;

  /// No description provided for @menuMacroLine.
  ///
  /// In ru, this message translates to:
  /// **'{cal} ккал · {p}б/{f}ж/{c}у'**
  String menuMacroLine(int cal, int p, int f, int c);

  /// No description provided for @backendUrlEmpty.
  ///
  /// In ru, this message translates to:
  /// **'URL не должен быть пустым.'**
  String get backendUrlEmpty;
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
