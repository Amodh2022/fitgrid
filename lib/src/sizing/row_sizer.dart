import 'package:flutter/widgets.dart';

import '../model/fitgrid_column.dart';
import '../model/row_height.dart';
import '../theme/fitgrid_theme.dart';
import 'column_layout.dart';
import 'row_metrics.dart';

/// Turns a [FitGridRowHeight] policy into [FitGridRowMetrics] — the heights and
/// offsets the render layer scrolls, paints and hit-tests against.
///
/// The counterpart to [FitGridColumnSizer], and it has the harder job: column
/// measurement is bounded by the number of columns, while row measurement is
/// bounded by the number of rows, and this package exists to avoid paying
/// anything per row.
///
/// Two things keep that honest:
///
/// * **Only wrapping columns are measured.** A column with `maxLines: 1`
///   occupies exactly one line whatever it contains, so its contribution is the
///   line height of its style — computed once for the whole grid, not once per
///   cell. Only columns that can wrap need a `TextPainter` per row.
/// * **A grid with no wrapping columns never measures at all.** It resolves to
///   uniform metrics, which is the same O(1) geometry a fixed row height gets.
///   That is the common case, and it costs nothing to ask for content sizing
///   and not need it.
///
/// What is left — a grid that really does wrap — is O(rows x wrapping columns)
/// `TextPainter` layouts, once per change to the data, the column widths or the
/// theme. That is a real cost and there is no way around it: the scrollbar
/// cannot be right until every row's height is known. Clamp such a column's
/// width so the wrap point is stable, and prefer [FitGridRowHeight.fixed] for
/// datasets where the cost would show.
class FitGridRowSizer {
  FitGridRowSizer();

  final TextPainter _painter = TextPainter();

  /// Resolves every row to a height.
  ///
  /// [layout] must be the resolved column layout for the same frame: how tall a
  /// wrapped cell is depends entirely on how wide its column ended up.
  FitGridRowMetrics resolve<T>({
    required FitGridRowHeight? policy,
    required List<FitGridColumn<T>> columns,
    required List<T> rows,
    required FitGridColumnLayout layout,
    required FitGridThemeData theme,
    required TextDirection textDirection,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final rowCount = rows.length;

    switch (policy) {
      case FitGridFixedRowHeight(:final pixels):
        return FitGridRowMetrics.uniform(rowCount: rowCount, rowHeight: pixels);

      case null:
        return FitGridRowMetrics.uniform(
          rowCount: rowCount,
          rowHeight: theme.effectiveRowHeight,
        );

      case FitGridContentRowHeight():
        return _measure(
          policy: policy,
          columns: columns,
          rows: rows,
          layout: layout,
          theme: theme,
          textDirection: textDirection,
          textScaler: textScaler,
        );
    }
  }

  FitGridRowMetrics _measure<T>({
    required FitGridContentRowHeight policy,
    required List<FitGridColumn<T>> columns,
    required List<T> rows,
    required FitGridColumnLayout layout,
    required FitGridThemeData theme,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final padding = theme.effectiveCellPadding;
    final chrome = padding.vertical + theme.dividerThickness;

    // The height of one line in the theme's cell style, which is what every
    // single-line column contributes no matter what is in it. Measured against
    // a glyph with both an ascender and a descender so the value matches what a
    // real cell lays out to.
    final lineHeight = _heightOf(
      'Ag',
      theme.cellTextStyle,
      textDirection,
      textScaler,
      maxLines: 1,
      maxWidth: double.infinity,
    );
    final singleLine = policy.clamp(lineHeight + chrome);

    // Columns that can occupy more than one line, paired with the width their
    // text has to fit into. Everything else is already accounted for by
    // [singleLine].
    final wrapping = <(FitGridColumn<T>, double)>[];
    for (var i = 0; i < columns.length && i < layout.length; i++) {
      final column = columns[i];
      if (column.maxLines == 1 || column.cellBuilder != null) continue;
      final available = layout.widths[i] - padding.horizontal;
      if (available <= 0) continue;
      wrapping.add((column, available));
    }

    if (wrapping.isEmpty || rows.isEmpty) {
      return FitGridRowMetrics.uniform(
        rowCount: rows.length,
        rowHeight: singleLine,
      );
    }

    final heights = List<double>.filled(rows.length, singleLine);
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      var tallest = lineHeight;
      for (final (column, available) in wrapping) {
        final text = column.value(row);
        if (text.isEmpty) continue;
        final height = _heightOf(
          text,
          column.cellStyle?.call(row, r) ?? theme.cellTextStyle,
          textDirection,
          textScaler,
          maxLines: column.maxLines,
          maxWidth: available,
        );
        if (height > tallest) tallest = height;
      }
      heights[r] = policy.clamp(tallest + chrome);
    }

    return FitGridRowMetrics.measured(heights);
  }

  double _heightOf(
    String text,
    TextStyle style,
    TextDirection textDirection,
    TextScaler textScaler, {
    required int? maxLines,
    required double maxWidth,
  }) {
    _painter
      ..text = TextSpan(text: text, style: style)
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..layout(maxWidth: maxWidth);
    return _painter.height;
  }

  void dispose() => _painter.dispose();
}
