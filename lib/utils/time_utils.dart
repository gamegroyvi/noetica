import 'package:intl/intl.dart';

String formatTimestamp(DateTime t) {
  final df = DateFormat('d MMM, HH:mm', 'ru');
  return df.format(t);
}

String formatDateOnly(DateTime t) {
  final df = DateFormat('d MMMM yyyy', 'ru');
  return df.format(t);
}

/// Human-readable gap between two timestamps, e.g. "через 3 дня",
/// "5 часов назад". Russian, plural-aware (rough — good enough for MVP).
String formatGap(Duration d) {
  final abs = d.abs();
  final past = d.isNegative;
  String unit;
  int value;
  if (abs.inDays >= 1) {
    value = abs.inDays;
    unit = _pluralRu(value, 'день', 'дня', 'дней');
  } else if (abs.inHours >= 1) {
    value = abs.inHours;
    unit = _pluralRu(value, 'час', 'часа', 'часов');
  } else if (abs.inMinutes >= 1) {
    value = abs.inMinutes;
    unit = _pluralRu(value, 'минута', 'минуты', 'минут');
  } else {
    return past ? 'только что' : 'сейчас';
  }
  return past ? '$value $unit назад' : 'через $value $unit';
}

/// Gap "since previous entry" rendered as a soft label.
String formatGapSince(DateTime current, DateTime previous) {
  final d = current.difference(previous).abs();
  if (d.inMinutes < 1) return 'сразу после';
  if (d.inHours < 1) {
    final m = d.inMinutes;
    return '+ $m ${_pluralRu(m, 'минута', 'минуты', 'минут')}';
  }
  if (d.inDays < 1) {
    final h = d.inHours;
    return '+ $h ${_pluralRu(h, 'час', 'часа', 'часов')}';
  }
  if (d.inDays < 30) {
    final v = d.inDays;
    return '+ $v ${_pluralRu(v, 'день', 'дня', 'дней')}';
  }
  if (d.inDays < 365) {
    final v = (d.inDays / 30).round();
    return '+ $v ${_pluralRu(v, 'месяц', 'месяца', 'месяцев')}';
  }
  final v = (d.inDays / 365).round();
  return '+ $v ${_pluralRu(v, 'год', 'года', 'лет')}';
}

String _pluralRu(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
