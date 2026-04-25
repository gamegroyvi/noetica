import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/personal_knowledge_service.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// Multi-step onboarding questionnaire. Each step has its own validation;
/// the user can only advance if the answer is valid. The whole transition
/// system is animated (slide + fade) and stays strictly black-and-white.
class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key, this.existing, this.onDone});

  /// When editing an existing profile, all fields are pre-filled and the
  /// final action saves the profile in place without continuing to the
  /// axis-onboarding screen.
  final UserProfile? existing;

  /// Called after the questionnaire is fully answered and the profile saved.
  /// When null (default), the screen relies on `profileProvider` invalidation
  /// to let the app's router move to the next screen.
  final VoidCallback? onDone;

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  static const _stepCount = 6;

  int _step = 0;

  // Step 0: name
  final _nameCtrl = TextEditingController();

  // Step 1: aspiration ("Кем хочешь стать через год")
  final _aspirationCtrl = TextEditingController();

  // Step 2: interests (free-form chips, 3..12)
  final List<String> _interests = [];
  final _interestCtrl = TextEditingController();

  // Step 3: skill level per interest (novice/learning/confident/expert).
  // Stored separately from `_interests` so we can default new entries to
  // 'novice' on the fly.
  final Map<String, String> _interestLevels = {};

  // Step 4: pain point (free text, optional)
  final _painCtrl = TextEditingController();

  // Step 5: weekly hours commitment
  int _weeklyHours = 5;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _aspirationCtrl.text = e.aspiration;
      _interests.addAll(e.interests);
      _interestLevels.addAll(e.interestLevels);
      _painCtrl.text = e.painPoint;
      _weeklyHours = e.weeklyHours;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aspirationCtrl.dispose();
    _painCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  void _toggleInterest(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    setState(() {
      final idx = _interests.indexWhere(
        (e) => e.toLowerCase() == v.toLowerCase(),
      );
      if (idx >= 0) {
        final removed = _interests.removeAt(idx);
        _interestLevels.remove(removed);
      } else if (_interests.length < 12) {
        _interests.add(v);
        _interestLevels.putIfAbsent(v, () => 'novice');
      }
    });
  }

  void _commitTypedInterest() {
    final v = _interestCtrl.text.trim();
    if (v.isEmpty) return;
    _toggleInterest(v);
    _interestCtrl.clear();
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return _aspirationCtrl.text.trim().isNotEmpty;
      case 2:
        return _interests.length >= 3 && _interests.length <= 12;
      case 3:
        // Levels default to 'novice' as soon as an interest is added, so
        // the step is always passable. We just need to render the screen
        // so the user can correct defaults.
        return _interests.isNotEmpty;
      case 4:
        return true; // pain point optional
      case 5:
        return _weeklyHours > 0;
      default:
        return false;
    }
  }

  Future<void> _next() async {
    if (!_canAdvance) return;
    if (_step < _stepCount - 1) {
      FocusScope.of(context).unfocus();
      setState(() => _step += 1);
      return;
    }
    await _finish();
  }

  void _back() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step -= 1);
  }

  String _buildKnowledgeSummary(UserProfile profile) {
    final levelsBlurb = profile.interestLevels.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${e.key} (${e.value})')
        .join(', ');
    final parts = <String>[
      if (profile.name.isNotEmpty) 'Зовут ${profile.name}.',
      if (profile.aspiration.isNotEmpty) 'Цель: ${profile.aspiration}.',
      if (levelsBlurb.isNotEmpty) 'Сейчас: $levelsBlurb.',
      if (profile.painPoint.isNotEmpty) 'Что мешает: ${profile.painPoint}.',
      'В неделю готов уделять около ${profile.weeklyHours} часов.',
    ];
    return parts.join(' ');
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
      final profile = (widget.existing ??
              UserProfile(
                name: '',
                aspiration: '',
                interests: const [],
                interestLevels: const {},
                painPoint: '',
                weeklyHours: 5,
                updatedAt: DateTime.now(),
              ))
          .copyWith(
        name: _nameCtrl.text.trim(),
        aspiration: _aspirationCtrl.text.trim(),
        interests: List<String>.from(_interests),
        interestLevels: cleanLevels,
        painPoint: _painCtrl.text.trim(),
        weeklyHours: _weeklyHours,
        updatedAt: DateTime.now(),
      );
      await svc.save(profile);
      // Seed the personal knowledge base with what we just learned in
      // the questionnaire. Future LLM prompts will pull from this
      // document so the model has stable context across sessions.
      final summary = _buildKnowledgeSummary(profile);
      await PersonalKnowledgeService().recordOnboarding(
        summary: summary,
        goals: profile.aspiration.isEmpty ? const [] : [profile.aspiration],
        constraints: [
          'В неделю на развитие: ~${profile.weeklyHours} ч',
          if (profile.painPoint.isNotEmpty)
            'Что мешает: ${profile.painPoint}',
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLast = _step == _stepCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _back,
                      icon: Icon(Icons.arrow_back, color: palette.fg),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                    )
                  else if (widget.existing != null)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: palette.fg),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProgressDots(
                      total: _stepCount,
                      current: _step,
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_step + 1} / $_stepCount',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: _stepBody(palette),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_canAdvance && !_saving) ? _next : null,
                  child: Text(
                    _saving
                        ? '...'
                        : (isLast
                            ? (widget.existing != null
                                ? 'Сохранить'
                                : 'К пентаграмме')
                            : 'Дальше'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(NoeticaPalette palette) {
    switch (_step) {
      case 0:
        return _StepShell(
          eyebrow: 'ЗНАКОМСТВО',
          title: 'Как тебя называть?',
          hint: 'Только для интерфейса. Никуда не уходит.',
          child: TextField(
            controller: _nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _next(),
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(hintText: 'Имя'),
          ),
        );
      case 1:
        return _StepShell(
          eyebrow: 'ЦЕЛЬ',
          title: 'Кем хочешь стать через год?',
          hint: 'Свободный текст: «бегаю 5 раз в неделю», «выпустил книгу», «спокойно отношусь к работе» — что угодно.',
          child: TextField(
            controller: _aspirationCtrl,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Опиши себя через год',
            ),
          ),
        );
      case 2:
        return _StepShell(
          eyebrow: 'РОСТ',
          title: 'В чём хочешь развиваться?',
          hint: 'От 3 до 12 коротких фраз. На их основе AI придумает твои личные оси — никаких фиксированных шаблонов.',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _interestCtrl,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _commitTypedInterest(),
                        decoration: const InputDecoration(
                          hintText: 'Своё направление…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _interests.length < 12
                          ? _commitTypedInterest
                          : null,
                      child: const Text('+ Добавить'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_interests.isNotEmpty) ...[
                  Text(
                    'Твоё (${_interests.length})',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in _interests)
                        _InterestChip(
                          label: v,
                          selected: true,
                          onTap: () => _toggleInterest(v),
                          palette: palette,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  'ПОДСКАЗКИ',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in suggestedInterests)
                      _InterestChip(
                        label: s,
                        selected: _interests.any(
                          (e) => e.toLowerCase() == s.toLowerCase(),
                        ),
                        onTap: () => _toggleInterest(s),
                        palette: palette,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      case 3:
        return _StepShell(
          eyebrow: 'УРОВЕНЬ',
          title: 'Насколько ты уже в этом?',
          hint: 'Это нужно, чтобы план не был ни «копай Hello world», ни «пиши свой компилятор». Можно жать «Дальше» — по умолчанию «Новичок».',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final interest in _interests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _InterestLevelRow(
                      interest: interest,
                      level: _interestLevels[interest] ?? 'novice',
                      palette: palette,
                      onLevelChanged: (lvl) {
                        setState(() => _interestLevels[interest] = lvl);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      case 4:
        return _StepShell(
          eyebrow: 'ПРОСАДКА',
          title: 'Где сейчас тяжело?',
          hint: 'Пропусти, если нечего сказать. Эта запись хранится локально и помогает строить план роста.',
          child: TextField(
            controller: _painCtrl,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Что мешает / где буксует?',
            ),
          ),
        );
      case 5:
        return _StepShell(
          eyebrow: 'РИТМ',
          title: 'Сколько часов в неделю готов вкладывать?',
          hint: 'Это нужно, чтобы план был реалистичным. Среднее по неделе.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_weeklyHours',
                    style: TextStyle(
                      fontSize: 64,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: palette.fg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _hoursWord(_weeklyHours),
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: _weeklyHours.toDouble(),
                min: 1,
                max: 40,
                divisions: 39,
                activeColor: palette.fg,
                inactiveColor: palette.line,
                onChanged: (v) => setState(() => _weeklyHours = v.round()),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1ч', style: TextStyle(color: palette.muted)),
                  Text('40ч+', style: TextStyle(color: palette.muted)),
                ],
              ),
            ],
          ),
        );
    }
    return const SizedBox.shrink();
  }
}

String _hoursWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'час в неделю';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'часа в неделю';
  }
  return 'часов в неделю';
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.eyebrow,
    required this.title,
    required this.hint,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 24),
        Expanded(child: child),
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.total,
    required this.current,
    required this.palette,
  });

  final int total;
  final int current;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: 3,
                decoration: BoxDecoration(
                  color: i <= current ? palette.fg : palette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? palette.fg : palette.bg,
        border: Border.all(color: selected ? palette.fg : palette.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: palette.bg,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? palette.bg : palette.fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestLevelRow extends StatelessWidget {
  const _InterestLevelRow({
    required this.interest,
    required this.level,
    required this.palette,
    required this.onLevelChanged,
  });

  final String interest;
  final String level;
  final NoeticaPalette palette;
  final ValueChanged<String> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          interest,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.fg,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final lvl in kInterestLevels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _LevelPill(
                    label: kInterestLevelLabels[lvl] ?? lvl,
                    selected: level == lvl,
                    palette: palette,
                    onTap: () => onLevelChanged(lvl),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.fg : palette.bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? palette.fg : palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: selected ? palette.bg : palette.fg,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
