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
  String get onboardingInterests => 'Interests';

  @override
  String get onboardingHours => 'Hours per week?';

  @override
  String get onboardingContinue => 'Next';

  @override
  String get onboardingFinish => 'Start';

  @override
  String get pomodoroTitle => 'Pomodoro';

  @override
  String get pomodoroStart => 'Start focus';

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
  String get settingsImport => 'Import from clipboard';

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
  String get pomodoroFocusDone => 'Focus done';

  @override
  String get pomodoroBreakDone => 'Break done';

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
  String get roadmapGenerating => 'Generating plan…';

  @override
  String roadmapImportBtn(int n) {
    return 'Import ($n)';
  }

  @override
  String get pomodoroRunning => 'Pomodoro running';

  @override
  String pomodoroFocusStarted(int min, String title) {
    return 'Focus $min min: $title';
  }

  @override
  String axisXpForAxis(int xp) {
    return '+$xp XP';
  }

  @override
  String get dashboardXpToday => 'XP TODAY';

  @override
  String dashboardXpWeek(int xp) {
    return '$xp this week';
  }

  @override
  String dashboardBestAxis(String name, int xp) {
    return '$name · +$xp XP';
  }

  @override
  String get dashboardDescribeGoal => 'Describe your goal';

  @override
  String dashboardOverdueCount(int n) {
    return '$n overdue';
  }

  @override
  String dashboardTodayCount(int n) {
    return '$n today';
  }

  @override
  String get dashboardThinking => 'Thinking about the plan…';

  @override
  String get aboutApp => 'About you';

  @override
  String get knowledgePrefs => 'Preferences';

  @override
  String get actionClear => 'Clear';

  @override
  String get roadmapHorizon => 'Horizon';

  @override
  String get roadmapWeek => 'Week';

  @override
  String get roadmapMonth => 'Month';

  @override
  String get roadmapQuarter => 'Quarter';

  @override
  String get roadmapTaskCount => 'Task count';

  @override
  String get pomodoroTooltip => 'Pomodoro';

  @override
  String get pulseStreak => 'STREAK';

  @override
  String get pulseStartToday => 'start today';

  @override
  String get pulseQuiet => 'quiet so far';

  @override
  String get pulseBestAxis => 'BEST AXIS';

  @override
  String get pulseNoData => 'no data';

  @override
  String pulseDeadline(String date) {
    return 'by $date';
  }

  @override
  String get pulseNoDeadline => 'no deadlines';

  @override
  String pulseDeadlineHours(int h) {
    return '${h}h';
  }

  @override
  String pulseDeadlineDays(int d) {
    return '${d}d';
  }

  @override
  String get onboardQ1 => 'Hi. I\'m your growth assistant. What\'s your name?';

  @override
  String onboardQ2(String name) {
    return 'Okay, $name. What do you want to achieve in the next year?';
  }

  @override
  String get onboardQ2NoName => 'What do you want to achieve in the next year?';

  @override
  String get onboardQ3 => 'Which areas are you already active in? Pick 3–8.';

  @override
  String get onboardQ4 => 'How many hours per week can you realistically dedicate?';

  @override
  String get onboardHoursWeek => 'h/wk';

  @override
  String onboardWeeklyTime(int h) {
    return 'Weekly for growth: ~$h h';
  }

  @override
  String onboardSaveError(String error) {
    return 'Failed to save profile: $error';
  }

  @override
  String get onboardSelectOne => 'Select at least one';

  @override
  String onboardSelectMore(int n) {
    return 'Select $n more';
  }

  @override
  String get onboardCustomOpen => '× custom';

  @override
  String get onboardCustomClosed => '+ custom';

  @override
  String onboardHoursLabel(int h) {
    return '$h h';
  }

  @override
  String get onboardLevelNovice => 'novice';

  @override
  String get onboardLevelLearning => 'learning';

  @override
  String get onboardLevelConfident => 'confident';

  @override
  String get onboardLevelExpert => 'expert';

  @override
  String onboardProfileName(String name) {
    return 'Name: $name.';
  }

  @override
  String onboardProfileGoal(String goal) {
    return 'Goal: $goal.';
  }

  @override
  String onboardProfileNow(String text) {
    return 'Current: $text.';
  }

  @override
  String onboardProfileHours(int h) {
    return 'Ready to dedicate about $h h/wk.';
  }

  @override
  String get actionNext => 'Next';

  @override
  String get onboardPlanTitle => 'Generate a plan right away?';

  @override
  String onboardPlanBody(String goal) {
    return 'AI will break «$goal» into 4–10 concrete tasks tied to the axes you just set up. The prompt is pre-filled — you can edit it before generating.';
  }

  @override
  String get actionLater => 'Later';

  @override
  String get onboardFillAxes => 'Fill at least 3 axes for the pentagram to make sense';

  @override
  String get onboardTooManyAxes => 'Too many axes: keep no more than 8, or it will be chaos';

  @override
  String onboardSaveAxesError(String error) {
    return 'Failed to save axes: $error';
  }

  @override
  String get onboardRegenTitle => 'Regenerate axes';

  @override
  String get onboardDescribeAxes => 'Describe your growth axes';

  @override
  String get onboardAiGenerating => 'AI is generating axes…';

  @override
  String get onboardYourAxes => 'Your personal axes';

  @override
  String get onboardAxesHint => '3 to 8 directions you want to grow in. Tasks and notes will be tied to them. You can change them later.';

  @override
  String onboardAiError(String error) {
    return 'Failed to reach AI: $error. Below are fallback axes, edit as you like.';
  }

  @override
  String onboardAiDrawingAxes(int n) {
    return 'From your $n interests AI is drawing a personal pentagram…';
  }

  @override
  String onboardAiGenerated(String model) {
    return 'Generated by $model. Rename, remove extras, add your own. 3 to 8.';
  }

  @override
  String get onboardRegenBtn => 'Regenerate axes';

  @override
  String get onboardWaitSeconds => 'This takes 5–25 seconds';

  @override
  String get onboardAddAxis => 'Add axis';

  @override
  String get onboardCreatePentagram => 'Create pentagram';

  @override
  String onboardAxisHint(int n) {
    return 'Axis name (#$n)';
  }

  @override
  String get onboardAxesUpdated => 'Axes updated';

  @override
  String onboardAxesMigrated(int n) {
    return 'Axes updated, migrated $n task links';
  }

  @override
  String get backendsTitle => 'Backends';

  @override
  String get backendsAdd => 'Add';

  @override
  String backendsError(String error) {
    return 'Error: $error';
  }

  @override
  String get backendsHint => 'The active backend is used for AI, sync and login. You can keep several (e.g. prod and a personal server) and switch without restarting.';

  @override
  String get backendsDeleteTitle => 'Delete backend?';

  @override
  String backendsSaveError(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get backendsPinging => 'Pinging…';

  @override
  String get backendsOnline => 'Backend is responding';

  @override
  String backendsOffline(String error) {
    return 'Not responding: $error';
  }

  @override
  String get backendsPing => 'Ping';

  @override
  String get backendsMakeActive => 'Make active';

  @override
  String get backendsEdit => 'Edit';

  @override
  String get backendsLastOne => 'At least one backend must remain';

  @override
  String get backendsNewTitle => 'New backend';

  @override
  String get backendsEditTitle => 'Edit backend';

  @override
  String get backendsName => 'Name';

  @override
  String get backendsNameHint => 'Prod · Local · Backup';

  @override
  String get backendsUrlError => 'Enter a valid URL starting with http(s)://';

  @override
  String get menuTitle => 'Weekly menu';

  @override
  String get menuNewConfirmTitle => 'Create a new menu?';

  @override
  String get menuNewConfirmBody => 'Current tasks and recipes will stay in the knowledge base — you can find them by tag menu/… or open by link.\n\nThe generation form will reopen.';

  @override
  String get actionCreate => 'Create';

  @override
  String get menuBreakfast => 'Breakfast';

  @override
  String get menuLunch => 'Lunch';

  @override
  String get menuDinner => 'Dinner';

  @override
  String get menuSnack => 'Snack';

  @override
  String menuRecipeStubTitle(String name) {
    return 'Recipe: $name';
  }

  @override
  String get menuRecipeStubBody => '_Recipe not yet generated._\n\nOpen the weekly menu → tap «Get recipe» next to this dish.';

  @override
  String menuShoppingTitle(String range) {
    return 'Shopping list · menu $range';
  }

  @override
  String get menuShoppingHeader => 'Shopping list for the week';

  @override
  String menuGoalServings(String goal, int n) {
    return 'Goal: $goal · $n servings';
  }

  @override
  String menuImportError(String error) {
    return 'Failed to import menu: $error';
  }

  @override
  String get menuIngredients => 'INGREDIENTS';

  @override
  String menuFullRecipe(String link) {
    return 'Full recipe: [[$link]]';
  }

  @override
  String get menuGenerating => 'AI is creating the menu…';

  @override
  String get menuImporting => 'Creating tasks and shopping list…';

  @override
  String menuDateRange(String from, String to) {
    return '7 days from $from to $to';
  }

  @override
  String get menuWhatCreated => 'What I will create';

  @override
  String get menuBullet1 => '21 tasks (breakfast / lunch / dinner for 7 days)';

  @override
  String get menuBullet2 => '1 note «Shopping list» with a checklist';

  @override
  String get menuBullet3 => 'Recipes will load on tap and be saved to linked notes';

  @override
  String get menuRegenerate => 'Regenerate';

  @override
  String get menuImportBtn => 'Import to tasks';

  @override
  String menuImportedCount(int n) {
    return 'Menu imported · $n tasks';
  }

  @override
  String get menuNew => 'New menu';

  @override
  String menuImportedHint(String tag) {
    return 'Tag #$tag groups all these entries. Tap a dish — open the task. Tap «Get recipe» on any dish — the recipe will be saved to the linked note.';
  }

  @override
  String menuServings(int n) {
    return '$n servings';
  }

  @override
  String menuDailyCalories(int n) {
    return '~$n kcal per day';
  }

  @override
  String get menuOpenRecipe => 'Open';

  @override
  String get menuGetRecipe => 'Get recipe';

  @override
  String get habitsTitle => 'Micro-habits';

  @override
  String get habitsIntentError => 'Describe the habit you want to build.';

  @override
  String habitsDayOf(int day, int total, String intent) {
    return 'Day $day of $total · challenge «$intent»';
  }

  @override
  String habitsImported(String intent, int n) {
    return 'Challenge «$intent» added — $n mini-tasks in Tasks.';
  }

  @override
  String habitsImportError(String error) {
    return 'Failed to import challenge: $error';
  }

  @override
  String get habitsGenerating => 'AI is finding tiny steps…';

  @override
  String get habitsImporting => 'Creating tasks in Noetica…';

  @override
  String habitsBullet1(int n) {
    return '$n tasks — one per day, from easy to reinforcing';
  }

  @override
  String get habitsBullet2 => 'Each action ≤ 2 minutes of real effort';

  @override
  String get habitsBullet3 => 'Will appear in Tasks under «Today» / «Tomorrow» / …';

  @override
  String habitsDaysMini(int n) {
    return '$n days · one mini-task each';
  }

  @override
  String habitsAddTasks(int n) {
    return 'Add $n tasks';
  }

  @override
  String get coachMorningTitle => 'Morning plan';

  @override
  String get coachEveningTitle => 'Evening review';

  @override
  String get coachRefresh => 'Refresh';

  @override
  String get coachError => 'Could not get advice';

  @override
  String get coachRetry => 'Retry';

  @override
  String get coachFocus => 'Focus of the day';

  @override
  String get coachPlanToday => 'Plan for today';

  @override
  String get coachMotivation => 'Motivation';

  @override
  String get coachDayResults => 'Day results';

  @override
  String get coachSummary => 'Summary';

  @override
  String get coachWins => 'What went well';

  @override
  String get coachImprove => 'What to improve';

  @override
  String get coachTomorrow => 'For tomorrow';

  @override
  String get reflectionResult => 'What went well / result';

  @override
  String get reflectionDifficulties => 'What was difficult / obstacles';

  @override
  String get reflectionMinutes => 'Time spent, min';

  @override
  String get reflectionCanSkip => 'Can skip';

  @override
  String get toolsTitle => 'Assistant';

  @override
  String get toolsAvailable => 'Available';

  @override
  String get toolsSoon => 'Coming soon';

  @override
  String get toolsDescriptionFull => 'AI compiles ready-made plans and distributes them across your days, axes and tags. Weekly menu, workout program, study course — everything goes to Calendar and Tasks as regular entries.';

  @override
  String toolsOpening(String title) {
    return 'Opening «$title»…';
  }

  @override
  String toolsComingSoon(String title) {
    return 'Coming soon: «$title»';
  }

  @override
  String authLoginError(String error) {
    return 'Login failed: $error';
  }

  @override
  String get authWait => 'Please wait…';

  @override
  String get authLoginGoogle => 'Sign in with Google';

  @override
  String get authSyncHint => 'Your data syncs between devices under one Google account. The app doesn\'t work without signing in.';

  @override
  String get dayCalendar => 'Calendar';

  @override
  String get dayPlanTask => 'Plan a task';

  @override
  String get dayEmpty => 'Nothing closed or planned for this day.';

  @override
  String get dayNoEntries => 'No entries.';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get dayTomorrow => 'Tomorrow';

  @override
  String get dayMonths => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get dayWeekdays => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String dayDone(int n) {
    return '✓ Completed ($n)';
  }

  @override
  String dayDeadlines(int n) {
    return '⏳ Deadlines ($n)';
  }

  @override
  String daySummaryClosed(int n, int xp) {
    return '$n closed · +$xp XP';
  }

  @override
  String daySummaryDeadline(int n) {
    return '$n deadline';
  }

  @override
  String get untitled => '(untitled)';

  @override
  String get weeklyTitle => 'Weekly review';

  @override
  String get weeklyAxis => 'Axis';

  @override
  String get weeklyCompleted => 'Completed';

  @override
  String get weeklyXP => 'XP';

  @override
  String get weeklyTasks => 'Tasks';

  @override
  String get weeklyNotes => 'Notes';

  @override
  String get weeklyStreak => 'Streak';

  @override
  String get weeklyBestDay => 'Best day';

  @override
  String get weeklyWorstDay => 'Weakest day';

  @override
  String get weeklyHighlights => 'Week highlights';

  @override
  String get weeklyAdvice => 'Advice for next week';

  @override
  String get weeklyNoData => 'Not enough data';

  @override
  String get weeklyDays => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get weeklyMonths => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get weeklyDone => 'completed';

  @override
  String get weeklyCreated => 'created';

  @override
  String get weeklyGenerating => 'AI is analyzing your week…';

  @override
  String get weeklyShare => 'Share';

  @override
  String get weeklyClose => 'Close';

  @override
  String get weeklyTotal => 'total';

  @override
  String get weeklyReflTitle => 'Week summary';

  @override
  String get weeklyReflSubtitle => 'A quick look: what went well, what didn\'t, and where to next.';

  @override
  String get weeklyWinsLabel => 'What went well';

  @override
  String get weeklyLossesLabel => 'What didn\'t work';

  @override
  String get weeklyFocusLabel => 'Focus for next week';

  @override
  String get weeklyMoodLabel => 'Well-being';

  @override
  String get weeklyLater => 'Later';

  @override
  String get weeklySubmit => 'Save';

  @override
  String get weeklyCustomHint => 'Custom (optional)';

  @override
  String weeklySaveError(String error) {
    return 'Failed to save: $error';
  }

  @override
  String weeklyMoodSummary(int n) {
    return 'well-being $n/5';
  }

  @override
  String get weeklyWin1 => 'completed plan';

  @override
  String get weeklyWin2 => 'new habits';

  @override
  String get weeklyWin3 => 'project progress';

  @override
  String get weeklyWin4 => 'had rest';

  @override
  String get weeklyWin5 => 'discipline held';

  @override
  String get weeklyWin6 => 'learned new topic';

  @override
  String get weeklyWin7 => 'good relationships';

  @override
  String get weeklyLoss1 => 'procrastination';

  @override
  String get weeklyLoss2 => 'fatigue';

  @override
  String get weeklyLoss3 => 'distractions';

  @override
  String get weeklyLoss4 => 'didn\'t prioritize important';

  @override
  String get weeklyLoss5 => 'burnout';

  @override
  String get weeklyLoss6 => 'was sick';

  @override
  String get weeklyLoss7 => 'conflicts';

  @override
  String get weeklyFocus1 => 'finish unfinished';

  @override
  String get weeklyFocus2 => 'new habit';

  @override
  String get weeklyFocus3 => 'focus on main';

  @override
  String get weeklyFocus4 => 'rest';

  @override
  String get weeklyFocus5 => 'study';

  @override
  String get weeklyFocus6 => 'sport';

  @override
  String get weeklyFocus7 => 'relationships';

  @override
  String epochPeak(int n) {
    return 'EPOCH $n · PEAK';
  }

  @override
  String get epochPostpone => 'Postpone';

  @override
  String get epochTreeFull => 'You\'ve filled the tree.';

  @override
  String epochTwoPaths(int n) {
    return 'Two paths ahead — you can refresh your axes and start Epoch $n with a clean slate, or stay focused and take on a harder tier of tasks.';
  }

  @override
  String get epochNewEpoch => 'New epoch';

  @override
  String epochNewEpochSub(int n) {
    return 'Redraw branches — Epoch $n. XP and level remain.';
  }

  @override
  String get epochGoDeeper => 'Go deeper';

  @override
  String epochGoDeeperSub(int n) {
    return 'Tier $n in the same Epoch — tasks will be harder, tree resets.';
  }

  @override
  String get graphBranchGoals => 'Goals';

  @override
  String get graphBranchConstraints => 'Constraints';

  @override
  String get graphBranchHighlights => 'Highlights';

  @override
  String get graphBranchReflections => 'Reflections';

  @override
  String get graphBranchPreferences => 'Preferences';

  @override
  String get graphFilterAll => 'All';

  @override
  String get graphFilterNotes => 'Notes';

  @override
  String get graphFilterTasks => 'Tasks';

  @override
  String get graphFilterBookmarks => 'Bookmarks';

  @override
  String get graphFilterDaily => 'Daily';

  @override
  String get graphFilterKnowledge => 'Self-knowledge';

  @override
  String get pomodoroStop => 'Stop';

  @override
  String get pomodoroSeries => 'Focus session series';

  @override
  String get pomodoroSeriesReset => 'Focus session series — tap to reset';

  @override
  String get pomodoroSettings => 'Settings';

  @override
  String get pomodoroFocusMin => 'Focus, min';

  @override
  String get pomodoroShortBreak => 'Short break, min';

  @override
  String get pomodoroLongBreak => 'Long break';

  @override
  String get pomodoroAutoStart => 'Auto-start next phase';

  @override
  String get pomodoroAutoStartSub => 'Timer continues automatically after focus/break ends';

  @override
  String get pomodoroSoundVibro => 'Sound + vibration';

  @override
  String get pomodoroSoundVibroSub => 'System ding and haptic on phase change (notification always comes)';

  @override
  String get graphCentreLabel => 'me';

  @override
  String get graphGoalsHint => 'What do you want to achieve';

  @override
  String get graphConstraintsHint => 'What holds you back';

  @override
  String get graphHighlightsHint => 'What you have achieved';

  @override
  String get graphReflectionsHint => 'Notes on the past';

  @override
  String get graphDelete => 'Delete';

  @override
  String get graphSearchHint => 'Search knowledge base…';

  @override
  String get graphKnowledgeBase => 'Knowledge base';

  @override
  String get graphSearchTooltip => 'Search';

  @override
  String get graphDailyTooltip => 'Daily';

  @override
  String get graphShowRecipes => 'Show recipes';

  @override
  String get graphHideRecipes => 'Hide recipes';

  @override
  String get graphGlobalTooltip => 'Global graph';

  @override
  String get graphNewNote => 'New note';

  @override
  String get graphResetView => 'Reset view';

  @override
  String get graphShuffle => 'Shuffle';

  @override
  String get graphEmptyTitle1 => 'Write';

  @override
  String get graphEmptyBody1 => 'Notes, tasks, daily — everything becomes graph nodes.';

  @override
  String get graphEmptyTitle2 => 'Connect';

  @override
  String get graphEmptyBody2 => 'Mention [[title]] in text — Noetica builds an edge.';

  @override
  String get graphEmptyTitle3 => 'Explore';

  @override
  String get graphEmptyBody3 => 'Graph shows which topics overlap and where gaps are.';

  @override
  String get graphEmptyTitle4 => 'About you';

  @override
  String get graphEmptyBody4 => 'Goals, constraints, achievements — these branches help AI.';

  @override
  String get graphEmptyTitle5 => 'First entry';

  @override
  String get graphEmptyBody5 => 'Tap + to create a note and see the graph in action.';

  @override
  String get graphEmptyTitle6 => 'Tags';

  @override
  String get graphEmptyBody6 => 'Add tags to entries — they become nodes too.';

  @override
  String get graphResetFilter => 'Reset filter';

  @override
  String get graphEmptyAllTitle => 'Knowledge base is empty';

  @override
  String get graphEmptyAllBody => 'Create your first note or task — they will appear here as graph nodes.';

  @override
  String get graphEmptyAllAction => 'Create entry';

  @override
  String get graphEmptyNotesTitle => 'No notes yet';

  @override
  String get graphEmptyNotesBody => 'Notes appear as individual nodes. Links are created automatically when the body contains a [[reference]] to another note.';

  @override
  String get graphEmptyNotesAction => 'Create note';

  @override
  String get graphEmptyTasksTitle => 'No tasks in graph';

  @override
  String get graphEmptyTasksBody => 'Create a task via \"+\" or generate a task plan from your goal.';

  @override
  String get graphEmptyBookmarksTitle => 'No bookmarks yet';

  @override
  String get graphEmptyBookmarksBody => 'Long-press a graph node to bookmark it.';

  @override
  String get graphEmptyDailyTitle => 'Daily is empty';

  @override
  String get graphEmptyDailyBody => 'Tap the calendar icon in the header to create an entry for today.';

  @override
  String get graphEmptyKnowledgeTitle => 'Self-knowledge is empty';

  @override
  String get graphEmptyKnowledgeBody => 'Fill in goals, constraints and achievements via branch taps — this gives AI more context for plan generation.';

  @override
  String get editListAdd => 'Add';

  @override
  String get editListRemove => 'Remove';

  @override
  String get editListSave => 'Save';

  @override
  String get graphConnections => 'connections';

  @override
  String get selfBranchesTooltip => 'Branches';

  @override
  String get selfSettingsTooltip => 'Settings';

  @override
  String get selfTreeBranches => 'TREE · BRANCHES';

  @override
  String get selfGeneratePlan => 'Generate plan';

  @override
  String get selfScoreExplain => 'Points are awarded for completing tasks linked to axes. They decay over time — the pentagram reflects you over the last month.';

  @override
  String selfEpochArchive(int n) {
    return 'EPOCH $n · ARCHIVE';
  }

  @override
  String get selfArchiveReadonly => 'Tree of this epoch at the time of transition. Read only.';

  @override
  String get selfArchiveEmpty => 'Archive of this epoch is empty — it ended before we started recording history. Future transitions will be saved completely.';

  @override
  String get selfArchiveBranches => 'BRANCHES OF THAT EPOCH';

  @override
  String get selfEpochLabel => 'EPOCH';

  @override
  String selfEpochShort(String epoch) {
    return 'E$epoch';
  }

  @override
  String selfEpochTierShort(String epoch, String tier) {
    return 'E$epoch.$tier';
  }

  @override
  String get selfLevelLabel => 'LEVEL';

  @override
  String get selfStreakLabel => 'STREAK';

  @override
  String selfStreakDays(int n) {
    return '$n d.';
  }

  @override
  String get selfReadyTransition => 'Ready for transition — tap to open';

  @override
  String get selfStreakBroken => 'Streak broken. Close one task today — start over.';

  @override
  String axisEpochPrefix(String n) {
    return 'E$n';
  }

  @override
  String get axisState => 'STATE';

  @override
  String get axisCompletedByAxis => 'COMPLETED BY AXIS';

  @override
  String get axisNoTasks => 'Completed tasks linked to this axis will appear here.';

  @override
  String get axesOnboardingFirst => 'Complete onboarding first.';

  @override
  String get axesYes => 'Yes';

  @override
  String get axesAxis => 'Axis';

  @override
  String get axesDone => 'Done';

  @override
  String get dashNoActiveTasks => 'No active tasks — rest or create a new one.';

  @override
  String get dashDone => 'Done';

  @override
  String get dashPostpone => 'Postpone';

  @override
  String get dashFocusTimer => 'Start focus timer';

  @override
  String get dashPostponeBy => 'POSTPONE BY';

  @override
  String get dashViewPentagram => 'View your pentagram';

  @override
  String get heatmapWeekdays => 'Mo,,We,,Fr,,';

  @override
  String get heatmapMonths => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String heatmapEmptyYear(int year) {
    return 'nothing in $year yet';
  }

  @override
  String heatmapYearSummary(String total, int year) {
    return '$total closed in $year — tap a day';
  }

  @override
  String get heatmapLess => 'less';

  @override
  String get heatmapMore => 'more';

  @override
  String get miniTreeEmpty => 'Tree appears after the first branch';

  @override
  String miniTreeXp(int xp) {
    return 'total $xp XP · tap for full tree';
  }

  @override
  String pulseStreakDay(int n) {
    return '$n day';
  }

  @override
  String pulseStreakDays(int n) {
    return '$n days';
  }

  @override
  String pulseStreakDaysMany(int n) {
    return '$n days';
  }

  @override
  String get notesQuickHint => 'Quick note…';

  @override
  String get notesSearchHint => 'Search';

  @override
  String get notesNotFound => 'Nothing found';

  @override
  String get notesEmptyHint => 'Write a thought in the line above or open the full editor with \"+\".';

  @override
  String get notesNotFoundHint => 'Try a different query.';

  @override
  String get calMonths => 'January,February,March,April,May,June,July,August,September,October,November,December';

  @override
  String get calWeekdays => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get calToday => 'Today';

  @override
  String get calPlanDay => 'Plan for this day';

  @override
  String get calNothingRecorded => 'Nothing recorded.';

  @override
  String get calMonthsShort => 'Jan,Feb,Mar,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get calDaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get calTodayPrefix => 'Today';

  @override
  String get calYesterday => 'Yesterday';

  @override
  String get calTomorrow => 'Tomorrow';

  @override
  String get calDayEmpty => 'Nothing recorded for this day.';

  @override
  String get taskOverdue => 'Overdue';

  @override
  String get taskNoTasks => 'No tasks — all completed or none created.';

  @override
  String get settingsSync => 'Sync';

  @override
  String get settingsSyncSub => 'Google Drive for backup';

  @override
  String get settingsExportSub => 'JSON to clipboard';

  @override
  String get settingsImportSub => 'Paste JSON';

  @override
  String get settingsAboutSub => 'Version, licenses';

  @override
  String get roadmapTitle => 'AI Plan';

  @override
  String get roadmapGenerateFirst => 'Generate your first plan';

  @override
  String get roadmapAxis => 'Axis';

  @override
  String get roadmapGoal => 'Goal';

  @override
  String get roadmapGenerate => 'Generate';

  @override
  String get roadmapWeek1 => 'Week 1';

  @override
  String get roadmapWeek2 => 'Week 2';

  @override
  String get roadmapWeek3 => 'Week 3';

  @override
  String get roadmapWeek4 => 'Week 4';

  @override
  String get roadmapError => 'Error';

  @override
  String get homeMore => 'More';

  @override
  String get onboardingActiveHours => 'Active hours';

  @override
  String get menuRecipeSteps => 'RECIPE STEPS';

  @override
  String get menuGenerateRecipe => 'Generate recipe';

  @override
  String get entryUntitled => 'Untitled';

  @override
  String get axisTileFocusTasks => 'focus tasks';

  @override
  String get backendsNoKey => 'key not set';

  @override
  String get editListAddItem => 'Add';

  @override
  String get editListHint => 'New item';

  @override
  String get editListAddFirst => 'Add first entry';

  @override
  String get entryTaskDone => '✓ task';

  @override
  String get entryTask => 'task';

  @override
  String get backendsActive => 'Active';

  @override
  String get debugFillAxes => 'Fill all axes to 100%';

  @override
  String get debugFillAxesSub => 'Creates synthetic tasks so the pentagon hits peak';

  @override
  String get debugFillAxesDone => 'Done. Open Self — overlay should appear.';

  @override
  String get debugResetAck => 'Reset epoch ack';

  @override
  String get debugResetAckSub => 'Clears epochAckedAt — overlay will trigger again at peak';

  @override
  String get debugResetAckDone => 'Ack reset.';

  @override
  String get debugBumpEpoch => 'Force +1 epoch';

  @override
  String get debugBumpEpochDone => 'Epoch incremented.';

  @override
  String get debugResetEpoch => 'Reset epoch to 1';

  @override
  String get debugResetEpochSub => 'Full progression rollback to Epoch 1';

  @override
  String get debugResetEpochDone => 'Reset to Epoch 1.';

  @override
  String get roadmapRegenerate => 'Regenerate';

  @override
  String get roadmapFailed => 'Failed';

  @override
  String get roadmapGenericError => 'Something went wrong';

  @override
  String get roadmapBack => 'Back';

  @override
  String get roadmapToday => 'today';

  @override
  String get roadmapTomorrow => 'tomorrow';

  @override
  String roadmapInDays(int n) {
    return 'in $n days';
  }

  @override
  String roadmapDueDate(String date) {
    return 'by $date';
  }

  @override
  String get roadmapFromOnboarding => 'From onboarding';

  @override
  String get pomodoroStopAction => 'Stop';

  @override
  String get pomodoroGoAction => 'Let\'s go';

  @override
  String get onboardGoals => 'improve health,switch career,learn something new,become disciplined,develop relationships,find balance,launch project';

  @override
  String get onboardInterests => 'studying,code,design,sports,meditation,reading,music,languages,cooking,relationships,finance,creativity,career,family';

  @override
  String get onboardTimePrefix => 'Time';

  @override
  String get onboardPainPrefix => 'What blocks you';

  @override
  String get onboardComfortTime => 'Comfortable time';

  @override
  String get onboardNameHint => 'Name';

  @override
  String get onboardCustomValue => 'Custom value';

  @override
  String get onboardVolumeMini => 'mini volume, bit by bit';

  @override
  String get onboardVolumeComfort => 'comfortable pace';

  @override
  String get onboardVolumeSerious => 'serious involvement';

  @override
  String get onboardVolumeAlmost => 'almost a second job';

  @override
  String get onboardVolumeMax => 'maximum mode';

  @override
  String onboardPainSummary(String pain) {
    return 'Obstacles: $pain.';
  }

  @override
  String onboardTimeSummary(String time) {
    return 'Comfortable time: $time.';
  }

  @override
  String get pulseDeadlineLabel => 'Deadline';

  @override
  String get pluralTaskOne => 'task';

  @override
  String get pluralTaskFew => 'tasks';

  @override
  String get pluralTaskMany => 'tasks';

  @override
  String get pluralDeadlineOne => 'deadline';

  @override
  String get pluralDeadlineFew => 'deadlines';

  @override
  String get pluralDeadlineMany => 'deadlines';

  @override
  String get pluralNoteOne => 'note';

  @override
  String get pluralNoteFew => 'notes';

  @override
  String get pluralNoteMany => 'notes';

  @override
  String get pluralBranchOne => 'branch';

  @override
  String get pluralBranchFew => 'branches';

  @override
  String get pluralBranchMany => 'branches';

  @override
  String get heatmapNothing => 'nothing';

  @override
  String miniTreeBest(String symbol, String name, int level) {
    return 'best: $symbol $name · L$level';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String get timeNow => 'now';

  @override
  String timeAgoFmt(int value, String unit) {
    return '$value $unit ago';
  }

  @override
  String timeInFmt(int value, String unit) {
    return 'in $value $unit';
  }

  @override
  String get timeRightAfter => 'right after';

  @override
  String timePlusFmt(int value, String unit) {
    return '+ $value $unit';
  }

  @override
  String get pluralDayOne => 'day';

  @override
  String get pluralDayFew => 'days';

  @override
  String get pluralDayMany => 'days';

  @override
  String get pluralHourOne => 'hour';

  @override
  String get pluralHourFew => 'hours';

  @override
  String get pluralHourMany => 'hours';

  @override
  String get pluralMinuteOne => 'minute';

  @override
  String get pluralMinuteFew => 'minutes';

  @override
  String get pluralMinuteMany => 'minutes';

  @override
  String get pluralMonthOne => 'month';

  @override
  String get pluralMonthFew => 'months';

  @override
  String get pluralMonthMany => 'months';

  @override
  String get pluralYearOne => 'year';

  @override
  String get pluralYearFew => 'years';

  @override
  String get pluralYearMany => 'years';

  @override
  String get pomodoroFocus => 'Focus';

  @override
  String get pomodoroBreak => 'Short break';

  @override
  String pomodoroLongBreakHint(int min) {
    return 'Long break $min min';
  }

  @override
  String pomodoroShortBreakHint(int min) {
    return 'Short break $min min';
  }

  @override
  String pomodoroNextFocusAuto(int min) {
    return 'Let\'s go — next focus $min min';
  }

  @override
  String get pomodoroNextFocusManual => 'Start next focus when ready';

  @override
  String get pomodoroTimeToRest => 'Time to rest';

  @override
  String get pomodoroBackToFocus => 'Back to focus';

  @override
  String get pomodoroReadyAgain => 'Ready to work again?';

  @override
  String get notifChannelName => 'Deadlines & reminders';

  @override
  String get notifChannelDesc => 'Reminders about upcoming and overdue tasks.';

  @override
  String get notifWindowsHint => 'Windows toasts + tray icon. Keep the app minimized to tray for notifications to work.';

  @override
  String get notifUnsupported => 'This platform is not supported.';

  @override
  String get notifMorningTitle => 'Morning plan';

  @override
  String get notifMorningBody => 'Open AI coach — plan your day';

  @override
  String get notifEveningTitle => 'Evening review';

  @override
  String get notifEveningBody => 'Let\'s review the day — what went well, what to improve?';

  @override
  String get notifDeadlineTomorrow => 'Deadline tomorrow';

  @override
  String get notifDeadlineToday => 'Deadline today';

  @override
  String get notifDeadlinePassed => 'Deadline passed';

  @override
  String get notifWeeklyTitle => 'Weekly reflection time';

  @override
  String get notifWeeklyBody => 'How was your week?';

  @override
  String get trayOpen => 'Open Noetica';

  @override
  String get trayExit => 'Exit';

  @override
  String get genMenuGoal => 'Nutrition goal';

  @override
  String get genMenuClassic => 'Balanced';

  @override
  String get genMenuLoseWeight => 'Lose weight';

  @override
  String get genMenuHealth => 'Health';

  @override
  String get genMenuMuscle => 'Muscle gain';

  @override
  String get genMenuEnergy => 'Energy / sport';

  @override
  String get genMenuServings => 'Servings';

  @override
  String get genMenuStart => 'Menu start';

  @override
  String get genMenuAxis => 'Growth axis';

  @override
  String get genMenuAxisHelp => '21 tasks will be added to the chosen axis and grant XP when completed.';

  @override
  String get genMenuRestrictions => 'Restrictions (optional)';

  @override
  String get genMenuRestrictionsHint => 'gluten-free; no pork; vegetarian';

  @override
  String get genMenuNotes => 'Extra wishes (optional)';

  @override
  String get genMenuNotesHint => 'less cooking on weekdays; more fish; quick breakfasts';

  @override
  String get genHabitIntent => 'What habit do you want to build?';

  @override
  String get genHabitIntentHint => 'sleep earlier · less phone in the morning · drink more water';

  @override
  String get genHabitDays => 'How many days';

  @override
  String get genHabitAxis => 'Growth axis';

  @override
  String get genHabitAxisHelp => 'All mini-tasks will earn XP and grow with this axis.';

  @override
  String get genHabitNotes => 'Extra wishes (optional)';

  @override
  String get genHabitNotesHint => 'morning routine · tried before, didn\'t stick · no apps needed';

  @override
  String get genMenuTitle => 'Weekly menu';

  @override
  String get genMenuDesc => '7 days × breakfast / lunch / dinner with macros for your goal.';

  @override
  String get genMenuBullet1 => '21 tasks on the Body axis with deadlines';

  @override
  String get genMenuBullet2 => 'Shopping list as a separate checklist note';

  @override
  String get genMenuBullet3 => 'Full recipes loaded on tap';

  @override
  String get genTrainingTitle => 'Training plan';

  @override
  String get genTrainingDesc => '4-week program for strength, endurance, or recomposition.';

  @override
  String get genTrainingBullet1 => 'Takes available equipment into account';

  @override
  String get genTrainingBullet2 => 'Each session is a task with sets as sub-tasks';

  @override
  String get genStudyTitle => 'Study plan';

  @override
  String get genStudyDesc => 'Break down \"learn X\" into lessons with note summaries.';

  @override
  String get genStudyBullet1 => 'Lessons = tasks on the Mind axis';

  @override
  String get genStudyBullet2 => 'Summaries are notes linked via [[wiki-links]]';

  @override
  String get genHabitsTitle => 'Micro-habits';

  @override
  String get genHabitsDesc => '7-day challenge of short daily tasks.';

  @override
  String get genHabitsBullet1 => 'Each action ≤ 2 min — you actually follow through';

  @override
  String get genHabitsBullet2 => 'Tailored to your axis, progressively harder';

  @override
  String get genHabitsBullet3 => 'Appear in Tasks with daily deadlines';

  @override
  String get reflectionBlocked => 'Stuck';

  @override
  String get menuGoalLoseWeight => 'Weight loss';

  @override
  String get menuGoalHealth => 'Health';

  @override
  String get menuGoalMuscle => 'Muscle gain';

  @override
  String get menuGoalEnergy => 'Energy / sport';

  @override
  String get menuGoalClassic => 'Classic balanced';

  @override
  String get apiErrNotLoggedIn => 'Not signed in to Google. Please sign in and try again.';

  @override
  String apiErrServerUnreachable(String details) {
    return 'Could not reach the server: $details';
  }

  @override
  String get apiErrSessionExpired => 'Session expired. Please sign in with Google again.';

  @override
  String apiErrInvalidJson(String details) {
    return 'Server returned invalid JSON: $details';
  }

  @override
  String get validationRequired => 'Field is required';

  @override
  String validationRange(int min, int max) {
    return 'Must be between $min and $max';
  }

  @override
  String get backendDefault => 'Default';

  @override
  String get backendCantDeleteLast => 'Cannot delete the only backend. Add another one first.';

  @override
  String menuRecipePrefix(String name) {
    return 'Recipe: $name';
  }

  @override
  String get menuRecipeNotGenerated => 'Recipe not yet generated';

  @override
  String menuSummary(String goal, int servings, String range) {
    return '$goal · $servings servings · $range';
  }

  @override
  String get androidChannelName => 'Deadlines and reminders';

  @override
  String get androidChannelDesc => 'Reminders for approaching and overdue tasks.';

  @override
  String get interestSport => 'Sports';

  @override
  String get interestReading => 'Reading';

  @override
  String get interestLanguages => 'Language learning';

  @override
  String get interestProgramming => 'Programming';

  @override
  String get interestMusic => 'Music';

  @override
  String get interestDrawing => 'Drawing';

  @override
  String get interestMeditation => 'Meditation';

  @override
  String get interestFriendship => 'Friendship';

  @override
  String get interestFamily => 'Family';

  @override
  String get interestFinance => 'Finance';

  @override
  String get interestCareer => 'Career';

  @override
  String get interestBusiness => 'Entrepreneurship';

  @override
  String get interestNutrition => 'Nutrition';

  @override
  String get interestSleep => 'Sleep';

  @override
  String get interestTravel => 'Travel';

  @override
  String get interestWriting => 'Writing';

  @override
  String get interestCrafts => 'Crafts';

  @override
  String get skillNovice => 'Novice';

  @override
  String get skillLearning => 'Learning';

  @override
  String get skillConfident => 'Confident';

  @override
  String get skillExpert => 'Expert';

  @override
  String get onboardAxisBody => 'Body';

  @override
  String get onboardAxisMind => 'Mind';

  @override
  String get onboardAxisWork => 'Work';

  @override
  String get onboardAxisRelations => 'Relationships';

  @override
  String get onboardAxisSoul => 'Soul';

  @override
  String menuMacroLine(int cal, int p, int f, int c) {
    return '$cal kcal · ${p}P/${f}F/${c}C';
  }

  @override
  String get backendUrlEmpty => 'URL must not be empty.';
}
