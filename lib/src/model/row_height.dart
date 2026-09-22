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
  /// Costs a measurement pass over the visible window and forces row offsets
  /// to be tracked in a prefix-sum table rather than computed.
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
  const FitGridContentRowHeight({this.min = 32.0, this.max});

  final double min;
  final double? max;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridContentRowHeight && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}
