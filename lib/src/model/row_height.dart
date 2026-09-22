import 'package:flutter/foundation.dart';

/// How tall each row is.
@immutable
sealed class FitGridRowHeight {
  const FitGridRowHeight();

  /// Every row the same height. The fast path: row offsets are arithmetic, so
  /// finding the rows in the viewport is O(1) rather than a search.
  const factory FitGridRowHeight.fixed(double pixels) = FitGridFixedRowHeight;

  /// Each row sized to its tallest cell, clamped to [min]/[max].
  ///
  /// Only cells that can occupy more than one line have anything to say here,
  /// so this pairs with [FitGridColumn.maxLines]: a grid whose columns are all
  /// single-line still resolves to one uniform height, and costs nothing extra
  /// to lay out. Once a column does wrap, row offsets stop being arithmetic and
  /// move into a prefix-sum table — see [FitGridRowMetrics].
  const factory FitGridRowHeight.contentSized({double min, double? max}) =
      FitGridContentRowHeight;
}

/// Uniform row height. See [FitGridRowHeight.fixed].
final class FitGridFixedRowHeight extends FitGridRowHeight {
  const FitGridFixedRowHeight(this.pixels)
    : assert(pixels > 0, 'pixels must be positive');

  final double pixels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridFixedRowHeight && other.pixels == pixels;

  @override
  int get hashCode => pixels.hashCode;
}

/// Per-row measured height. See [FitGridRowHeight.contentSized].
final class FitGridContentRowHeight extends FitGridRowHeight {
  const FitGridContentRowHeight({this.min = 32.0, this.max})
    : assert(min > 0, 'min must be positive'),
      assert(max == null || max >= min, 'max must not be below min');

  /// Floor for a measured row, so a row of empty cells still has a body to
  /// click on.
  final double min;

  /// Ceiling for a measured row. A row that wants to be taller is clipped at
  /// this height rather than allowed to swallow the viewport.
  final double? max;

  /// Applies this policy's clamp to a measured [height].
  double clamp(double height) {
    var result = height;
    if (result < min) result = min;
    if (max != null && result > max!) result = max!;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridContentRowHeight && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}
