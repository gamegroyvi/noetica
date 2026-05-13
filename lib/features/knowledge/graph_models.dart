import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/models.dart';

// ---------------------------------------------------------------------------
// Branch enum — PersonalKnowledge categories shown as branch headers.
// ---------------------------------------------------------------------------

enum GraphBranch {
  goals,
  constraints,
  highlights,
  reflections,
  preferences,
}

extension GraphBranchX on GraphBranch {
  String localTitle(S tr) {
    switch (this) {
      case GraphBranch.goals:
        return tr.graphBranchGoals;
      case GraphBranch.constraints:
        return tr.graphBranchConstraints;
      case GraphBranch.highlights:
        return tr.graphBranchHighlights;
      case GraphBranch.reflections:
        return tr.graphBranchReflections;
      case GraphBranch.preferences:
        return tr.graphBranchPreferences;
    }
  }

  Color get color {
    switch (this) {
      case GraphBranch.goals:
        return const Color(0xFF1A1A1A);
      case GraphBranch.constraints:
        return const Color(0xFF555555);
      case GraphBranch.highlights:
        return const Color(0xFF333333);
      case GraphBranch.reflections:
        return const Color(0xFF777777);
      case GraphBranch.preferences:
        return const Color(0xFF444444);
    }
  }
}

// ---------------------------------------------------------------------------
// Graph node — a single point in the force-directed simulation.
// ---------------------------------------------------------------------------

class GraphNode {
  GraphNode({
    required this.id,
    required this.label,
    required this.color,
    required this.isCentre,
    this.entry,
    this.isBookmarked = false,
    this.isBranchHeader = false,
    this.isLeaf = false,
    this.branch,
    this.leafIndex = -1,
    this.tags = const [],
    Offset? position,
  })  : pos = position ?? Offset.zero,
        vel = Offset.zero;

  final String id;
  final String label;
  final Color color;
  final bool isCentre;
  final Entry? entry;
  final bool isBookmarked;
  final bool isBranchHeader;
  final bool isLeaf;
  final GraphBranch? branch;
  final int leafIndex;
  final List<String> tags;
  int linkCount = 0;
  int childCount = 0;
  Offset pos;
  Offset vel;
  bool pinned = false;

  double get radius {
    if (isCentre) return 18;
    if (isBranchHeader) return 12;
    if (isBookmarked) return 13;
    if (isLeaf) return 7;
    final base = 6.0 + math.min(linkCount * 1.5, 8.0);
    return base;
  }
}

class GraphEdge {
  const GraphEdge(this.from, this.to);
  final int from;
  final int to;
}

// ---------------------------------------------------------------------------
// Force-directed simulation parameters.
// ---------------------------------------------------------------------------

const double kGraphRepulsion = 8000;
const double kGraphSpringK = 0.012;
const double kGraphSpringLen = 140;
const double kGraphDamping = 0.85;
const double kGraphMinVelocity = 0.05;
const double kGraphMaxForce = 80;
const double kGraphCentreGravity = 0.0008;

// ---------------------------------------------------------------------------
// Color palette for entry types.
// ---------------------------------------------------------------------------

Color entryColor(Entry? e) {
  if (e == null) return const Color(0xFFAAAAAA);
  if (e.bookmarked) return const Color(0xFFF59E0B);
  if (e.tags.contains('daily')) return const Color(0xFF3B82F6);
  if (e.isTask) return const Color(0xFF06B6D4);
  return const Color(0xFF10B981);
}

// ---------------------------------------------------------------------------
// Filter modes.
// ---------------------------------------------------------------------------

enum GraphFilterMode { all, notes, tasks, bookmarks, daily, knowledge }

extension GraphFilterModeX on GraphFilterMode {
  String localLabel(S tr) {
    switch (this) {
      case GraphFilterMode.all:
        return tr.graphFilterAll;
      case GraphFilterMode.notes:
        return tr.graphFilterNotes;
      case GraphFilterMode.tasks:
        return tr.graphFilterTasks;
      case GraphFilterMode.bookmarks:
        return tr.graphFilterBookmarks;
      case GraphFilterMode.daily:
        return tr.graphFilterDaily;
      case GraphFilterMode.knowledge:
        return tr.graphFilterKnowledge;
    }
  }

  IconData get icon {
    switch (this) {
      case GraphFilterMode.all:
        return Icons.blur_on;
      case GraphFilterMode.notes:
        return Icons.note_outlined;
      case GraphFilterMode.tasks:
        return Icons.checklist;
      case GraphFilterMode.bookmarks:
        return Icons.bookmark_outline;
      case GraphFilterMode.daily:
        return Icons.today;
      case GraphFilterMode.knowledge:
        return Icons.account_tree_outlined;
    }
  }

  bool get showsKnowledgeBranches {
    switch (this) {
      case GraphFilterMode.all:
      case GraphFilterMode.knowledge:
        return true;
      case GraphFilterMode.notes:
      case GraphFilterMode.tasks:
      case GraphFilterMode.bookmarks:
      case GraphFilterMode.daily:
        return false;
    }
  }

  bool get showsEntries {
    switch (this) {
      case GraphFilterMode.all:
      case GraphFilterMode.notes:
      case GraphFilterMode.tasks:
      case GraphFilterMode.bookmarks:
      case GraphFilterMode.daily:
        return true;
      case GraphFilterMode.knowledge:
        return false;
    }
  }
}
