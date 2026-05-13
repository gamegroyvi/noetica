import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NOETICA';

  @override
  String get tabDashboard => 'Now';

  @override
  String get tabSelf => 'Self';

  @override
  String get tabTasks => 'Tasks';

  @override
  String get tabMore => 'More';

  @override
  String get navJournal => 'Journal';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navKnowledge => 'Graph';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navSettings => 'Settings';

  @override
  String get navPomodoro => 'Pomodoro';

  @override
  String get navRoadmap => 'AI-Plan';

  @override
  String get sectionNow => 'NOW';

  @override
  String get sectionToday => 'TODAY';

  @override
  String get sectionPulse => 'PULSE';

  @override
  String get sectionRecent => 'RECENT';

  @override
  String get sectionOverdue => 'OVERDUE';

  @override
  String get sectionTomorrow => 'TOMORROW';

  @override
  String get sectionThisWeek => 'THIS WEEK';

  @override
  String get sectionLater => 'LATER';

  @override
  String get sectionDone => 'DONE';

  @override
  String get sectionHeatmap => 'ACTIVITY';

  @override
  String get filterAll => 'All';

  @override
  String get filterOpen => 'Open';

  @override
  String get filterOverdue => 'Overdue';

  @override
  String get filterDone => 'Done';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionDone => 'Done';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionExport => 'Export';

  @override
  String get actionImport => 'Import';

  @override
  String get taskNew => 'New entry';

  @override
  String get taskComplete => 'Done';

  @override
  String get taskSubtasks => 'Subtasks';

  @override
  String get taskDueDate => 'Due date';

  @override
  String get taskXp => 'XP';

  @override
  String get editorTitle => 'Title';

  @override
  String get editorBody => 'Body';

  @override
  String get editorTags => 'Tags';

  @override
  String get editorAddTag => 'add tag…';

  @override
  String get editorAxes => 'Axes';

  @override
  String get editorBacklinks => 'Backlinks';

  @override
  String get editorSubtasks => 'Subtasks';

  @override
  String get selfBranches => 'Branches';

  @override
  String get selfSettings => 'Settings';

  @override
  String get selfEpoch => 'Epoch';

  @override
  String get selfLevel => 'Level';

  @override
  String get selfStreak => 'Streak';

  @override
  String get selfNewEpoch => 'New epoch';

  @override
  String get selfDeepen => 'Deepen';

  @override
  String get axisBody => 'Body';

  @override
  String get axisMind => 'Mind';

  @override
  String get axisWork => 'Work';

  @override
  String get axisSocial => 'Social';

  @override
  String get axisSoul => 'Soul';

  @override
  String get onboardingName => 'What\'s your name?';

  @override
  String get onboardingGoals => 'What are your goals?';

  @override
  String get onboardingInterests => 'What interests you?';

  @override
  String get onboardingHours => 'Hours per week?';

  @override
  String get onboardingContinue => 'Next';

  @override
  String get onboardingFinish => 'Start';

  @override
  String get pomodoroTitle => 'Pomodoro';

  @override
  String get pomodoroStart => 'Start';

  @override
  String get pomodoroPause => 'Pause';

  @override
  String get pomodoroReset => 'Reset';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsExport => 'Export data';

  @override
  String get settingsImport => 'Import data';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsLightMode => 'Light mode';

  @override
  String get knowledgeEmpty => 'Knowledge base is empty';

  @override
  String get knowledgeEmptyHint => 'Create your first note or task — they will appear here as graph nodes.';

  @override
  String get knowledgeCreateEntry => 'Create entry';

  @override
  String get knowledgeGoals => 'Goals';

  @override
  String get knowledgeConstraints => 'Constraints';

  @override
  String get knowledgeHighlights => 'Highlights';

  @override
  String get knowledgeReflections => 'Reflections';

  @override
  String get knowledgePreferences => 'Preferences';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get notesTitle => 'Journal';

  @override
  String get deleteConfirm => 'Entry deleted';

  @override
  String get deleteUndone => 'Restored';

  @override
  String get emptyTasks => 'No tasks yet';

  @override
  String get emptyNotes => 'No notes yet';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingDay => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get reflectionHow => 'How did it go?';

  @override
  String get reflectionEasy => 'Easy';

  @override
  String get reflectionNormal => 'Normal';

  @override
  String get reflectionHard => 'Hard';

  @override
  String get reflectionSkip => 'Skip';

  @override
  String get weeklyReflection => 'Weekly reflection';

  @override
  String daysTotalStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: '0 days',
    );
    return '$_temp0';
  }
}
