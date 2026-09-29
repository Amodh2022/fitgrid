import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// One sort key, read out of the rows into flat typed arrays.
///
/// Rows are arbitrary objects and comparators are closures over them, and
/// neither can cross to another isolate. What can is a column of plain values,
/// so a sort that is to run in the background first reads each key once per row
/// on the UI thread — sliced across frames — into one of these.
@immutable
class FitGridSortColumn {
  const FitGridSortColumn.text({
    required Uint16List this.units,
    required Int32List this.offsets,
    required this.descending,
  }) : numbers = null,
       nulls = null;

  const FitGridSortColumn.number({
    required Float64List this.numbers,
    required Uint8List this.nulls,
    required this.descending,
  }) : units = null,
       offsets = null;

  /// Every row's text, UTF-16 code units end to end.
  final Uint16List? units;

  /// Where each row's text starts in [units]; one longer than the rows, so row
  /// i is `units[offsets[i]]` up to `units[offsets[i + 1]]`.
  final Int32List? offsets;

  /// Every row's value, for a number, a date or a flag.
  final Float64List? numbers;

  /// 1 where a row had no value. Empty values sort first ascending.
  final Uint8List? nulls;

  final bool descending;

  int compare(int a, int b) {
    final result = _compare(a, b);
    return descending ? -result : result;
  }

  int _compare(int a, int b) {
    final units = this.units;
    if (units != null) {
      // Code unit by code unit, which is exactly what `String.compareTo` does,
      // so a background sort orders text the way the foreground one would.
      final offsets = this.offsets!;
      var i = offsets[a];
      final iEnd = offsets[a + 1];
      var j = offsets[b];
      final jEnd = offsets[b + 1];
      while (i < iEnd && j < jEnd) {
        final d = units[i] - units[j];
        if (d != 0) return d;
        i++;
        j++;
      }
      return (iEnd - offsets[a]) - (jEnd - offsets[b]);
    }
    final nulls = this.nulls!;
    final aNull = nulls[a] == 1;
    final bNull = nulls[b] == 1;
    if (aNull || bNull) return aNull == bNull ? 0 : (aNull ? -1 : 1);
    final numbers = this.numbers!;
    return numbers[a].compareTo(numbers[b]);
  }
}

/// Orders row indices by [columns], highest priority first, with the row's
/// own position as the last tie-break so the sort is stable.
///
/// Top-level so it can run on another isolate.
Int32List fitGridSortIndices(List<FitGridSortColumn> columns) {
  final length = columns.isEmpty
      ? 0
      : (columns.first.offsets?.length ?? columns.first.nulls!.length + 1) - 1;
  final order = Int32List(length);
  for (var i = 0; i < length; i++) {
    order[i] = i;
  }
  order.sort((a, b) {
    for (final column in columns) {
      final result = column.compare(a, b);
      if (result != 0) return result;
    }
    return a - b;
  });
  return order;
}

/// Compares two values the way [FitGridSortColumn] does, for the sort that
/// stays on the UI thread: empty first, then by value.
int fitGridCompareSortValues(Object? a, Object? b) {
  if (a == null || b == null) return a == b ? 0 : (a == null ? -1 : 1);
  return switch ((a, b)) {
    (final String a, final String b) => a.compareTo(b),
    (final num a, final num b) => a.compareTo(b),
    (final DateTime a, final DateTime b) => a.compareTo(b),
    (final bool a, final bool b) => a == b ? 0 : (a ? 1 : -1),
    _ => throw ArgumentError(
      'A sort value must be a String, num, DateTime or bool, and the same '
      'one for every row; got ${a.runtimeType} and ${b.runtimeType}.',
    ),
  };
}

/// Reads one key out of [rows], yielding to the event loop every [budget] so
/// the UI keeps drawing frames. Returns null when [cancelled] says the work is
/// no longer wanted.
Future<FitGridSortColumn?> fitGridReadSortColumn<T>(
  List<T> rows,
  Object? Function(T row) valueOf, {
  required bool descending,
  required bool Function() cancelled,
  Duration budget = const Duration(milliseconds: 6),
}) async {
  final length = rows.length;
  final watch = Stopwatch()..start();

  Future<bool> yieldIfDue() async {
    if (watch.elapsed < budget) return false;
    await Future<void>.delayed(Duration.zero);
    watch.reset();
    return cancelled();
  }

  // The first value decides the kind. Numbers go straight into typed arrays;
  // only text needs holding on to, to be copied out once its length is known.
  Object? first;
  for (var i = 0; i < length && first == null; i++) {
    first = valueOf(rows[i]);
  }

  Never mixed(Object value) => throw ArgumentError(
    'A column\'s sort values must all be one kind; '
    'got ${first.runtimeType} and ${value.runtimeType}.',
  );

  if (first is String || first == null) {
    final texts = List<String?>.filled(length, null);
    var textLength = 0;
    for (var i = 0; i < length; i++) {
      final value = valueOf(rows[i]);
      if (value != null) {
        if (value is! String) mixed(value);
        texts[i] = value;
        textLength += value.length;
      }
      if ((i & 1023) == 0 && await yieldIfDue()) return null;
    }
    final units = Uint16List(textLength);
    final offsets = Int32List(length + 1);
    var at = 0;
    for (var i = 0; i < length; i++) {
      offsets[i] = at;
      final text = texts[i];
      if (text != null && text.isNotEmpty) {
        units.setRange(at, at + text.length, text.codeUnits);
        at += text.length;
      }
      if ((i & 1023) == 0 && await yieldIfDue()) return null;
    }
    offsets[length] = at;
    return FitGridSortColumn.text(
      units: units,
      offsets: offsets,
      descending: descending,
    );
  }

  if (first is! num && first is! DateTime && first is! bool) {
    throw ArgumentError(
      'A sort value must be a String, num, DateTime or bool; '
      'got ${first.runtimeType}.',
    );
  }
  final numbers = Float64List(length);
  final nulls = Uint8List(length);
  for (var i = 0; i < length; i++) {
    final value = valueOf(rows[i]);
    switch (value) {
      case null:
        nulls[i] = 1;
      case final num n when first is num:
        numbers[i] = n.toDouble();
      case final DateTime d when first is DateTime:
        numbers[i] = d.microsecondsSinceEpoch.toDouble();
      case final bool b when first is bool:
        numbers[i] = b ? 1 : 0;
      default:
        mixed(value);
    }
    if ((i & 1023) == 0 && await yieldIfDue()) return null;
  }
  return FitGridSortColumn.number(
    numbers: numbers,
    nulls: nulls,
    descending: descending,
  );
}

/// [rows] in [order], built in slices so the UI keeps drawing frames. Returns
/// null when [cancelled] says the result is no longer wanted.
Future<List<T>?> fitGridInOrder<T>(
  Int32List order,
  List<T> rows, {
  required bool Function() cancelled,
  Duration budget = const Duration(milliseconds: 6),
}) async {
  final length = order.length;
  if (length == 0) return <T>[];
  final sorted = List<T>.filled(length, rows[order[0]]);
  final watch = Stopwatch()..start();
  for (var i = 0; i < length; i++) {
    sorted[i] = rows[order[i]];
    if ((i & 4095) == 0 && watch.elapsed >= budget) {
      await Future<void>.delayed(Duration.zero);
      if (cancelled()) return null;
      watch.reset();
    }
  }
  return sorted;
}

/// Sorts on a background isolate where there is one; on the web, where there
/// is not, `compute` runs it on the UI thread after the keys are read.
Future<Int32List> fitGridSortInBackground(List<FitGridSortColumn> columns) =>
    compute(fitGridSortIndices, columns, debugLabel: 'fitgrid sort');
