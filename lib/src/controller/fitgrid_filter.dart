import 'package:flutter/foundation.dart';

import '../model/column_filter.dart';
import '../model/fitgrid_column.dart';
import 'fitgrid_search_index.dart';

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

  int _shapeRevision = 0;

  /// Bumped by every change but the search text. While it holds still, a
  /// longer search keeps only rows the shorter one kept, so the data state
  /// can filter the previous result rather than every row.
  @internal
  int get shapeRevision => _shapeRevision;

  /// Whether every row the search [query] keeps, a search for [previous]
  /// kept too, with the column filters unchanged.
  @internal
  bool queryNarrows(String previous) {
    if (previous.isEmpty) return true;
    return _caseSensitive
        ? _query.contains(previous)
        : _query.toLowerCase().contains(previous.toLowerCase());
  }

  bool _caseSensitive = false;
  bool get caseSensitive => _caseSensitive;
  set caseSensitive(bool value) {
    if (_caseSensitive == value) return;
    _caseSensitive = value;
    _shapeRevision++;
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
    _shapeRevision++;
    notifyListeners();
  }

  void setColumnFilter(String columnId, FitGridRowPredicate<T>? predicate) {
    if (predicate == null) {
      if (_columnFilters.remove(columnId) == null) return;
    } else {
      _columnFilters[columnId] = predicate;
    }
    _shapeRevision++;
    notifyListeners();
  }

  /// Clears every column filter, of both kinds, leaving the search.
  void clearColumnFilters() {
    if (_columnFilters.isEmpty && _filters.isEmpty) return;
    _columnFilters.clear();
    _filters.clear();
    _shapeRevision++;
    notifyListeners();
  }

  void clear() {
    if (isEmpty) return;
    _query = '';
    _columnFilters.clear();
    _filters.clear();
    _shapeRevision++;
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

  /// Whether [text] contains [needle], ignoring case. [needle] is already
  /// lower case. Compares code units folding ASCII letters, so the common
  /// case allocates nothing; text with anything beyond ASCII falls back to
  /// `toLowerCase`, which is what decides a match there.
  static bool _containsIgnoringCase(String text, String needle) {
    final n = needle.length;
    final last = text.length - n;
    outer:
    for (var start = 0; start <= last; start++) {
      for (var k = 0; k < n; k++) {
        var unit = text.codeUnitAt(start + k);
        if (unit >= 0x80) return text.toLowerCase().contains(needle);
        if (unit >= 0x41 && unit <= 0x5A) unit += 0x20;
        if (unit != needle.codeUnitAt(k)) continue outer;
      }
      return true;
    }
    // No match in the ASCII prefix scanned; anything non-ASCII after it could
    // still lower-case into one.
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) >= 0x80) {
        return text.toLowerCase().contains(needle);
      }
    }
    return false;
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
  ///
  /// With [includeQuery] false the search is left out: the column filters
  /// alone, for a data state answering the search from an index.
  FitGridRowPredicate<T>? buildPredicate(
    List<FitGridColumn<T>> columns, {
    bool includeQuery = true,
  }) {
    if (isEmpty) return null;
    final query = includeQuery ? _query : '';
    final searchable = <FitGridColumn<T>>[
      if (query.isNotEmpty)
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
    if (query.isEmpty && filters.isEmpty) return null;

    final caseSensitive = _caseSensitive;
    final needle = caseSensitive ? query : query.toLowerCase();
    final asciiNeedle = needle.codeUnits.every((unit) => unit < 0x80);
    bool matches(String text) => caseSensitive
        ? text.contains(needle)
        : asciiNeedle
        ? _containsIgnoringCase(text, needle)
        : text.toLowerCase().contains(needle);

    return (T row) {
      for (final predicate in filters) {
        if (!predicate(row)) return false;
      }
      if (query.isEmpty) return true;
      for (final column in searchable) {
        if (matches(column.value(row))) return true;
      }
      return false;
    };
  }

  /// The search on its own, for a data state that can answer it from a
  /// search index, or null when there is none to answer: no search text, or a
  /// case-sensitive one, which the index — lower case — cannot.
  @internal
  FitGridSearch<T>? buildSearch(List<FitGridColumn<T>> columns) {
    if (_query.isEmpty || _caseSensitive) return null;
    final needle = _query.toLowerCase();
    if (!FitGridSearchIndex.canAnswer(needle)) return null;
    return FitGridSearch<T>(
      needle: needle,
      columns: <FitGridColumn<T>>[
        for (final column in columns)
          if (column.searchable) column,
      ],
      source: columns,
    );
  }
}
