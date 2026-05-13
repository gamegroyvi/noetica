import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';

String formatTimestamp(DateTime t) {
  final df = DateFormat('d MMM, HH:mm', 'ru');
  return df.format(t);
}

String formatDateOnly(DateTime t) {
  final df = DateFormat('d MMMM yyyy', 'ru');
  return df.format(t);
}

/// Human-readable gap between two timestamps, e.g. "через 3 дня",
/// "5 часов назад". Plural-aware via ARB translations.
String formatGap(Duration d, BuildContext context) {
  final abs = d.abs();
  final past = d.isNegative;
  final tr = S.of(context)!;
  String unit;
  int value;
  if (abs.inDays >= 1) {
    value = abs.inDays;
    unit = _pluralRu(value, tr.pluralDayOne, tr.pluralDayFew, tr.pluralDayMany);
  } else if (abs.inHours >= 1) {
    value = abs.inHours;
    unit = _pluralRu(value, tr.pluralHourOne, tr.pluralHourFew, tr.pluralHourMany);
  } else if (abs.inMinutes >= 1) {
    value = abs.inMinutes;
    unit = _pluralRu(value, tr.pluralMinuteOne, tr.pluralMinuteFew, tr.pluralMinuteMany);
  } else {
    return past ? tr.timeJustNow : tr.timeNow;
  }
  return past ? tr.timeAgoFmt(value, unit) : tr.timeInFmt(value, unit);
}

/// Gap "since previous entry" rendered as a soft label.
String formatGapSince(DateTime current, DateTime previous, BuildContext context) {
  final d = current.difference(previous).abs();
  final tr = S.of(context)!;
  if (d.inMinutes < 1) return tr.timeRightAfter;
  if (d.inHours < 1) {
    final m = d.inMinutes;
    return tr.timePlusFmt(m, _pluralRu(m, tr.pluralMinuteOne, tr.pluralMinuteFew, tr.pluralMinuteMany));
  }
  if (d.inDays < 1) {
    final h = d.inHours;
    return tr.timePlusFmt(h, _pluralRu(h, tr.pluralHourOne, tr.pluralHourFew, tr.pluralHourMany));
  }
  if (d.inDays < 30) {
    final v = d.inDays;
    return tr.timePlusFmt(v, _pluralRu(v, tr.pluralDayOne, tr.pluralDayFew, tr.pluralDayMany));
  }
  if (d.inDays < 365) {
    final v = (d.inDays / 30).round();
    return tr.timePlusFmt(v, _pluralRu(v, tr.pluralMonthOne, tr.pluralMonthFew, tr.pluralMonthMany));
  }
  final v = (d.inDays / 365).round();
  return tr.timePlusFmt(v, _pluralRu(v, tr.pluralYearOne, tr.pluralYearFew, tr.pluralYearMany));
}

String _pluralRu(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
