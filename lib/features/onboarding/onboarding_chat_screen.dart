import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/personal_knowledge_service.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';

class OnboardingChatScreen extends ConsumerStatefulWidget {
  const OnboardingChatScreen({super.key, this.existing, this.onDone});

  final UserProfile? existing;
  final VoidCallback? onDone;

  @override
  ConsumerState<OnboardingChatScreen> createState() =>
      _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends ConsumerState<OnboardingChatScreen> {
  static const int _stepCount = 7;
  int _step = 0;

  String _name = '';
  String _persona = '';
  final List<String> _aspirations = [];
  final List<String> _interests = [];
  final Map<String, String> _interestLevels = {};
  final List<String> _painPoints = [];
  int _weeklyHours = 5;
  final List<String> _windows = [];
  String _supportStyle = '';

  final List<_ChatMsg> _thread = [];

  final _textCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  bool _customOpen = false;
  int _levelIdx = 0;
  bool _saving = false;

  static const _personaOptions = <String>[
    'студент / учусь',
    'джун / меняю карьеру',
    'фаундер / свой проект',
    'работаю и выгораю',
    'хочу дисциплину',
    'ищу новый вектор',
  ];
  static const _aspirationOptions = <String>[
    'выйти на новую работу',
    'запустить проект',
    'стать стабильнее',
    'восстановить энергию',
    'прокачать навык',
    'навести порядок в жизни',
    'найти фокус',
  ];
  static const _interestOptions = <String>[
    'карьера / учёба',
    'проект / бизнес',
    'здоровье / энергия',
    'дисциплина / ритм',
    'отношения',
    'деньги',
    'творчество',
    'спокойствие',
    'навыки / обучение',
    'дом / быт',
    'сообщество',
    'смысл',
  ];
  static const _painOptions = <String>[
    'хаос в голове',
    'прокрастинация',
    'усталость',
    'нет понятного плана',
    'не хватает времени',
    'распыление',
    'перфекционизм',
    'выгорание',
    'отвлечения',
    'нет поддержки',
  ];
  static const _windowOptions = <String>[
    'утром',
    'днём',
    'вечером',
    'ночью',
    'в выходные',
  ];
  static const _supportOptions = <String>[
    'мягко и без давления',
    'чётко и по делу',
    'как строгий тренер',
    'маленькими шагами',
    'с челленджами',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name = e.name;
      if (e.aspiration.trim().isNotEmpty) {
        _aspirations.addAll(
          e.aspiration
              .split(RegExp(r'[;,]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }
      _interests.addAll(e.interests);
      _interestLevels.addAll(e.interestLevels);
      _painPoints.addAll(
        e.painPoint.isNotEmpty
            ? e.painPoint.split(',').map((s) => s.trim())
            : const [],
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
        return 'Привет. Я быстро соберу контекст, чтобы AI не давал generic-план. Как тебя зовут и где ты сейчас?';
      case 1:
        return _name.isNotEmpty
            ? 'Окей, ${_firstName(_name)}. Куда целимся в ближайшие 3–12 месяцев?'
            : 'Куда целимся в ближайшие 3–12 месяцев?';
      case 2:
        return 'Какие 3–8 сфер сильнее всего влияют на эту цель и качество жизни?';
      case 3:
        return 'Если хочешь, уточни уровень по сферам. Так задачи будут не слишком лёгкими и не слишком тяжёлыми.';
      case 4:
        return 'Что сейчас чаще всего ломает прогресс? Можно несколько.';
      case 5:
        return 'Сколько часов в неделю реально есть без самообмана?';
      case 6:
        return 'Когда удобнее работать и каким тоном тебя поддерживать?';
      default:
        return '';
    }
  }

  String _firstName(String full) =>
      full.trim().isEmpty ? '' : full.trim().split(RegExp(r'\s+')).first;

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _name.trim().isNotEmpty && _persona.trim().isNotEmpty;
      case 1:
        return _aspirations.isNotEmpty;
      case 2:
        return _interests.length >= 3;
      case 3:
        return true;
      case 4:
        return true;
      case 5:
        return _weeklyHours > 0;
      case 6:
        return _windows.isNotEmpty && _supportStyle.trim().isNotEmpty;
    }
    return false;
  }

  String _userReplyFor(int step) {
    switch (step) {
      case 0:
        return '${_name.trim()}; сейчас: $_persona';
      case 1:
        return _aspirations.join('; ');
      case 2:
        return _interests.join(', ');
      case 3:
        final rated = _interests
            .where((i) => kInterestLevels.contains(_interestLevels[i]))
            .map((i) => '$i: ${_levelRu(_interestLevels[i]!)}')
            .join('; ');
        return rated.isEmpty ? 'пропустить грейды' : rated;
      case 4:
        return _painPoints.isEmpty ? 'ничего особенно' : _painPoints.join(', ');
      case 5:
        return '$_weeklyHours ч/нед';
      case 6:
        return '${_windows.join(', ')}; стиль: $_supportStyle';
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
    AnalyticsService.instance.track(AnalyticsEvents.onboardingStepCompleted, {
      'step': _step,
    });
    if (_step >= _stepCount - 1) {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _thread
        ..removeLast()
        ..removeLast();
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
          if (kInterestLevels.contains(_interestLevels[i]))
            i: _interestLevels[i]!,
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
      final contextLines = <String>[
        if (_persona.isNotEmpty) 'Контекст: $_persona',
        if (_supportStyle.isNotEmpty) 'Стиль поддержки: $_supportStyle',
        if (_windows.isNotEmpty) 'Время: ${_windows.join(", ")}',
      ];
      final profile = base.copyWith(
        name: _name.trim(),
        aspiration: _aspirations.join('; '),
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
          ...contextLines,
          'В неделю на развитие: ~${profile.weeklyHours} ч',
          if (_painPoints.isNotEmpty) 'Что мешает: ${_painPoints.join(", ")}',
        ],
      );
      AnalyticsService.instance.track(AnalyticsEvents.onboardingCompleted);
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
      if (_persona.isNotEmpty) 'Сейчас: $_persona.',
      if (profile.aspiration.isNotEmpty) 'Цель: ${profile.aspiration}.',
      if (levelsBlurb.isNotEmpty) 'Сейчас: $levelsBlurb.',
      if (_painPoints.isNotEmpty) 'Что мешает: ${_painPoints.join(", ")}.',
      'Готов уделять около ${profile.weeklyHours} ч/нед.',
      if (_windows.isNotEmpty) 'Удобное время: ${_windows.join(", ")}.',
      if (_supportStyle.isNotEmpty) 'Нужный стиль поддержки: $_supportStyle.',
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
        return _IdentityReply(
          controller: _textCtrl,
          personaOptions: _personaOptions,
          selectedPersona: _persona,
          onNameChange: (v) => setState(() => _name = v),
          onPersona: (v) => setState(() => _persona = v),
          onSubmit: _canAdvance ? _advance : null,
          palette: palette,
        );
      case 1:
        return _ChipsReply(
          options: _aspirationOptions,
          selected: _aspirations,
          allowMultiple: true,
          onPick: (v) => setState(() {
            final idx = _aspirations
                .indexWhere((e) => e.toLowerCase() == v.toLowerCase());
            if (idx >= 0) {
              _aspirations.removeAt(idx);
            } else if (_aspirations.length < 6) {
              _aspirations.add(v);
            }
          }),
          customOpen: _customOpen,
          onToggleCustom: () => setState(() => _customOpen = !_customOpen),
          customCtrl: _customCtrl,
          onSubmitCustom: () {
            final v = _customCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() {
              if (_aspirations
                      .where((e) => e.toLowerCase() == v.toLowerCase())
                      .isEmpty &&
                  _aspirations.length < 6) {
                _aspirations.add(v);
              }
              _customOpen = false;
              _customCtrl.clear();
            });
          },
          palette: palette,
          submitLabel: _aspirations.isEmpty ? 'Выбери хотя бы одну' : 'Далее',
          onSubmit: _aspirations.isEmpty ? null : _advance,
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
            }
          }),
          customOpen: _customOpen,
          onToggleCustom: () => setState(() => _customOpen = !_customOpen),
          customCtrl: _customCtrl,
          onSubmitCustom: () {
            final v = _customCtrl.text.trim();
            if (v.isEmpty) return;
            setState(() {
              if (_interests
                      .where((e) => e.toLowerCase() == v.toLowerCase())
                      .isEmpty &&
                  _interests.length < 12) {
                _interests.add(v);
              }
              _customOpen = false;
              _customCtrl.clear();
            });
          },
          palette: palette,
          submitLabel:
              _canAdvance ? 'Далее' : 'Выбери ещё ${3 - _interests.length}',
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
          onToggleCustom: () => setState(() => _customOpen = !_customOpen),
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
          value: _weeklyHours.clamp(1, 60),
          onChanged: (v) => setState(() => _weeklyHours = v),
          onSubmit: _canAdvance ? _advance : null,
          palette: palette,
        );
      case 6:
        return _CadenceReply(
          windowOptions: _windowOptions,
          selectedWindows: _windows,
          supportOptions: _supportOptions,
          selectedSupport: _supportStyle,
          onWindow: (v) => setState(() {
            final idx =
                _windows.indexWhere((e) => e.toLowerCase() == v.toLowerCase());
            if (idx >= 0) {
              _windows.removeAt(idx);
            } else {
              _windows.add(v);
            }
          }),
          onSupport: (v) => setState(() => _supportStyle = v),
          palette: palette,
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

class _IdentityReply extends StatelessWidget {
  const _IdentityReply({
    required this.controller,
    required this.personaOptions,
    required this.selectedPersona,
    required this.onNameChange,
    required this.onPersona,
    required this.onSubmit,
    required this.palette,
  });

  final TextEditingController controller;
  final List<String> personaOptions;
  final String selectedPersona;
  final ValueChanged<String> onNameChange;
  final ValueChanged<String> onPersona;
  final VoidCallback? onSubmit;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          onChanged: onNameChange,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
          decoration: InputDecoration(
            hintText: 'Имя',
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
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Что ближе к твоей ситуации?',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in personaOptions)
              _Chip(
                label: opt,
                selected: selectedPersona == opt,
                onTap: () => onPersona(opt),
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
          child: Text(onSubmit == null ? 'Введи имя и контекст' : 'Далее'),
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
              if (!options.any((o) => o.toLowerCase() == picked.toLowerCase()))
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
                      borderSide: BorderSide(color: palette.fg, width: 1.5),
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
          AnimatedBuilder(
            animation: customCtrl ?? const AlwaysStoppedAnimation(0),
            builder: (context, _) {
              final pendingCustom =
                  customOpen && (customCtrl?.text.trim().isNotEmpty ?? false);
              final canAdvance =
                  onSubmit != null || (pendingCustom && onSubmitCustom != null);
              return FilledButton(
                onPressed: canAdvance
                    ? () {
                        if (pendingCustom) {
                          onSubmitCustom?.call();
                        }
                        if (onSubmit != null) {
                          onSubmit!();
                        } else if (pendingCustom) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onSubmit?.call();
                          });
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.fg,
                  foregroundColor: palette.bg,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(submitLabel!),
              );
            },
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
  static const _levelHints = <String, String>{
    'novice': 'только начинаю',
    'learning': 'в процессе',
    'confident': 'уверенно справляюсь',
    'expert': 'давно в теме',
  };

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();
    final clampedIdx = activeIdx.clamp(0, interests.length - 1);
    final active = interests[clampedIdx];
    final activeLevel = levels[active];
    final rated = interests.where((i) => levels[i] != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Шаг 1 — выбери сферу (вверху).  Шаг 2 — поставь грейд (внизу).',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final interest = interests[i];
              final isActive = i == clampedIdx;
              final isRated = levels[interest] != null;
              return _InterestPill(
                label: interest,
                active: isActive,
                rated: isRated,
                onTap: () => onActive(i),
                palette: palette,
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: interests.length,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'оценено $rated/${interests.length}',
          style: TextStyle(color: palette.muted, fontSize: 11),
        ),
        const SizedBox(height: 18),
        Text(
          'Твой уровень в «$active»',
          style: TextStyle(
            color: palette.fg,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            for (final level in kInterestLevels) ...[
              _LevelCard(
                label: _levelLabels[level] ?? level,
                hint: _levelHints[level] ?? '',
                selected: activeLevel == level,
                onTap: () => onLevel(active, level),
                palette: palette,
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: palette.fg,
            foregroundColor: palette.bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            rated == 0 ? 'Пропустить грейды' : 'Далее',
          ),
        ),
      ],
    );
  }
}

class _InterestPill extends StatelessWidget {
  const _InterestPill({
    required this.label,
    required this.active,
    required this.rated,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool active;
  final bool rated;
  final VoidCallback onTap;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final bg = active ? palette.fg : palette.surface;
    final fg = active ? palette.bg : palette.fg;
    final borderColor = active ? palette.fg : palette.line;
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(color: borderColor, width: active ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rated) ...[
                Icon(Icons.check, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.fg.withOpacity(0.08) : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? palette.fg : palette.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.fg : palette.line,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.fg,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: palette.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (hint.isNotEmpty)
                      Text(
                        hint,
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CadenceReply extends StatelessWidget {
  const _CadenceReply({
    required this.windowOptions,
    required this.selectedWindows,
    required this.supportOptions,
    required this.selectedSupport,
    required this.onWindow,
    required this.onSupport,
    required this.onSubmit,
    required this.palette,
  });

  final List<String> windowOptions;
  final List<String> selectedWindows;
  final List<String> supportOptions;
  final String selectedSupport;
  final ValueChanged<String> onWindow;
  final ValueChanged<String> onSupport;
  final VoidCallback? onSubmit;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final selectedLower = selectedWindows.map((e) => e.toLowerCase()).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Когда лучше ставить задачи?',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in windowOptions)
              _Chip(
                label: opt,
                selected: selectedLower.contains(opt.toLowerCase()),
                onTap: () => onWindow(opt),
                palette: palette,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Какой стиль поддержки нужен?',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in supportOptions)
              _Chip(
                label: opt,
                selected: selectedSupport == opt,
                onTap: () => onSupport(opt),
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
          child: Text(onSubmit == null ? 'Выбери время и стиль' : 'Готово'),
        ),
      ],
    );
  }
}

class _HoursReply extends StatelessWidget {
  const _HoursReply({
    required this.value,
    required this.onChanged,
    required this.onSubmit,
    required this.palette,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onSubmit;
  final NoeticaPalette palette;

  String _hint(int v) {
    if (v <= 3) return 'мини-объём, по чуть-чуть';
    if (v <= 8) return 'комфортный темп';
    if (v <= 15) return 'серьёзная вовлечённость';
    if (v <= 25) return 'почти второй джоб';
    return 'максимальный режим';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontFamily: 'IBMPlexMono',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: palette.fg,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'ч/нед',
              style: TextStyle(
                fontFamily: 'IBMPlexMono',
                fontSize: 14,
                color: palette.muted,
              ),
            ),
            const Spacer(),
            Text(
              _hint(value),
              style: TextStyle(
                fontFamily: 'IBMPlexMono',
                fontSize: 11,
                color: palette.muted,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: palette.fg,
            inactiveTrackColor: palette.line,
            thumbColor: palette.fg,
            overlayColor: palette.fg.withOpacity(0.12),
            valueIndicatorColor: palette.fg,
            valueIndicatorTextStyle: TextStyle(
              color: palette.surface,
              fontFamily: 'IBMPlexMono',
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            label: '$value ч',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          children: [
            Text('1',
                style: TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 11,
                    color: palette.muted)),
            const Spacer(),
            Text('60',
                style: TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 11,
                    color: palette.muted)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: palette.fg,
            foregroundColor: palette.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: onSubmit,
          child: const Text('Далее',
              style: TextStyle(
                  fontFamily: 'IBMPlexMono', fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
