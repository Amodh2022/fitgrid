import 'package:flutter/foundation.dart';

import '../model/column_filter.dart';
import '../model/enums.dart';
import '../model/sort_key.dart';

/// Everything about a grid a user would expect it to remember: the column
/// order, which columns are hidden or pinned, the widths they were dragged to,
/// the sort, the filters, the search and the page.
///
/// A snapshot, not a live view. Take one with
/// `FitGridController.saveState`, keep it wherever the app keeps preferences —
/// [toJson] gives a plain map, ready for `jsonEncode` — and hand it back to
/// `FitGridController.restoreState` next session.
///
/// Rows, selection and focus are left out on purpose. They describe the data,
/// not the view of it, and restoring a selection by index onto rows that have
/// changed since would select the wrong ones.
@immutable
class FitGridSavedState {
  const FitGridSavedState({
    this.columnOrder = const <String>[],
    this.hiddenColumns = const <String>{},
    this.frozenColumns = const <String, FitGridFreeze>{},
    this.columnWidths = const <String, double>{},
    this.sort = const <FitGridSortKey>[],
    this.filters = const <String, FitGridColumnFilter>{},
    this.query = '',
    this.pageSize,
    this.pageIndex,
  });

  /// Every column id, in display order, hidden ones included.
  final List<String> columnOrder;

  final Set<String> hiddenColumns;

  /// Each column's pin, including [FitGridFreeze.none], so a column the user
  /// unpinned stays unpinned even if the app declares it pinned.
  final Map<String, FitGridFreeze> frozenColumns;

  /// Widths the user dragged columns to. Columns left to their width policy
  /// are absent, and keep re-fitting to their content after a restore.
  final Map<String, double> columnWidths;

  final List<FitGridSortKey> sort;
  final Map<String, FitGridColumnFilter> filters;
  final String query;
  final int? pageSize;
  final int? pageIndex;

  /// The format version [toJson] writes, so a later release that changes the
  /// shape can still read what an earlier one saved.
  static const int version = 1;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'columnOrder': columnOrder,
    if (hiddenColumns.isNotEmpty) 'hidden': (hiddenColumns.toList()..sort()),
    if (frozenColumns.isNotEmpty)
      'frozen': <String, String>{
        for (final entry in frozenColumns.entries) entry.key: entry.value.name,
      },
    if (columnWidths.isNotEmpty) 'widths': columnWidths,
    if (sort.isNotEmpty)
      'sort': <Map<String, String>>[
        for (final key in sort)
          <String, String>{'column': key.columnId, 'dir': key.direction.name},
      ],
    if (filters.isNotEmpty)
      'filters': <String, Object?>{
        for (final entry in filters.entries) entry.key: entry.value.toJson(),
      },
    if (query.isNotEmpty) 'query': query,
    'pageSize': ?pageSize,
    'pageIndex': ?pageIndex,
  };

  /// Reads what [toJson] wrote. Anything it does not recognise — an unknown
  /// direction, a malformed entry — is skipped rather than thrown on, because
  /// a corrupt preference should cost the user their layout, not the screen.
  factory FitGridSavedState.fromJson(Map<String, Object?> json) {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    Map<String, Object?> mapOf(Object? value) => value is Map
        ? <String, Object?>{
            for (final entry in value.entries) '${entry.key}': entry.value,
          }
        : const <String, Object?>{};

    E? enumByName<E extends Enum>(List<E> values, Object? name) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    final frozen = <String, FitGridFreeze>{};
    for (final entry in mapOf(json['frozen']).entries) {
      final freeze = enumByName(FitGridFreeze.values, entry.value);
      if (freeze != null) frozen[entry.key] = freeze;
    }

    final sort = <FitGridSortKey>[];
    for (final raw in read<List<Object?>>('sort') ?? const <Object?>[]) {
      if (raw is! Map) continue;
      final column = raw['column'];
      final direction = enumByName(FitGridSortDirection.values, raw['dir']);
      if (column is String &&
          direction != null &&
          direction != FitGridSortDirection.none) {
        sort.add(FitGridSortKey(column, direction));
      }
    }

    return FitGridSavedState(
      columnOrder: <String>[
        for (final id in read<List<Object?>>('columnOrder') ?? const []) '$id',
      ],
      hiddenColumns: <String>{
        for (final id in read<List<Object?>>('hidden') ?? const []) '$id',
      },
      frozenColumns: frozen,
      columnWidths: <String, double>{
        for (final entry in mapOf(json['widths']).entries)
          if (entry.value case final num width) entry.key: width.toDouble(),
      },
      sort: sort,
      filters: <String, FitGridColumnFilter>{
        for (final entry in mapOf(json['filters']).entries)
          if (entry.value is Map)
            entry.key: FitGridColumnFilter.fromJson(mapOf(entry.value)),
      },
      query: read<String>('query') ?? '',
      pageSize: read<int>('pageSize'),
      pageIndex: read<int>('pageIndex'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FitGridSavedState &&
      listEquals(other.columnOrder, columnOrder) &&
      setEquals(other.hiddenColumns, hiddenColumns) &&
      mapEquals(other.frozenColumns, frozenColumns) &&
      mapEquals(other.columnWidths, columnWidths) &&
      listEquals(other.sort, sort) &&
      mapEquals(other.filters, filters) &&
      other.query == query &&
      other.pageSize == pageSize &&
      other.pageIndex == pageIndex;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(columnOrder),
    Object.hashAllUnordered(hiddenColumns),
    Object.hashAllUnordered(frozenColumns.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(columnWidths.entries.map((e) => (e.key, e.value))),
    Object.hashAll(sort),
    Object.hashAllUnordered(filters.entries.map((e) => (e.key, e.value))),
    query,
    pageSize,
    pageIndex,
  );

  @override
  String toString() => 'FitGridSavedState(${toJson()})';
}
