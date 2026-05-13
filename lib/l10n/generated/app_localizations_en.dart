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
  String selfEpoch(int n) {
    return 'Epoch $n';
  }

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

  @override
  String editorSaveError(String error) {
    return 'Failed to save entry: $error';
  }

  @override
  String editorDeletedMsg(String title) {
    return '«$title» deleted';
  }

  @override
  String get editorHintTask => 'What needs to be done?';

  @override
  String get editorNewEntry => 'New entry';

  @override
  String get editorEntry => 'Entry';

  @override
  String get editorExpand => 'Expand';

  @override
  String get editorClose => 'Close';

  @override
  String get editorParams => 'Parameters';

  @override
  String get editorMakeTask => 'Make a task';

  @override
  String get editorTaskModeHint => 'Deadline and XP on completion';

  @override
  String get editorNoteModeHint => 'Default — note';

  @override
  String get editorNoDeadline => 'No deadline';

  @override
  String get editorXpOnComplete => 'XP on completion';

  @override
  String get editorAddAxesHint => 'Add axes in onboarding first.';

  @override
  String get editorUntitled => '(untitled)';

  @override
  String editorBacklinksCount(int count) {
    return 'Backlinks ($count)';
  }

  @override
  String editorSubtasksProgress(int done, int total) {
    return 'Subtasks — $done/$total';
  }

  @override
  String get editorBodyHint => 'What\'s on your mind?\nFormatting: bold, italic, headings, checklists, [[note links]].';

  @override
  String get editorToolH1 => 'Heading 1';

  @override
  String get editorToolH2 => 'Heading 2';

  @override
  String get editorToolH3 => 'Heading 3';

  @override
  String get editorToolBold => 'Bold';

  @override
  String get editorToolItalic => 'Italic';

  @override
  String get editorToolStrike => 'Strikethrough';

  @override
  String get editorToolCode => 'Code';

  @override
  String get editorToolBullet => 'Bulleted list';

  @override
  String get editorToolNumber => 'Numbered list';

  @override
  String get editorToolCheckbox => 'Checklist';

  @override
  String get editorToolQuote => 'Quote';

  @override
  String get editorToolLink => 'Link';

  @override
  String get editorToolWikiLink => 'Note link';

  @override
  String get editorToolTag => 'Tag';

  @override
  String get editorWikiLinkTitle => 'Note link';

  @override
  String get editorWikiLinkHint => 'Start typing a name…';

  @override
  String editorCreateNote(String title) {
    return 'Create «$title»';
  }

  @override
  String get calendarNoTasks => 'No tasks';

  @override
  String get calendarPlanTask => 'Plan a task';

  @override
  String get calendarDeadlines => 'Deadlines';

  @override
  String get notesSearch => 'Search notes…';

  @override
  String get notesEmpty => 'No notes yet';

  @override
  String get notesNew => 'New note';

  @override
  String get calendarNotes => 'Notes';

  @override
  String dashboardOverdue(String date) {
    return 'overdue · $date';
  }

  @override
  String dashboardDueBy(String date) {
    return 'due $date';
  }

  @override
  String get dashboardPostpone15m => '+15 min';

  @override
  String get dashboardPostpone1h => '+1 hour';

  @override
  String get dashboardPostpone1d => '+1 day';

  @override
  String get dashboardPostpone3d => '+3 days';

  @override
  String dashboardTomorrow(String time) {
    return 'tomorrow $time';
  }

  @override
  String dashboardYesterday(String time) {
    return 'yesterday $time';
  }

  @override
  String get dashboardReflectPrompt => 'Quick look at what you’ve done?';

  @override
  String get dashboardGreetingAnon => 'Hi';

  @override
  String dashboardGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get dashboardOnboardingHint => 'Where to start? Pick an action below — this is a one-time setup, then your dashboard will fill with your records.';

  @override
  String get dashboardRoadmapNoGoal => 'AI will break your goal into 4–10 specific tasks linked to pentagon axes.';

  @override
  String dashboardRoadmapWithGoal(String goal) {
    return 'AI will break «$goal» into 4–10 tasks. The field is prefilled — you can edit.';
  }

  @override
  String get dashboardGraphHint => 'Second brain graph: goals, constraints, reflections, and notes. Tap a branch to edit.';

  @override
  String get dashboardNoteHint => 'Easy start: a few thoughts, an observation, or an idea. A note can later become a task.';

  @override
  String get dashboardRoadmapTitle => 'Generate a task plan';

  @override
  String get dashboardGenerate => 'Generate';

  @override
  String get dashboardGraphTitle => 'Explore knowledge base';

  @override
  String get dashboardOpenGraph => 'Open graph';

  @override
  String get dashboardNoteTitle => 'Write your first note';

  @override
  String get dashboardCreate => 'Create';

  @override
  String get dashboardWeekPassed => 'A week has passed';

  @override
  String get pomodoroFocusDone => 'Focus complete';

  @override
  String get pomodoroBreakDone => 'Break complete';

  @override
  String pomodoroLongBreakBody(int min) {
    return 'Long break $min min — press «Go» when ready.';
  }

  @override
  String pomodoroShortBreakBody(int min) {
    return 'Short break $min min — press «Go» when ready.';
  }

  @override
  String pomodoroNextFocusBody(int min) {
    return 'Next focus $min min — press «Go» when ready.';
  }

  @override
  String selfEpochNoData(int n) {
    return 'Epoch $n · no data';
  }

  @override
  String selfToNextLevel(int level, int xp) {
    return 'to L$level: $xp xp';
  }

  @override
  String get selfTreeHint => 'The tree grows from 3 branches. Add at least 3 branches to see the tree.';

  @override
  String axesSaveError(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get axesAiDrawing => 'AI is drawing new branches…';

  @override
  String axesRegenError(String error) {
    return 'Failed to regenerate: $error';
  }

  @override
  String get axesProfileUpdated => 'Profile updated. Regenerate branches now?';

  @override
  String get axesAiRedrawHint => 'AI will redraw the set with new inputs';

  @override
  String axesDragHint(int min, int max) {
    return 'Drag, rename, add or remove ($min to $max). To have AI redraw branches from scratch — Menu → «Regenerate».';
  }

  @override
  String axesMaxBranches(int max) {
    return 'Maximum $max branches';
  }

  @override
  String get axesRemoveTooltip => 'Remove';

  @override
  String get axesMinBranches => 'Minimum 3 branches';

  @override
  String get axesNameHint => 'e.g. Body';

  @override
  String get axesAiNewSet => 'AI will create a new set. Describe what to change';

  @override
  String get axesAiExample => 'e.g. more about health and creativity';

  @override
  String get axisXpTotal => 'TOTAL XP';

  @override
  String axisToEpoch(int n) {
    return 'TO E$n';
  }

  @override
  String axisLevelHint(int level, int epoch) {
    return 'Level L$level — from all completed tasks. Epoch E$epoch — from XP of this axis only, grows even after the tree is 100% full.';
  }

  @override
  String pomodoroCompleted(int n) {
    return '✦ $n';
  }

  @override
  String get pomodoroLongBreakEvery => 'Long break every N focuses';

  @override
  String get knowledgeContextHint => 'Briefly: who you are, what you do, what matters';

  @override
  String get knowledgePrefHint => 'key: value';

  @override
  String get navBranches => 'Branches';

  @override
  String get settingsMore => 'More';

  @override
  String get settingsOnboardAgain => 'Re-run onboarding';

  @override
  String get settingsOnboardAgainHint => 'Update interests, goals, and regenerate branches';

  @override
  String get settingsAddBranch => 'Add branch';

  @override
  String get editorSymbol => 'Symbol';

  @override
  String get roadmapMinAxes => 'Need at least 3 axes to build a plan.';

  @override
  String roadmapImported(int n) {
    return 'Imported tasks: $n';
  }

  @override
  String roadmapImportError(String error) {
    return 'Failed to import: $error';
  }

  @override
  String get roadmapGoalHint => 'The more specific, the better the plan. Example: «I want to run a half marathon in 3 months, current fitness is average».';

  @override
  String get roadmapInputHint => 'What do you want to achieve?';

  @override
  String get roadmapNeedAxes => 'Need at least 3 axes. Add them in the «Self» tab.';

  @override
  String get roadmapGenerating => 'This takes 5–15 seconds';

  @override
  String roadmapImportBtn(int n) {
    return 'Import ($n)';
  }
}
