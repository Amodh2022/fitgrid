import 'package:flutter/foundation.dart';

import '../model/row_model.dart';

/// How rows are grouped or nested, and which of the groups are open.
///
/// Expansion is stored as the set of keys that differ from the default rather
/// than as the set that is open. That way a new group arriving in the data
/// comes in open or closed according to its policy, instead of silently
/// collapsing because nobody had ever expanded a key that did not exist yet.
class FitGridGroupingState<T> extends ChangeNotifier {
  List<FitGridGroup<T>> _groups = <FitGridGroup<T>>[];

  /// The grouping levels, outermost first. Empty means no grouping.
  List<FitGridGroup<T>> get groups =>
      List<FitGridGroup<T>>.unmodifiable(_groups);
  set groups(List<FitGridGroup<T>> value) {
    _groups = List<FitGridGroup<T>>.of(value);
    _toggled.clear();
    notifyListeners();
  }

  FitGridTree<T>? _tree;

  /// Turns the rows into a hierarchy. Mutually exclusive with [groups]: a
  /// grouped tree is two answers to the same question.
  FitGridTree<T>? get tree => _tree;
  set tree(FitGridTree<T>? value) {
    if (identical(_tree, value)) return;
    _tree = value;
    _toggled.clear();
    notifyListeners();
  }

  bool get isActive => _groups.isNotEmpty || _tree != null;

  /// Keys whose state differs from the default.
  final Set<Object> _toggled = <Object>{};

  int _expansionRevision = 0;

  /// Bumped whenever anything about the expansion changes. The grid folds it
  /// into the cache key for the flattened display lines, because a `Set` has no
  /// cheap identity to compare instead.
  int get expansionRevision => _expansionRevision;

  @override
  void notifyListeners() {
    _expansionRevision++;
    super.notifyListeners();
  }

  /// Set by [expandAll] and [collapseAll], which are answers about every key
  /// rather than about any particular one, and so cannot be expressed as a set.
  bool? _allExpanded;

  bool get _defaultExpanded =>
      _allExpanded ??
      _tree?.initiallyExpanded ??
      (_groups.isEmpty ? true : _groups.first.initiallyExpanded);

  bool isExpanded(Object key) =>
      _toggled.contains(key) ? !_defaultExpanded : _defaultExpanded;

  void toggle(Object key) {
    if (!_toggled.remove(key)) _toggled.add(key);
    notifyListeners();
  }

  void setExpanded(Object key, bool expanded) {
    if (isExpanded(key) == expanded) return;
    toggle(key);
  }

  /// Opens everything, including groups nobody has seen yet.
  void expandAll() {
    _toggled.clear();
    _allExpanded = true;
    notifyListeners();
  }

  void collapseAll() {
    _toggled.clear();
    _allExpanded = false;
    notifyListeners();
  }

  /// Resets to the per-group policy, forgetting both the overrides and any
  /// [expandAll] or [collapseAll].
  void reset() {
    _toggled.clear();
    _allExpanded = null;
    notifyListeners();
  }
}
