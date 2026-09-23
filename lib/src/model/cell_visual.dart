import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../render/cell_spec.dart';

/// A small chart painted into each cell of a column — a data bar, a progress
/// track, a sparkline.
///
/// Painted by the same pass that draws the text, not built: a column of ten
/// thousand sparklines costs what a column of ten thousand words does, which
/// is the point of painting a grid in the first place.
///
/// The column's `value` still says what the cell *is* — for search, sort,
/// copy, export and screen readers — so give it the number the chart shows.
@immutable
sealed class FitGridCellVisual<T> {
  const FitGridCellVisual();

  /// A horizontal bar proportional to the value, drawn behind the text.
  ///
  /// The range runs from [min] to [max]. Leave either null to take it from
  /// the column's data — and the zero line is always inside it, so bars start
  /// from zero and a negative value extends the other way, in
  /// [negativeColor].
  const factory FitGridCellVisual.bar(
    num? Function(T row) valueOf, {
    num? min,
    num? max,
    Color? color,
    Color? negativeColor,
    bool showText,
  }) = FitGridBarVisual<T>;

  /// A track filled to a fraction between 0 and 1.
  const factory FitGridCellVisual.progress(
    double? Function(T row) fractionOf, {
    Color? color,
    bool showText,
  }) = FitGridProgressVisual<T>;

  /// A line through a series of values, scaled to the cell. The text is not
  /// painted — there is no room beside a chart — but it is still what the
  /// cell copies as and what a screen reader says.
  const factory FitGridCellVisual.sparkline(
    List<num> Function(T row) valuesOf, {
    Color? color,
    bool filled,
  }) = FitGridSparklineVisual<T>;

  /// Whether the column's text is painted over the chart.
  bool get showText;

  /// Whether the chart needs the column's data range to be drawn.
  bool get needsRange => false;

  /// The value this row contributes to the data range, if any.
  num? rangeValueOf(T row) => null;

  /// The painted geometry for a row, given the column's data range.
  FitGridCellVisualSpec? resolve(T row, (num, num)? range);
}

final class FitGridBarVisual<T> extends FitGridCellVisual<T> {
  const FitGridBarVisual(
    this.valueOf, {
    this.min,
    this.max,
    this.color,
    this.negativeColor,
    this.showText = true,
  });

  final num? Function(T row) valueOf;
  final num? min;
  final num? max;
  final Color? color;
  final Color? negativeColor;

  @override
  final bool showText;

  @override
  bool get needsRange => min == null || max == null;

  @override
  num? rangeValueOf(T row) => valueOf(row);

  @override
  FitGridCellVisualSpec? resolve(T row, (num, num)? range) {
    final value = valueOf(row);
    if (value == null) return null;
    final low = math.min(0, min ?? range?.$1 ?? 0);
    final high = math.max(0, max ?? range?.$2 ?? 0);
    if (high <= low) return null;
    double at(num v) => ((v.clamp(low, high) - low) / (high - low)).toDouble();
    final zero = at(0);
    final end = at(value);
    return FitGridCellVisualSpec.bar(
      from: math.min(zero, end),
      to: math.max(zero, end),
      negative: value < 0,
      color: value < 0 ? negativeColor : color,
    );
  }
}

final class FitGridProgressVisual<T> extends FitGridCellVisual<T> {
  const FitGridProgressVisual(
    this.fractionOf, {
    this.color,
    this.showText = true,
  });

  final double? Function(T row) fractionOf;
  final Color? color;

  @override
  final bool showText;

  @override
  FitGridCellVisualSpec? resolve(T row, (num, num)? range) {
    final fraction = fractionOf(row);
    if (fraction == null) return null;
    return FitGridCellVisualSpec.progress(
      to: fraction.clamp(0.0, 1.0).toDouble(),
      color: color,
    );
  }
}

final class FitGridSparklineVisual<T> extends FitGridCellVisual<T> {
  const FitGridSparklineVisual(
    this.valuesOf, {
    this.color,
    this.filled = false,
  });

  final List<num> Function(T row) valuesOf;
  final Color? color;
  final bool filled;

  @override
  bool get showText => false;

  @override
  FitGridCellVisualSpec? resolve(T row, (num, num)? range) {
    final values = valuesOf(row);
    if (values.length < 2) return null;
    var low = values.first;
    var high = values.first;
    for (final v in values) {
      if (v < low) low = v;
      if (v > high) high = v;
    }
    // A flat series is drawn flat through the middle, not divided by zero.
    final span = high - low;
    return FitGridCellVisualSpec.sparkline(
      points: <double>[
        for (final v in values) span == 0 ? 0.5 : ((v - low) / span).toDouble(),
      ],
      filled: filled,
      color: color,
    );
  }
}
