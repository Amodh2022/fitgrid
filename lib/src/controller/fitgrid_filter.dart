import 'package:flutter/foundation.dart';

import '../model/column_filter.dart';
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

  final Map<String, FitGridColumnFilter> _filters =
      <String, FitGridColumnFilter>{};

  /// The filters set through the filter UI, or [setFilter], keyed by column
  /// id. Unlike [columnFilters] these are data rather than closures, so they
  /// can be shown back to the user, saved, and sent to a server.
  Map<String, FitGridColumnFilter> get filters =>
      Map<String, FitGridColumnFilter>.unmodifiable(_filters);

  /// Every filter as JSON, keyed by column id — what a data source receives.
  Map<String, Object?> get filtersJson => <String, Object?>{
    for (final entry in _filters.entries) entry.key: entry.value.toJson(),
  };

  /// Ids of the columns narrowed by a filter of either kind.
  Set<String> get filteredColumnIds => <String>{
    ..._filters.keys,
    ..._columnFilters.keys,
  };

  bool get isEmpty =>
      _query.isEmpty && _columnFilters.isEmpty && _filters.isEmpty;

  /// Sets, or with null clears, a column's filter.
  ///
  /// The column must have a [FitGridColumn.filter] spec for the filter to
  /// apply: the spec is what knows how to read a number or a date out of a
  /// row. A filter on a column without one is kept but ignored.
  void setFilter(String columnId, FitGridColumnFilter? filter) {
    if (filter == null) {
      if (_filters.remove(columnId) == null) return;
    } else {
      if (_filters[columnId] == filter) return;
      _filters[columnId] = filter;
    }
    notifyListeners();
  }

  void setColumnFilter(String columnId, FitGridRowPredicate<T>? predicate) {
    if (predicate == null) {
      if (_columnFilters.remove(columnId) == null) return;
    } else {
      _columnFilters[columnId] = predicate;
    }
    notifyListeners();
  }

  /// Clears every column filter, of both kinds, leaving the search.
  void clearColumnFilters() {
    if (_columnFilters.isEmpty && _filters.isEmpty) return;
    _columnFilters.clear();
    _filters.clear();
    notifyListeners();
  }

  void clear() {
    if (isEmpty) return;
    _query = '';
    _columnFilters.clear();
    _filters.clear();
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

  static FitGridColumn<T>? _columnById<T>(
    List<FitGridColumn<T>> columns,
    String id,
  ) {
    for (final column in columns) {
      if (column.id == id) return column;
    }
    return null;
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

    for (final entry in _filters.entries) {
      final column = _columnById(columns, entry.key);
      final spec = column?.filter;
      if (column == null || spec == null) continue;
      final filter = entry.value;
      filters.add(
        (T row) => filter.matches(column.value(row), spec.typedValueOf(row)),
      );
    }
    // Everything asked for was on a hidden or removed column: nothing narrows.
    if (_query.isEmpty && filters.isEmpty) return null;

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
