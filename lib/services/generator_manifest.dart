import 'package:flutter/material.dart';

import 'generator_input.dart';

/// Lifecycle of a generator from the user's point of view.
///
/// `available` cards are tappable; `beta` are tappable but show a hint
/// about possible breakage; `soon` are placeholders with a "Coming"
/// pill, the tap shows a snackbar.
enum GeneratorStatus { available, beta, soon }

/// Source of a manifest. Currently every manifest is `builtin`
/// (compiled into the app); future phases will add `user` (created in
/// the in-app authoring wizard, stored locally) and `marketplace`
/// (downloaded from the catalog backend).
enum GeneratorSource { builtin, user, marketplace }

/// Declarative description of an AI-tool / generator. The runtime
/// (form → preview → import) will eventually be driven entirely by
/// this manifest — see `noetica-user-agents-design.md` for the full
/// schema. For now we only describe **how the catalog row looks**
/// (icon / title / description / bullets / status) and a `builder`
/// callback for tools that already have their own bespoke screen
/// (the existing «Меню недели» generator). Once the universal runtime
/// lands the bespoke `builder` field will go away.
@immutable
class GeneratorManifest {
  const GeneratorManifest({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.category = '',
    this.bullets = const [],
    this.source = GeneratorSource.builtin,
    this.author = '',
    this.inputs = const [],
    this.builder,
  });

  /// Stable identifier used for analytics, deep-links and the future
  /// `menu/<menuId>` style grouping tag. Format: `<source>/<slug>`
  /// for non-builtin sources; bare slug for builtins.
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final GeneratorStatus status;
  final String category;
  final List<String> bullets;
  final GeneratorSource source;
  final String author;

  /// Declarative form schema. Empty for tools that still have a
  /// hand-coded screen (`builder` non-null). Once a generator's
  /// inputs are described here, the universal `GeneratorFormView`
  /// can render the form without per-tool code.
  final List<GeneratorInputField> inputs;

  /// Optional bespoke screen builder. Used while we migrate hand-coded
  /// generators to the manifest runtime — not part of the long-term
  /// schema. `null` means "render with the universal runtime", which
  /// today only works for tools that have a typed manifest body.
  final WidgetBuilder? builder;

  bool get isInteractable =>
      status == GeneratorStatus.available || status == GeneratorStatus.beta;
}

/// Read-only catalog of generators known to the app. The list is the
/// union of compiled-in builtins and (eventually) user / marketplace
/// manifests. UI code should not assume any particular ordering — it
/// groups by `status` and `source` itself.
abstract class GeneratorRegistry {
  List<GeneratorManifest> list();

  /// Convenience views.
  Iterable<GeneratorManifest> get available =>
      list().where((m) => m.status == GeneratorStatus.available);
  Iterable<GeneratorManifest> get beta =>
      list().where((m) => m.status == GeneratorStatus.beta);
  Iterable<GeneratorManifest> get soon =>
      list().where((m) => m.status == GeneratorStatus.soon);

  GeneratorManifest? findById(String id) {
    for (final m in list()) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// In-process registry holding only the compiled-in builtins. Future
/// phases will compose a `CompositeRegistry` that reads from this
/// builtin registry plus a `UserGeneratorRegistry` (SharedPreferences
/// backed) plus a `MarketplaceRegistry` (network backed).
class BuiltinGeneratorRegistry extends GeneratorRegistry {
  BuiltinGeneratorRegistry(this._items);

  final List<GeneratorManifest> _items;

  @override
  List<GeneratorManifest> list() => List.unmodifiable(_items);
}
