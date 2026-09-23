import 'package:flutter/foundation.dart';

import 'row_model.dart';

/// The rows the grid is showing right now, however they are stored.
///
/// One seam for two very different suppliers: a list held in memory, and a
/// [FitGridDataSource] fetching pages from somewhere slow. Without it every
/// layer — the sizer, the metrics, the cell specs, the hit tests — would need a
/// branch for each, and the branches would drift.
///
/// [rowAt] may return null, which means "this row exists and has not arrived
/// yet". That is a real state for a server-backed grid and a state the geometry
/// has to hold space for, because a scrollbar that grows as rows load is a
/// scrollbar nobody can aim.
@immutable
class FitGridRowsView<T> {
  const FitGridRowsView({
    required this.length,
    required this.offset,
    required this.rowAt,
    required this.loaded,
    required this.identity,
    this.displayAt,
    int Function(int local)? globalIndexOf,
    int Function(int global)? localIndexOf,
  }) : _globalIndexOf = globalIndexOf,
       _localIndexOf = localIndexOf;

  /// A view onto a plain list, where every row is present.
  factory FitGridRowsView.of(List<T> rows, {int offset = 0}) =>
      FitGridRowsView<T>(
        length: rows.length,
        offset: offset,
        rowAt: (index) =>
            index < 0 || index >= rows.length ? null : rows[index],
        loaded: rows,
        identity: rows,
      );

  static FitGridRowsView<T> empty<T>() => FitGridRowsView<T>(
    length: 0,
    offset: 0,
    rowAt: (_) => null,
    loaded: const <Never>[],
    identity: const Object(),
  );

  /// How many rows this view spans — the page, not the dataset.
  final int length;

  /// Index in the full dataset of this view's first row. Non-zero when
  /// paginated, which is what keeps `onRowTap`, the selection and the focus
  /// speaking in global indices.
  final int offset;

  /// The row at a local index, or null when it has not loaded.
  final T? Function(int index) rowAt;

  /// The rows that are actually in hand, for measuring columns and computing
  /// aggregates. For a data source this is the loaded part of the window, which
  /// is the honest answer: a column cannot be measured against rows nobody has
  /// seen.
  final List<T> loaded;

  /// What downstream caches key on. Every memoized thing in the grid — the
  /// column layout, the row metrics, the painted cell specs — compares this, so
  /// it must change exactly when the visible rows do and not one build sooner.
  final Object identity;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => length != 0;

  /// The display line at a local index — a data row or a group header — or null
  /// when the grid is not grouped and every line is simply a row.
  final FitGridDisplayRow<T>? Function(int local)? displayAt;

  final int Function(int local)? _globalIndexOf;
  final int Function(int global)? _localIndexOf;

  /// The index into the full row list of a local line, or -1 for a header.
  ///
  /// Arithmetic when the lines are rows in order, a lookup once grouping has
  /// folded collapsed rows out from between them — which is why everything goes
  /// through here rather than adding [offset] for itself.
  int globalIndex(int local) => _globalIndexOf?.call(local) ?? offset + local;

  /// The inverse: where a row from the full list currently sits on screen, or
  /// -1 when it is inside something collapsed.
  int localIndex(int global) {
    final local = _localIndexOf?.call(global) ?? global - offset;
    return local < 0 || local >= length ? -1 : local;
  }

  /// Whether the line at a local index is a group header rather than a row.
  bool isHeader(int local) => displayAt?.call(local)?.isHeader ?? false;
}
