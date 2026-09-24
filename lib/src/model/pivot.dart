import 'package:flutter/foundation.dart';

import 'column_width.dart';
import 'enums.dart';
import 'fitgrid_column.dart';

/// How a pivot reduces the rows in one cell to a number.
enum FitGridAggregation {
  sum,
  count,
  average,
  min,
  max;

  /// Reduces [values]. Nulls are skipped — except by [count], which counts
  /// rows, not values, so an empty cell still counts the row it came from.
  num? reduce(List<num?> values) {
    if (this == count) return values.length;
    final present = <num>[for (final v in values) ?v];
    if (present.isEmpty) return null;
    return switch (this) {
      sum => present.fold<num>(0, (a, b) => a + b),
      average => present.fold<num>(0, (a, b) => a + b) / present.length,
      min => present.reduce((a, b) => a < b ? a : b),
      max => present.reduce((a, b) => a > b ? a : b),
      count => present.length,
    };
  }
}

/// Something to pivot by: a row heading, or a set of column headings.
@immutable
class FitGridPivotDimension<T> {
  const FitGridPivotDimension({
    required this.id,
    required this.label,
    required this.keyOf,
    this.format,
    this.comparator,
  });

  final String id;
  final String label;

  /// The heading a source row falls under.
  final Object? Function(T row) keyOf;

  /// How a key is written. Defaults to its `toString()`, and "(blank)" for
  /// null.
  final String Function(Object? key)? format;

  /// Orders the headings. Defaults to comparing the keys themselves when
  /// they are comparable, and their text when they are not.
  final Comparator<Object?>? comparator;

  String labelOf(Object? key) =>
      format?.call(key) ?? (key == null ? '(blank)' : '$key');

  int compare(Object? a, Object? b) {
    final custom = comparator;
    if (custom != null) return custom(a, b);
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    if (a is Comparable && b.runtimeType == a.runtimeType) {
      return a.compareTo(b);
    }
    return '$a'.compareTo('$b');
  }
}

/// A number to put in the cells, and how to combine it.
@immutable
class FitGridPivotValue<T> {
  const FitGridPivotValue({
    required this.id,
    required this.label,
    required this.valueOf,
    this.aggregation = FitGridAggregation.sum,
    this.format,
  });

  /// Counts the rows in each cell.
  const FitGridPivotValue.count({
    this.id = 'count',
    this.label = 'Count',
    this.format,
  }) : valueOf = _none,
       aggregation = FitGridAggregation.count;

  static num? _none(Object? _) => null;

  final String id;
  final String label;
  final num? Function(T row) valueOf;
  final FitGridAggregation aggregation;

  /// How a result is written. Defaults to an integer where it is one, and two
  /// decimal places where it is not.
  final String Function(num value)? format;

  String text(num? value) {
    if (value == null) return '';
    if (format != null) return format!(value);
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }
}

/// One row of a pivot: its headings, and a number per generated column.
@immutable
class FitGridPivotRow {
  const FitGridPivotRow({required this.keys, required this.cells});

  /// The row headings, one per row dimension, in order.
  final List<Object?> keys;

  /// Results by generated column id.
  final Map<String, num?> cells;

  num? operator [](String columnId) => cells[columnId];
}

/// What [fitGridPivot] produces: rows and columns ready for a `FitGrid`.
@immutable
class FitGridPivotResult {
  const FitGridPivotResult({
    required this.rows,
    required this.columns,
    required this.totals,
  });

  final List<FitGridPivotRow> rows;

  /// A column per row dimension, then one per value — or, with a column
  /// dimension, one per value under each heading, followed by a total for
  /// each value across the headings.
  final List<FitGridColumn<FitGridPivotRow>> columns;

  /// The grand total of every generated column, reduced from the source rows
  /// rather than from the cells, so an average of averages never happens.
  final Map<String, num?> totals;
}

/// Pivots [source] into summary rows.
///
/// ```dart
/// final pivot = fitGridPivot<Sale>(
///   sales,
///   rows: [FitGridPivotDimension(id: 'region', label: 'Region', keyOf: (s) => s.region)],
///   columns: FitGridPivotDimension(id: 'quarter', label: 'Quarter', keyOf: (s) => s.quarter),
///   values: [FitGridPivotValue(id: 'revenue', label: 'Revenue', valueOf: (s) => s.amount)],
/// );
/// FitGrid<FitGridPivotRow>(rows: pivot.rows, columns: pivot.columns);
/// ```
///
/// The result is an ordinary grid's worth of rows and columns — so sorting,
/// filtering, export and the rest work on a pivot exactly as on anything
/// else. The generated columns are sortable by number, aligned to the end,
/// and carry the grand totals as footer aggregates.
///
/// One pass over [source] to bucket it and one per cell to reduce, so it
/// scales with the data rather than with the size of the table.
FitGridPivotResult fitGridPivot<T>(
  List<T> source, {
  required List<FitGridPivotDimension<T>> rows,
  FitGridPivotDimension<T>? columns,
  required List<FitGridPivotValue<T>> values,
  bool columnTotals = true,
}) {
  assert(values.isNotEmpty, 'A pivot needs at least one value.');

  // Bucket by row key tuple, then by column key.
  final buckets = <_Tuple, Map<Object?, List<T>>>{};
  // The same rows by column heading alone, for the column totals.
  final byColumn = <Object?, List<T>>{};
  for (final item in source) {
    final rowKey = _Tuple(<Object?>[for (final d in rows) d.keyOf(item)]);
    final columnKey = columns?.keyOf(item);
    if (columns != null) {
      byColumn.putIfAbsent(columnKey, () => <T>[]).add(item);
    }
    buckets
        .putIfAbsent(rowKey, () => <Object?, List<T>>{})
        .putIfAbsent(columnKey, () => <T>[])
        .add(item);
  }

  final headings = byColumn.keys.toList()
    ..sort((a, b) => columns!.compare(a, b));

  String columnId(Object? heading, FitGridPivotValue<T> value) =>
      columns == null
      ? value.id
      : '${columns.id}=${columns.labelOf(heading)}/${value.id}';
  String totalId(FitGridPivotValue<T> value) => 'total/${value.id}';

  num? reduce(FitGridPivotValue<T> value, Iterable<T> items) =>
      value.aggregation.reduce(<num?>[for (final i in items) value.valueOf(i)]);

  final keys = buckets.keys.toList()
    ..sort((a, b) {
      for (var i = 0; i < rows.length; i++) {
        final c = rows[i].compare(a.values[i], b.values[i]);
        if (c != 0) return c;
      }
      return 0;
    });

  final pivotRows = <FitGridPivotRow>[
    for (final key in keys)
      FitGridPivotRow(
        keys: key.values,
        cells: <String, num?>{
          for (final value in values) ...<String, num?>{
            if (columns == null)
              value.id: reduce(value, buckets[key]![null] ?? const [])
            else ...<String, num?>{
              for (final heading in headings)
                columnId(heading, value): buckets[key]![heading] == null
                    ? null
                    : reduce(value, buckets[key]![heading]!),
              if (columnTotals)
                totalId(value): reduce(
                  value,
                  buckets[key]!.values.expand((items) => items),
                ),
            },
          },
        },
      ),
  ];

  final totals = <String, num?>{
    for (final value in values) ...<String, num?>{
      if (columns == null)
        value.id: reduce(value, source)
      else ...<String, num?>{
        for (final heading in headings)
          columnId(heading, value): reduce(value, byColumn[heading]!),
        if (columnTotals) totalId(value): reduce(value, source),
      },
    },
  };

  FitGridColumn<FitGridPivotRow> numberColumn(
    String id,
    String label,
    FitGridPivotValue<T> value,
  ) => FitGridColumn<FitGridPivotRow>(
    id: id,
    label: label,
    value: (row) => value.text(row[id]),
    copyValue: (row) => row[id]?.toString() ?? '',
    alignment: FitGridAlignment.end,
    sortable: true,
    comparator: (a, b) {
      final x = a[id];
      final y = b[id];
      if (x == null) return y == null ? 0 : -1;
      if (y == null) return 1;
      return x.compareTo(y);
    },
    aggregate: (_) => value.text(totals[id]),
  );

  final generated = <FitGridColumn<FitGridPivotRow>>[
    for (var i = 0; i < rows.length; i++)
      FitGridColumn<FitGridPivotRow>(
        id: rows[i].id,
        label: rows[i].label,
        value: (row) => rows[i].labelOf(row.keys[i]),
        sortable: true,
        comparator: (a, b) => rows[i].compare(a.keys[i], b.keys[i]),
        freeze: i == 0 ? FitGridFreeze.start : FitGridFreeze.none,
        footerLabel: i == 0 ? 'Total' : null,
        aggregate: i == 0 ? (_) => '' : null,
        width: const FitGridColumnWidth.auto(),
      ),
    if (columns == null)
      for (final value in values) numberColumn(value.id, value.label, value)
    else ...<FitGridColumn<FitGridPivotRow>>[
      for (final heading in headings)
        for (final value in values)
          numberColumn(
            columnId(heading, value),
            values.length == 1
                ? columns.labelOf(heading)
                : '${columns.labelOf(heading)} · ${value.label}',
            value,
          ),
      if (columnTotals)
        for (final value in values)
          numberColumn(
            totalId(value),
            values.length == 1 ? 'Total' : 'Total ${value.label}',
            value,
          ),
    ],
  ];

  return FitGridPivotResult(
    rows: pivotRows,
    columns: generated,
    totals: totals,
  );
}

/// A list of keys compared by value, for bucketing.
@immutable
class _Tuple {
  const _Tuple(this.values);

  final List<Object?> values;

  @override
  bool operator ==(Object other) =>
      other is _Tuple && listEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(values);
}
