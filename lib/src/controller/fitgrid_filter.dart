import 'package:flutter/foundation.dart';

import '../model/fitgrid_column.dart';

/// The active search text and column filters.
///
/// Separate from the data it narrows, and separate again from the sort, because
/// the three invalidate different caches: typing into the search re-derives the
/// row view, while sorting reuses the filtered list and column widths survive
/// both. Folding them into one notifier would mean every keystroke re-measured
/// every column.
class FitGridFilterState<T> extends ChangeNotifier {
  String _query = '';

  /// Free-text search applied across every [FitGridColumn.searchable] column.
  String get query => _query;
  set query(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  bool _caseSensitive = false;
  bool get caseSensitive => _caseSensitive;
  set caseSensitive(bool value) {
    if (_caseSensitive == value) return;
    _caseSensitive = value;
    notifyListeners();
  }

  final Map<String, FitGridRowPredicate<T>> _columnFilters =
      <String, FitGridRowPredicate<T>>{};

  /// Per-column predicates, keyed by column id. A row must pass every one of
  /// them, and the search, to survive.
  Map<String, FitGridRowPredicate<T>> get columnFilters =>
      Map<String, FitGridRowPredicate<T>>.unmodifiable(_columnFilters);

  bool get isEmpty => _query.isEmpty && _columnFilters.isEmpty;

  void setColumnFilter(String columnId, FitGridRowPredicate<T>? predicate) {
    if (predicate == null) {
      if (_columnFilters.remove(columnId) == null) return;
    } else {
      _columnFilters[columnId] = predicate;
    }
    notifyListeners();
  }

  void clearColumnFilters() {
    if (_columnFilters.isEmpty) return;
    _columnFilters.clear();
    notifyListeners();
  }

  void clear() {
    if (isEmpty) return;
    _query = '';
    _columnFilters.clear();
    notifyListeners();
  }

  /// Where [query] occurs in [text], as flat `start, end` pairs.
  ///
  /// The grid hands these to the render layer, which draws a wash behind
  /// exactly those characters using the painter it has already laid out — so
  /// highlighting a match costs a rectangle rather than a rebuilt span tree.
  List<int> matchesIn(String text) {
    if (_query.isEmpty || text.isEmpty) return const <int>[];
    final haystack = _caseSensitive ? text : text.toLowerCase();
    final needle = _caseSensitive ? _query : _query.toLowerCase();
    final spans = <int>[];
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) break;
      spans
        ..add(at)
        ..add(at + needle.length);
      from = at + needle.length;
    }
    return spans;
  }

  bool _matchesQuery(String text) {
    if (_query.isEmpty) return true;
    return _caseSensitive
        ? text.contains(_query)
        : text.toLowerCase().contains(_query.toLowerCase());
  }

  /// Builds the predicate the data state filters with, or null when nothing is
  /// filtered — which is the signal to skip the pass entirely rather than run
  /// a predicate that always says yes over every row.
  FitGridRowPredicate<T>? buildPredicate(List<FitGridColumn<T>> columns) {
    if (isEmpty) return null;
    final searchable = <FitGridColumn<T>>[
      if (_query.isNotEmpty)
        for (final column in columns)
          if (column.searchable) column,
    ];
    final filters = <FitGridRowPredicate<T>>[];
    for (final entry in _columnFilters.entries) {
      // A filter on a column that has since been removed is dropped rather
      // than kept alive against a column nobody can see to clear it.
      if (columns.any((column) => column.id == entry.key)) {
        filters.add(entry.value);
      }
    }

    return (T row) {
      for (final predicate in filters) {
        if (!predicate(row)) return false;
      }
      if (_query.isEmpty) return true;
      for (final column in searchable) {
        if (_matchesQuery(column.value(row))) return true;
      }
      return false;
    };
  }
}
