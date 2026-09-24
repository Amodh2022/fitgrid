import 'package:flutter/foundation.dart';

/// Which rows have their detail panel open, when `FitGrid.detailBuilder` is
/// set.
///
/// Rows are identified by key rather than index — by `FitGrid.rowKey`, or by
/// the row object itself when there is none — so an open panel stays with its
/// row through a sort or a filter instead of reattaching to whatever row has
/// moved into its position.
class FitGridDetailState extends ChangeNotifier {
  final Set<Object> _expanded = <Object>{};

  int _revision = 0;

  /// Bumped on every change, for the grid's caches: a `Set` has no cheap
  /// identity to compare.
  int get revision => _revision;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  /// The keys of the rows whose panels are open.
  Set<Object> get expanded => Set<Object>.unmodifiable(_expanded);

  bool get isEmpty => _expanded.isEmpty;

  bool isExpanded(Object key) => _expanded.contains(key);

  void toggle(Object key) {
    if (!_expanded.remove(key)) _expanded.add(key);
    notifyListeners();
  }

  void setExpanded(Object key, bool expanded) {
    if (isExpanded(key) == expanded) return;
    toggle(key);
  }

  void collapseAll() {
    if (_expanded.isEmpty) return;
    _expanded.clear();
    notifyListeners();
  }
}
