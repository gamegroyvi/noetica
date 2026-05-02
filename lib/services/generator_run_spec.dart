import 'package:flutter/foundation.dart';

/// What the universal `GeneratorRunScreen` should do with the items the
/// LLM returns. Authored once per manifest; consumed by the import
/// step.
@immutable
class GeneratorImportSpec {
  const GeneratorImportSpec({
    this.importAs = GeneratorImportTarget.task,
    this.dueStrategy = GeneratorDueStrategy.today,
    this.dueHourLocal = 9,
    this.axisIdInputId,
    this.tagPrefix = '',
    this.xpPerItem = 5,
  });

  /// What kind of entry to create per item.
  final GeneratorImportTarget importAs;

  /// How to compute `dueAt` for created tasks.
  final GeneratorDueStrategy dueStrategy;

  /// Hour of day (local time) to pin tasks to when `dueStrategy` is
  /// `today`/`ladder`/`respectOffset`. Default 09:00 keeps imports in
  /// "Сегодня"/"Завтра"/etc instead of midnight overdue.
  final int dueHourLocal;

  /// Form-field id whose value is an axis id. The picked axis is
  /// attached to created entries. Null = no axis link.
  final String? axisIdInputId;

  /// Prefix for the `runId`-suffixed tag stamped on every created
  /// entry (e.g. `'challenge'` → `challenge/abc123`). Empty string
  /// disables the prefixed tag and only the manifest-id tag is used.
  final String tagPrefix;

  /// XP awarded per task (only used when `importAs == task`).
  final int xpPerItem;
}

/// Where each generated item ends up.
enum GeneratorImportTarget { task, note }

/// How the universal runtime computes `dueAt` per item.
///
/// - `none`: items become entries without a due date.
/// - `today`: every item is due today at `dueHourLocal`.
/// - `ladder`: items 1..N are due day 0, day 1, day 2 … starting today.
/// - `respectOffset`: each item's `due_offset_days` (from the LLM) is
///   honored; items without an offset are placed today.
enum GeneratorDueStrategy { none, today, ladder, respectOffset }

/// Single item from `/tools/run`. Mirrors backend `GeneratorItem`.
@immutable
class GeneratorRunItem {
  const GeneratorRunItem({
    required this.title,
    this.body = '',
    this.dueOffsetDays,
  });

  final String title;
  final String body;
  final int? dueOffsetDays;

  factory GeneratorRunItem.fromJson(Map<String, Object?> json) {
    final off = json['due_offset_days'];
    int? offset;
    if (off is int) {
      offset = off;
    } else if (off is num) {
      offset = off.toInt();
    }
    return GeneratorRunItem(
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      dueOffsetDays: offset,
    );
  }
}

/// Result envelope returned by `/tools/run`. Mirrors backend
/// `GeneratorRunResponse`.
@immutable
class GeneratorRunResult {
  const GeneratorRunResult({
    required this.model,
    this.summary = '',
    this.items = const [],
  });

  final String model;
  final String summary;
  final List<GeneratorRunItem> items;

  factory GeneratorRunResult.fromJson(Map<String, Object?> json) =>
      GeneratorRunResult(
        model: (json['model'] as String?) ?? '',
        summary: (json['summary'] as String?) ?? '',
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map<String, Object?>>()
            .map(GeneratorRunItem.fromJson)
            .toList(),
      );
}
