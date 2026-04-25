import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/personal_knowledge_service.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// Chat-style 7-step onboarding. Each step is presented as an assistant
/// "bubble" with predefined chip choices (single or multi-select) plus an
/// optional free-text input — minimising how much the user has to type.
///
/// The set of fields collected is the same that the LLM expects on
/// `/onboarding/axes` and `/roadmap/generate`:
///   name, aspiration, interests, interest levels, pain points,
///   weekly-hours, preferred work windows.
class OnboardingChatScreen extends ConsumerStatefulWidget {
  const OnboardingChatScreen({super.key, this.existing, this.onDone});

  final UserProfile? existing;
  final VoidCallback? onDone;

  @override
  ConsumerState<OnboardingChatScreen> createState() =>
      _OnboardingChatScreenState();
}

class _OnboardingChatScreenState
    extends ConsumerState<OnboardingChatScreen> {
  static const int _stepCount = 7;
  int _step = 0;

  // Collected answers.
  String _name = '';
  String _aspiration = '';
  final List<String> _interests = [];
  final Map<String, String> _interestLevels = {};
  final List<String> _painPoints = [];
  int _weeklyHours = 5;
  final List<String> _windows = [];

  // Chat thread of "messages" — bot prompt + user reply pairs.
  final List<_ChatMsg> _thread = [];

  // Per-step UI state.
  final _textCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  bool _customOpen = false;
  // For interest-levels step we track which interest is being calibrated.
  int _levelIdx = 0;
  bool _saving = false;

  // Suggestions.
  static const _aspirationOptions = <String>[
    'поправить здоровье',
    'сменить профессию',
    'выучить новое',
    'стать дисциплинированнее',
    'развить отношения',
    'найти баланс',
    'запустить проект',
  ];
  static const _interestOptions = <String>[
    'учёба',
    'код',
    'дизайн',
    'спорт',
    'медитация',
    'чтение',
    'музыка',
    'языки',
    'кулинария',
    'отношения',
    'финансы',
    'творчество',
    'карьера',
    'семья',
  ];
  static const _painOptions = <String>[
    'прокрастинация',
    'не хватает времени',
    'нет цели',
    'усталость',
    'перфекционизм',
    'нет дисциплины',
    'распыление',
    'страх',
    'выгорание',
    'отвлечения',
  ];
  static const _windowOptions = <String>[
    'утром',
    'днём',
    'вечером',
    'ночью',
    'в выходные',
  ];
  static const _hoursOptions = <int>[2, 5, 10, 18, 30];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name = e.name;
      _aspiration = e.aspiration;
      _interests.addAll(e.interests);
      _interestLevels.addAll(e.interestLevels);
      _painPoints.addAll(
        e.painPoint.isNotEmpty ? e.painPoint.split(',').map((s) => s.trim()) : const [],
      );
      _weeklyHours = e.weeklyHours;
    }
    _seedThread();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _seedThread() {
    _thread.add(_ChatMsg.bot(_questionFor(0)));
  }

  String _questionFor(int step) {
    switch (step) {
      case 0:
        return 'Привет. Я твой ассистент роста. Как тебя зовут?';
      case 1:
        return _name.isNotEmpty
            ? 'Окей, ${_firstName(_name)}. Чего ты хочешь достичь в ближайший год?'
            : 'Чего ты хочешь достичь в ближайший год?';
      case 2:
        return 'В каких сферах ты уже что-то делаешь? Выбери 3–8.';
      case 3:
        return 'Оцени свой текущий уровень в каждой. Это нужно, чтобы я подбирал задачи по силам.';
      case 4:
        return 'Что тебе чаще всего мешает? Можно несколько.';
      case 5:
        return 'Сколько часов в неделю реально готов уделять?';
      case 6:
        return 'Когда тебе удобнее работать над этим?';
      default:
        return '';
    }
  }

  String _firstName(String full) =>
      full.trim().isEmpty ? '' : full.trim().split(RegExp(r'\s+')).first;

  // ===== Validation =====
  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _name.trim().isNotEmpty;
      case 1:
        return _aspiration.trim().isNotEmpty;
      case 2:
        return _interests.length >= 3;
      case 3:
        return _interests.every(
            (i) => kInterestLevels.contains(_interestLevels[i] ?? 'novice'));
      case 4:
        return true;
      case 5:
        return _weeklyHours > 0;
      case 6:
        return _windows.isNotEmpty;
    }
    return false;
  }

  String _userReplyFor(int step) {
    switch (step) {
      case 0:
        return _name.trim();
      case 1:
        return _aspiration.trim();
      case 2:
        return _interests.join(', ');
      case 3:
        return _interests
            .map((i) =>
                '$i: ${_levelRu(_interestLevels[i] ?? 'novice')}')
            .join('; ');
      case 4:
        return _painPoints.isEmpty
            ? 'ничего особенно'
            : _painPoints.join(', ');
      case 5:
        return '$_weeklyHours ч/нед';
      case 6:
        return _windows.join(', ');
    }
    return '';
  }

  void _advance() {
    if (!_canAdvance) return;
    setState(() {
      _thread.add(_ChatMsg.user(_userReplyFor(_step)));
      _customOpen = false;
      _customCtrl.clear();
      _textCtrl.clear();
      if (_step < _stepCount - 1) {
        _step += 1;
        _thread.add(_ChatMsg.bot(_questionFor(_step)));
      }
    });
    if (_step >= _stepCount - 1) {
      // Last step's answer is now committed; finish.
      _finish();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      // Pop the last bot message + last user message.
      _thread
        ..removeLast() // current bot question
        ..removeLast(); // previous user reply
      _step -= 1;
      _customOpen = false;
      _customCtrl.clear();
      _textCtrl.clear();
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    HapticFeedback.selectionClick();
    try {
      final svc = ref.read(profileServiceProvider);
      final cleanLevels = <String, String>{
        for (final i in _interests)
          i: _interestLevels[i] ?? 'novice',
      };
      final base = widget.existing ??
          UserProfile(
            name: '',
            aspiration: '',
            interests: const [],
            interestLevels: const {},
            painPoint: '',
            weeklyHours: 5,
            updatedAt: DateTime.now(),
          );
      final profile = base.copyWith(
        name: _name.trim(),
        aspiration: _aspiration.trim(),
        interests: List<String>.from(_interests),
        interestLevels: cleanLevels,
        painPoint: _painPoints.join(', '),
        weeklyHours: _weeklyHours,
        updatedAt: DateTime.now(),
      );
      await svc.save(profile);

      final summary = _buildKnowledgeSummary(profile);
      await PersonalKnowledgeService().recordOnboarding(
        summary: summary,
        goals: profile.aspiration.isEmpty ? const [] : [profile.aspiration],
        constraints: [
          'В неделю на развитие: ~${profile.weeklyHours} ч',
          if (_windows.isNotEmpty) 'Время: ${_windows.join(", ")}',
          if (_painPoints.isNotEmpty)
            'Что мешает: ${_painPoints.join(", ")}',
        ],
      );
      ref.invalidate(profileProvider);
      if (widget.onDone != null) {
        widget.onDone!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить профиль: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildKnowledgeSummary(UserProfile profile) {
    final levelsBlurb = profile.interestLevels.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${e.key} (${_levelRu(e.value)})')
        .join(', ');
    final parts = <String>[
      if (profile.name.isNotEmpty) 'Зовут ${profile.name}.',
      if (profile.aspiration.isNotEmpty) 'Цель: ${profile.aspiration}.',
      if (levelsBlurb.isNotEmpty) 'Сейчас: $levelsBlurb.',
      if (_painPoints.isNotEmpty)
        'Что мешает: ${_painPoints.join(", ")}.',
      'Готов уделять около ${profile.weeklyHours} ч/нед.',
      if (_windows.isNotEmpty) 'Удобное время: ${_windows.join(", ")}.',
    ];
    return parts.join(' ');
  }

  String _levelRu(String level) => switch (level) {
        'novice' => 'новичок',
        'learning' => 'учусь',
        'confident' => 'уверенно',
        'expert' => 'эксперт',
        _ => level,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back,
              color: palette.fg),
          onPressed: _back,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_step + 1} / $_stepCount',
                style: TextStyle(color: palette.muted, fontSize: 13)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _thread.length,
                reverse: false,
                itemBuilder: (context, i) {
                  final m = _thread[i];
                  return _Bubble(msg: m, palette: palette);
                },
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.line)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _stepInput(palette),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepInput(NoeticaPalette palette) {
    if (_saving) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_step) {
      case 0:
        return _TextReply(
          controller: _textCtrl,
          hint: 'Имя',
          onChange: (v) => setState(() => _name = v),
          onSubmit: _canAdvance ? _advance : null,
          palette: palette,
        );
      case 1:
        return _ChipsReply(
          options: _aspirationOptions,
          selected: _aspiration.isEmpty ? const [] : [_aspiration],
          allowMultiple: false,
          onPick: (v) {
            setState(() => _aspiration = v);
            _advance();
          },
          customOpen: _customOpen,
          onToggleCustom: () =>
              setState(() => _customOpen = !_customOpen),
          customCtrl: _customCtrl,
          onSubmitCustom: () {
            final v = _customCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() => _aspiration = v);
            _advance();
          },
          palette: palette,
          submitLabel: null, // single-select auto-advances
        );
      case 2:
        return _ChipsReply(
          options: _interestOptions,
          selected: _interests,
          allowMultiple: true,
          onPick: (v) => setState(() {
            final idx = _interests
                .indexWhere((e) => e.toLowerCase() == v.toLowerCase());
            if (idx >= 0) {
              final removed = _interests.removeAt(idx);
              _interestLevels.remove(removed);
            } else if (_interests.length < 12) {
              _interests.add(v);
              _interestLevels.putIfAbsent(v, () => 'novice');
            }
          }),
          customOpen: _customOpen,
          onToggleCustom: () =>
              setState(() => _customOpen = !_customOpen),
          customCtrl: _customCtrl,
          onSubmitCustom: () {
            final v = _customCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() {
              if (_interests
                      .where(
                          (e) => e.toLowerCase() == v.toLowerCase())
                      .isEmpty &&
                  _interests.length < 12) {
                _interests.add(v);
                _interestLevels.putIfAbsent(v, () => 'novice');
              }
              _customOpen = false;
              _customCtrl.clear();
            });
          },
          palette: palette,
          submitLabel: _canAdvance
              ? 'Далее'
              : 'Выбери ещё ${3 - _interests.length}',
          onSubmit: _canAdvance ? _advance : null,
        );
      case 3:
        return _LevelsReply(
          interests: _interests,
          levels: _interestLevels,
          activeIdx: _levelIdx,
          onLevel: (interest, level) =>
              setState(() => _interestLevels[interest] = level),
          onActive: (i) => setState(() => _levelIdx = i),
          onSubmit: _canAdvance ? _advance : null,
          palette: palette,
        );
      case 4:
        return _ChipsReply(
          options: _painOptions,
          selected: _painPoints,
          allowMultiple: true,
          onPick: (v) => setState(() {
            final idx = _painPoints
                .indexWhere((e) => e.toLowerCase() == v.toLowerCase());
            if (idx >= 0) {
              _painPoints.removeAt(idx);
            } else {
              _painPoints.add(v);
            }
          }),
          customOpen: _customOpen,
          onToggleCustom: () =>
              setState(() => _customOpen = !_customOpen),
          customCtrl: _customCtrl,
          onSubmitCustom: () {
            final v = _customCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() {
              if (_painPoints
                  .where((e) => e.toLowerCase() == v.toLowerCase())
                  .isEmpty) {
                _painPoints.add(v);
              }
              _customOpen = false;
              _customCtrl.clear();
            });
          },
          palette: palette,
          submitLabel: 'Далее',
          onSubmit: _advance,
        );
      case 5:
        return _HoursReply(
          options: _hoursOptions,
          selected: _weeklyHours,
          onPick: (v) {
            setState(() => _weeklyHours = v);
            _advance();
          },
          palette: palette,
        );
      case 6:
        return _ChipsReply(
          options: _windowOptions,
          selected: _windows,
          allowMultiple: true,
          onPick: (v) => setState(() {
            final idx = _windows
                .indexWhere((e) => e.toLowerCase() == v.toLowerCase());
            if (idx >= 0) {
              _windows.removeAt(idx);
            } else {
              _windows.add(v);
            }
          }),
          customOpen: false,
          onToggleCustom: null,
          customCtrl: null,
          onSubmitCustom: null,
          palette: palette,
          submitLabel: _canAdvance ? 'Готово' : 'Выбери хотя бы один',
          onSubmit: _canAdvance ? _advance : null,
        );
    }
    return const SizedBox.shrink();
  }
}

class _ChatMsg {
  _ChatMsg.bot(this.text) : isBot = true;
  _ChatMsg.user(this.text) : isBot = false;

  final String text;
  final bool isBot;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.palette});

  final _ChatMsg msg;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final isBot = msg.isBot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: isBot ? palette.surface : palette.fg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isBot ? 4 : 12),
                bottomRight: Radius.circular(isBot ? 12 : 4),
              ),
              border: Border.all(color: palette.line),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isBot ? palette.fg : palette.bg,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextReply extends StatelessWidget {
  const _TextReply({
    required this.controller,
    required this.hint,
    required this.onChange,
    required this.onSubmit,
    required this.palette,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChange;
  final VoidCallback? onSubmit;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChange,
            onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.fg, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: palette.fg,
            foregroundColor: palette.bg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: const Icon(Icons.arrow_forward, size: 18),
        ),
      ],
    );
  }
}

class _ChipsReply extends StatelessWidget {
  const _ChipsReply({
    required this.options,
    required this.selected,
    required this.allowMultiple,
    required this.onPick,
    required this.customOpen,
    required this.onToggleCustom,
    required this.customCtrl,
    required this.onSubmitCustom,
    required this.palette,
    required this.submitLabel,
    this.onSubmit,
  });

  final List<String> options;
  final List<String> selected;
  final bool allowMultiple;
  final ValueChanged<String> onPick;
  final bool customOpen;
  final VoidCallback? onToggleCustom;
  final TextEditingController? customCtrl;
  final VoidCallback? onSubmitCustom;
  final NoeticaPalette palette;
  final String? submitLabel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final selLower = selected.map((e) => e.toLowerCase()).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              _Chip(
                label: opt,
                selected: selLower.contains(opt.toLowerCase()),
                onTap: () => onPick(opt),
                palette: palette,
              ),
            for (final picked in selected)
              if (!options
                  .any((o) => o.toLowerCase() == picked.toLowerCase()))
                _Chip(
                  label: picked,
                  selected: true,
                  onTap: () => onPick(picked),
                  palette: palette,
                ),
            if (onToggleCustom != null)
              _Chip(
                label: customOpen ? '× своё' : '+ своё',
                selected: customOpen,
                onTap: onToggleCustom!,
                palette: palette,
              ),
          ],
        ),
        if (customOpen && customCtrl != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customCtrl,
                  autofocus: true,
                  onSubmitted: (_) => onSubmitCustom?.call(),
                  decoration: InputDecoration(
                    hintText: 'Своё значение',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: palette.fg, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add, color: palette.fg),
                onPressed: onSubmitCustom,
              ),
            ],
          ),
        ],
        if (allowMultiple && submitLabel != null) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: palette.fg,
              foregroundColor: palette.bg,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(submitLabel!),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.fg : palette.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? palette.fg : palette.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.bg : palette.fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LevelsReply extends StatelessWidget {
  const _LevelsReply({
    required this.interests,
    required this.levels,
    required this.activeIdx,
    required this.onLevel,
    required this.onActive,
    required this.onSubmit,
    required this.palette,
  });

  final List<String> interests;
  final Map<String, String> levels;
  final int activeIdx;
  final void Function(String interest, String level) onLevel;
  final ValueChanged<int> onActive;
  final VoidCallback? onSubmit;
  final NoeticaPalette palette;

  static const _levelLabels = <String, String>{
    'novice': 'Новичок',
    'learning': 'Учусь',
    'confident': 'Уверенно',
    'expert': 'Эксперт',
  };

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final interest = interests[i];
              return _Chip(
                label: interest,
                selected: i == activeIdx,
                onTap: () => onActive(i),
                palette: palette,
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemCount: interests.length,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in kInterestLevels)
              _Chip(
                label: _levelLabels[level] ?? level,
                selected:
                    (levels[interests[activeIdx]] ?? 'novice') == level,
                onTap: () => onLevel(interests[activeIdx], level),
                palette: palette,
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: palette.fg,
            foregroundColor: palette.bg,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Далее'),
        ),
      ],
    );
  }
}

class _HoursReply extends StatelessWidget {
  const _HoursReply({
    required this.options,
    required this.selected,
    required this.onPick,
    required this.palette,
  });

  final List<int> options;
  final int selected;
  final ValueChanged<int> onPick;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final h in options)
          _Chip(
            label: '$h ч/нед',
            selected: h == selected,
            onTap: () => onPick(h),
            palette: palette,
          ),
      ],
    );
  }
}
