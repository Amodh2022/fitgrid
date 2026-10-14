import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../model/fitgrid_column.dart';

/// What a case-insensitive search looks for, and in which columns.
///
/// Built by the filter state next to the full predicate, so the data state can
/// answer the search from a [FitGridSearchIndex] instead of reading every
/// cell of every row on each keystroke.
@internal
@immutable
class FitGridSearch<T> {
  const FitGridSearch({
    required this.needle,
    required this.columns,
    required this.source,
  });

  /// The search text, lower case.
  final String needle;

  /// The searchable columns, in order.
  final List<FitGridColumn<T>> columns;

  /// The visible columns [columns] was taken from. An index is reused while
  /// this is the same list, and the rows are.
  final Object source;
}

/// Every row's search text, lower case, read once.
///
/// Rows are packed into chunks of [chunkRows]: each chunk is one string with
/// the rows' cells end to end, a separator between cells, and the offset of
/// each row's first cell. A search is then one native `indexOf` per match
/// rather than a closure call, a `toLowerCase` and a `contains` per cell.
///
/// Like the column measurement, it is keyed on the rows list's identity: a
/// cell whose text changes without the rows list being replaced is searched
/// as it was.
@internal
class FitGridSearchIndex<T> {
  FitGridSearchIndex._(this.rows, this.source, this._chunks, this._offsets);

  /// Rows per chunk: small enough that searching one is well inside a frame's
  /// budget, large enough that the per-chunk overhead does not show.
  static const int chunkRows = 8192;

  /// Between cells, so a match never spans two of them. A search for text
  /// containing it is not answered from the index.
  static const String separator = '\u0000';

  final List<T> rows;
  final Object source;
  final List<String> _chunks;
  final List<Int32List> _offsets;

  /// Code units held, for a memory estimate.
  int get length => _chunks.fold(0, (sum, chunk) => sum + chunk.length);

  bool fits(List<T> rows, FitGridSearch<T> search) =>
      identical(this.rows, rows) && identical(source, search.source);

  static bool canAnswer(String needle) =>
      needle.isNotEmpty && !needle.contains(separator);

  /// Reads [search]'s columns out of [rows], yielding to the event loop every
  /// [budget]. Returns null when [cancelled] says it is no longer wanted.
  static Future<FitGridSearchIndex<T>?> build<T>(
    List<T> rows,
    FitGridSearch<T> search, {
    required bool Function() cancelled,
    Duration budget = const Duration(milliseconds: 6),
  }) async {
    final columns = search.columns;
    final chunks = <String>[];
    final offsets = <Int32List>[];
    final watch = Stopwatch()..start();
    for (var start = 0; start < rows.length; start += chunkRows) {
      final end = start + chunkRows < rows.length
          ? start + chunkRows
          : rows.length;
      final buffer = StringBuffer();
      final starts = Int32List(end - start + 1);
      for (var i = start; i < end; i++) {
        starts[i - start] = buffer.length;
        final row = rows[i];
        for (final column in columns) {
          buffer
            ..write(column.value(row).toLowerCase())
            ..write(separator);
        }
        if ((i & 255) == 0 && watch.elapsed >= budget) {
          await Future<void>.delayed(Duration.zero);
          if (cancelled()) return null;
          watch.reset();
        }
      }
      starts[end - start] = buffer.length;
      chunks.add(buffer.toString());
      offsets.add(starts);
    }
    return FitGridSearchIndex<T>._(rows, search.source, chunks, offsets);
  }

  /// The rows whose text contains [needle], which is lower case. Returns null
  /// when [cancelled] says it is no longer wanted.
  Future<Set<T>?> matching(
    String needle, {
    required bool Function() cancelled,
    Duration budget = const Duration(milliseconds: 6),
  }) async {
    final matched = HashSet<T>.identity();
    final watch = Stopwatch()..start();
    for (var c = 0; c < _chunks.length; c++) {
      final chunk = _chunks[c];
      final starts = _offsets[c];
      final base = c * chunkRows;
      var from = 0;
      while (true) {
        final at = chunk.indexOf(needle, from);
        if (at < 0) break;
        final row = _rowAt(starts, at);
        matched.add(rows[base + row]);
        // The rest of that row cannot add anything: on to the next one.
        from = starts[row + 1];
      }
      if (watch.elapsed >= budget) {
        await Future<void>.delayed(Duration.zero);
        if (cancelled()) return null;
        watch.reset();
      }
    }
    return matched;
  }

  /// The row whose text holds code unit [at]: the last start at or before it.
  static int _rowAt(Int32List starts, int at) {
    var low = 0;
    var high = starts.length - 2;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (starts[mid] <= at) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}
