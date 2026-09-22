import 'package:flutter/foundation.dart';

/// How a column decides how wide it wants to be.
///
/// This is the package's headline feature, so it gets real nouns rather than a
/// `bool autoFit` and a pair of ratio knobs. Every variant carries its own
/// [min]/[max] clamp, because "measure the content, but never below 80 and
/// never above 400" is the request people actually have.
@immutable
sealed class FitGridColumnWidth {
  const FitGridColumnWidth({this.min, this.max});

  /// Size the column to its content: the header plus a sample of the widest
  /// cells, measured with a real `TextPainter`.
  const factory FitGridColumnWidth.auto({
    double? min,
    double? max,
    int sampleSize,
    bool measureAllRows,
  }) = FitGridAutoWidth;

  /// An exact pixel width. Never measured, never stretched.
  const factory FitGridColumnWidth.fixed(double pixels) = FitGridFixedWidth;

  /// Take a share of the leftover width, like `Flexible`. Sized from its
  /// [flex] against the other flex columns, after fixed and auto columns have
  /// taken what they need.
  const factory FitGridColumnWidth.flex(int flex, {double? min, double? max}) =
      FitGridFlexWidth;

  /// Size to the header text alone, ignoring cell content. Useful for columns
  /// whose cells are icons, badges or checkboxes.
  const factory FitGridColumnWidth.fitHeader({double? min, double? max}) =
      FitGridFitHeaderWidth;

  /// Lower clamp in logical pixels, applied after measurement.
  final double? min;

  /// Upper clamp in logical pixels, applied after measurement.
  final double? max;

  /// Whether this policy pins the column to a single width, leaving a resize
  /// drag nothing to do.
  ///
  /// A [FitGridFixedWidth] is the obvious case, but `auto(min: 120, max: 120)`
  /// is the same thing said differently, and the header checks this rather than
  /// the runtime type so both are treated alike: no handle is offered for a
  /// column that could not move if it were dragged.
  bool get isPinned => min != null && max != null && min == max;

  /// Applies this policy's clamp to a measured or computed [width].
  double clamp(double width) {
    var result = width;
    if (min != null && result < min!) result = min!;
    if (max != null && result > max!) result = max!;
    return result;
  }
}

/// Content-measured width. See [FitGridColumnWidth.auto].
final class FitGridAutoWidth extends FitGridColumnWidth {
  const FitGridAutoWidth({
    super.min,
    super.max,
    this.sampleSize = 24,
    this.measureAllRows = false,
  }) : assert(sampleSize > 0, 'sampleSize must be positive');

  /// How many of the longest cells to actually measure.
  ///
  /// Measuring every row of a 100k-row table would cost more than painting it.
  /// The sizer instead picks the [sampleSize] longest strings by character
  /// count — which is cheap — and runs the expensive `TextPainter` measurement
  /// only on those. Character count is a proxy for width, not a guarantee, so
  /// a larger sample trades time for accuracy on proportional fonts.
  final int sampleSize;

  /// Measure every row instead of a sample. Correct, and O(rows) in
  /// `TextPainter` layouts — only reasonable for small, static tables.
  final bool measureAllRows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridAutoWidth &&
          other.min == min &&
          other.max == max &&
          other.sampleSize == sampleSize &&
          other.measureAllRows == measureAllRows;

  @override
  int get hashCode => Object.hash(min, max, sampleSize, measureAllRows);
}

/// Exact width. See [FitGridColumnWidth.fixed].
final class FitGridFixedWidth extends FitGridColumnWidth {
  const FitGridFixedWidth(this.pixels)
    : assert(pixels > 0, 'pixels must be positive'),
      super(min: pixels, max: pixels);

  final double pixels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridFixedWidth && other.pixels == pixels;

  @override
  int get hashCode => pixels.hashCode;
}

/// Proportional share of leftover width. See [FitGridColumnWidth.flex].
final class FitGridFlexWidth extends FitGridColumnWidth {
  const FitGridFlexWidth(this.flex, {super.min, super.max})
    : assert(flex > 0, 'flex must be positive');

  final int flex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridFlexWidth &&
          other.flex == flex &&
          other.min == min &&
          other.max == max;

  @override
  int get hashCode => Object.hash(flex, min, max);
}

/// Header-only measured width. See [FitGridColumnWidth.fitHeader].
final class FitGridFitHeaderWidth extends FitGridColumnWidth {
  const FitGridFitHeaderWidth({super.min, super.max});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridFitHeaderWidth && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}
