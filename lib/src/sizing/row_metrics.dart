import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Where every row sits vertically, and how tall it is.
///
/// The render layer never divides by a row height itself: it asks this. That
/// indirection is what lets uniform rows stay arithmetic — O(1) offsets, no
/// table, no allocation — while content-sized rows binary search a prefix sum,
/// without the windowing, painting and hit-testing code knowing which of the
/// two it is looking at.
@immutable
sealed class FitGridRowMetrics {
  const FitGridRowMetrics();

  /// Every row the same height. Offsets are multiplication.
  const factory FitGridRowMetrics.uniform({
    required int rowCount,
    required double rowHeight,
  }) = FitGridUniformRowMetrics;

  /// Per-row measured heights. Offsets come from a prefix-sum table.
  factory FitGridRowMetrics.measured(List<double> heights) =
      FitGridMeasuredRowMetrics;

  /// No rows at all.
  static const FitGridRowMetrics empty = FitGridUniformRowMetrics(
    rowCount: 0,
    rowHeight: 1.0,
  );

  int get rowCount;

  /// Total height of every row, whether or not it is on screen.
  double get totalHeight;

  /// Whether all rows share one height. Callers that can take a cheaper path
  /// when they do — and there are a few — branch on this.
  bool get isUniform;

  /// Height of a single row.
  double heightOf(int row);

  /// Top edge of a row in content space. Defined for `row == rowCount`, where
  /// it equals [totalHeight], so a caller can ask for the bottom edge of the
  /// last row without a special case.
  double offsetOf(int row);

  /// The row containing [y] in content space, or -1 when [y] falls outside the
  /// content.
  int rowAtOffset(double y) => y < 0 || y >= totalHeight ? -1 : clampedRowAt(y);

  /// The row containing [y], clamped into range rather than rejected. This is
  /// what windowing wants: a scroll position slightly past either end should
  /// still name the first or last row.
  int clampedRowAt(double y);

  /// How many rows are needed to cover [extent] pixels starting at [firstRow],
  /// including the partially visible row at each end.
  int rowsSpanning(int firstRow, double extent);
}

/// Uniform row heights. See [FitGridRowMetrics.uniform].
final class FitGridUniformRowMetrics extends FitGridRowMetrics {
  const FitGridUniformRowMetrics({
    required this.rowCount,
    required this.rowHeight,
  }) : assert(rowHeight > 0, 'rowHeight must be positive');

  @override
  final int rowCount;

  final double rowHeight;

  @override
  bool get isUniform => true;

  @override
  double get totalHeight => rowCount * rowHeight;

  @override
  double heightOf(int row) => rowHeight;

  @override
  double offsetOf(int row) => row * rowHeight;

  @override
  int clampedRowAt(double y) =>
      rowCount == 0 ? 0 : (y ~/ rowHeight).clamp(0, rowCount - 1);

  @override
  int rowsSpanning(int firstRow, double extent) =>
      (extent / rowHeight).ceil() + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridUniformRowMetrics &&
          other.rowCount == rowCount &&
          other.rowHeight == rowHeight;

  @override
  int get hashCode => Object.hash(rowCount, rowHeight);

  @override
  String toString() =>
      'FitGridRowMetrics.uniform($rowCount x ${rowHeight.toStringAsFixed(1)}px)';
}

/// Measured row heights. See [FitGridRowMetrics.measured].
///
/// Equality is identity, deliberately. Comparing two height tables element by
/// element is O(rows), and it would run on every build of a grid that is
/// scrolling — which is the one place this package refuses to spend O(rows).
/// The widget layer memoizes the metrics it builds, so the same instance comes
/// back when nothing relevant changed, and identity is exactly the right test.
final class FitGridMeasuredRowMetrics extends FitGridRowMetrics {
  FitGridMeasuredRowMetrics(List<double> heights)
    : _offsets = _prefixSums(heights),
      rowCount = heights.length;

  /// Prefix sums of the row heights, length `rowCount + 1`.
  final Float64List _offsets;

  @override
  final int rowCount;

  @override
  bool get isUniform => false;

  @override
  double get totalHeight => _offsets[rowCount];

  @override
  double heightOf(int row) => _offsets[row + 1] - _offsets[row];

  @override
  double offsetOf(int row) => _offsets[row];

  @override
  int clampedRowAt(double y) {
    if (rowCount == 0) return 0;
    if (y <= 0) return 0;
    if (y >= totalHeight) return rowCount - 1;
    var low = 0;
    var high = rowCount - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_offsets[mid + 1] <= y) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  @override
  int rowsSpanning(int firstRow, double extent) {
    if (rowCount == 0) return 0;
    final first = firstRow.clamp(0, rowCount - 1);
    final last = clampedRowAt(_offsets[first] + extent);
    return math.max(1, last - first + 1);
  }

  static Float64List _prefixSums(List<double> heights) {
    final sums = Float64List(heights.length + 1);
    var running = 0.0;
    for (var i = 0; i < heights.length; i++) {
      running += heights[i];
      sums[i + 1] = running;
    }
    return sums;
  }

  @override
  String toString() =>
      'FitGridRowMetrics.measured($rowCount rows, '
      '${totalHeight.toStringAsFixed(1)}px)';
}
