import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/l10n/generated/app_localizations_ru.dart';
import 'package:noetica/services/pomodoro_service.dart';

void main() {
  final tr = SRu();

  group('PomodoroPhase', () {
    test('storage keys are stable wire-format strings', () {
      expect(PomodoroPhase.idle.storage, 'idle');
      expect(PomodoroPhase.focus.storage, 'focus');
      expect(PomodoroPhase.breakTime.storage, 'break');
      expect(PomodoroPhase.longBreak.storage, 'long_break');
    });

    test('localizedLabel returns non-empty strings for all phases', () {
      for (final phase in PomodoroPhase.values) {
        final label = phase.localizedLabel(tr);
        expect(label, isNotEmpty,
            reason: '${phase.name} should have a non-empty label');
      }
    });

    test('idle label is always "Pomodoro"', () {
      expect(PomodoroPhase.idle.localizedLabel(tr), 'Pomodoro');
    });

    test('focus label uses translation key', () {
      final label = PomodoroPhase.focus.localizedLabel(tr);
      expect(label, isNotEmpty);
      expect(label, isNot('focus'));
    });
  });

  group('PomodoroService', () {
    test('singleton instance is always the same', () {
      expect(
        identical(PomodoroService.instance, PomodoroService.instance),
        isTrue,
      );
    });

    test('updateLocale does not throw', () {
      expect(
        () => PomodoroService.instance.updateLocale(tr),
        returnsNormally,
      );
    });
  });
}
