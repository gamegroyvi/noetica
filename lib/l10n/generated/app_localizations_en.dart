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
  String get navCoach => 'AI Coach';

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
  String get sectionTree => 'TREE';

  @override
  String get sectionRecentlyClosed => 'RECENTLY CLOSED';

  @override
  String get linkCalendar => 'calendar →';

  @override
  String get linkAll => 'all →';

  @override
  String get linkTasks => 'tasks →';

  @override
  String get freeDay => 'free day';

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

  @override
  String get sortSmart => 'Smart';

  @override
  String get sortDueAsc => 'Due ↑';

  @override
  String get sortCreatedDesc => 'Recent';

  @override
  String get sortXpDesc => 'Heaviest first';

  @override
  String get tooltipSort => 'Sort';

  @override
  String get tooltipSettings => 'Settings';

  @override
  String get noDate => 'No date';

  @override
  String get allAxes => 'All axes';

  @override
  String get noAxis => 'No axis';

  @override
  String get expandPlans => 'Expand plans';

  @override
  String get collapsePlans => 'Collapse plans';

  @override
  String get weeklyMenu => 'Weekly menu';

  @override
  String tasksInPlan(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tasks',
      one: 'task',
    );
    return '$count $_temp0 in plan';
  }

  @override
  String plansCount(int count) {
    return 'Plans ($count)';
  }

  @override
  String get emptyFilterTitle => 'Nothing matches the filter';

  @override
  String get emptyFilterHint => 'Reset filters or change sort order to see other tasks.';

  @override
  String get emptyTasksTitle => 'No tasks';

  @override
  String get emptyTasksHint => 'Create a task via \"+\". Link it to axes — completion earns points on the pentagon.';

  @override
  String get sectionAccount => 'Account';

  @override
  String get sectionProfile => 'Profile';

  @override
  String get sectionAxes => 'Growth axes';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get sectionBackend => 'Backend';

  @override
  String get sectionData => 'Data';

  @override
  String get sectionAbout => 'About';

  @override
  String get sectionDeveloper => '⚙ Developer';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsSyncHint => 'Pull data from cloud and push local changes';

  @override
  String get settingsNotLoggedIn => 'Not logged in';

  @override
  String get settingsNotLoggedInHint => 'Restart the app to log in.';

  @override
  String get settingsNoName => 'No name';

  @override
  String get settingsNoGoal => 'No goal set';

  @override
  String get settingsRegenAxes => 'Regenerate axes';

  @override
  String get settingsRegenAxesNoInterests => 'Add interests in profile so AI can generate axes';

  @override
  String settingsRegenAxesHint(int count) {
    return 'AI will rebuild axes from $count interests';
  }

  @override
  String get settingsNotificationsUnsupported => 'Notifications not supported here';

  @override
  String get settingsLocalNotifications => 'Local notifications';

  @override
  String get settingsLocalNotificationsHint => '1 day before, morning, and 1 hour after deadline';

  @override
  String get settingsMorningReminder => 'Morning reminder';

  @override
  String get settingsCoachReminders => 'AI coach reminders';

  @override
  String get settingsCoachRemindersHint => 'Morning plan and evening review';

  @override
  String get settingsEveningReview => 'Evening review';

  @override
  String get settingsExportJson => 'Export to JSON';

  @override
  String get settingsExportJsonHint => 'Save profile, axes and entries to file';

  @override
  String get settingsImportJson => 'Import from JSON';

  @override
  String get settingsImportJsonHint => 'Restore data from clipboard';

  @override
  String get settingsEraseAll => 'Erase all data';

  @override
  String get settingsEraseAllHint => 'Return to onboarding screen';

  @override
  String get settingsSourceCode => 'Source code';

  @override
  String get settingsVersion => 'v0.1.0 — minimalist growth tracker';

  @override
  String get dialogImportTitle => 'Import data';

  @override
  String get dialogImportBody => 'Paste export JSON from clipboard. Existing data will be merged (entry ID used for deduplication).';

  @override
  String get dialogPasteClipboard => 'Paste from clipboard';

  @override
  String get dialogEraseTitle => 'Erase all data?';

  @override
  String get dialogEraseBody => 'Profile, axes, tasks, notes and settings will be deleted. This action is irreversible.';

  @override
  String get dialogErase => 'Erase';

  @override
  String get dialogLogoutTitle => 'Log out?';

  @override
  String get dialogLogoutBody => 'Local data will remain on device. To sync again, log in with the same Google account.';

  @override
  String snackExportSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get snackCopy => 'Copy';

  @override
  String snackExportError(String error) {
    return 'Export failed: $error';
  }

  @override
  String get snackClipboardEmpty => 'Clipboard is empty.';

  @override
  String snackImportSuccess(int count) {
    return 'Imported $count entries.';
  }

  @override
  String snackImportError(String error) {
    return 'Import failed: $error';
  }

  @override
  String snackEraseError(String error) {
    return 'Erase failed: $error';
  }

  @override
  String get snackSyncing => 'Syncing…';

  @override
  String get snackSyncDone => 'Done. Data pulled from cloud.';

  @override
  String snackSyncError(String error) {
    return 'Failed: $error';
  }

  @override
  String snackLogoutError(String error) {
    return 'Logout failed: $error';
  }

  @override
  String get loadingBackends => 'Loading…';

  @override
  String get loadingBackendsHint => 'Loading backend list…';

  @override
  String get reflectionDidNotGo => 'Didn\'t work';

  @override
  String get reflectionDifficult => 'Hard';

  @override
  String get reflectionOk => 'OK';

  @override
  String get reflectionEasyShort => 'Easy';

  @override
  String get entryKindTask => 'Task';

  @override
  String get entryKindNote => 'Note';

  @override
  String get entryKindHabit => 'Habit';
}
