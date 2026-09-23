import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../model/column_width.dart';
import '../model/enums.dart';
import '../model/fitgrid_column.dart';
import '../theme/fitgrid_theme.dart';
import 'column_layout.dart';
import 'column_order.dart';

/// Turns column width *policies* into actual pixel widths by measuring the
/// content.
///
/// The measurement itself is the expensive part — `TextPainter.layout` is not
/// something you want to run once per cell of a large table — so the work is
/// bounded in two ways. Candidate strings are first narrowed by character
/// count, which is arithmetic; only the survivors are laid out. And the scratch
/// painter is reused across every measurement rather than allocated per cell.
///
/// Character count is a proxy for rendered width, not a guarantee: in a
/// proportional font "WWW" is wider than "lllllll". Sampling several of the
/// longest candidates rather than just the single longest is what keeps that
/// approximation honest, and
/// [FitGridAutoWidth.measureAllRows] escapes it entirely when a table is small
/// enough to afford the truth.
class FitGridColumnSizer {
  FitGridColumnSizer();

  final TextPainter _painter = TextPainter(maxLines: 1);

  /// Resolves every visible column to a width.
  ///
  /// [overrides] are widths the user has dragged a column to; they win over the
  /// column's own policy but are still clamped by it, so a resize cannot push a
  /// column past its declared bounds.
  FitGridColumnLayout resolve<T>({
    required List<FitGridColumn<T>> columns,
    required List<T> rows,
    required FitGridThemeData theme,
    required double availableWidth,
    required TextDirection textDirection,
    TextScaler textScaler = TextScaler.noScaling,
    Map<String, double> overrides = const <String, double>{},
    bool stretchToFill = true,
  }) {
    // Already partitioned when the caller came through the controller; doing
    // it again is O(columns) and keeps a direct caller honest.
    final visible = fitGridVisibleColumns(columns);
    if (visible.isEmpty) return FitGridColumnLayout.empty;

    final headerChrome =
        theme.effectiveHeaderPadding.horizontal + theme.dividerThickness;
    final cellChrome =
        theme.effectiveCellPadding.horizontal + theme.dividerThickness;

    final widths = List<double>.filled(visible.length, 0.0);
    final flexIndices = <int>[];

    for (var i = 0; i < visible.length; i++) {
      final column = visible[i];
      final policy = column.width;

      final override = overrides[column.id];
      if (override != null) {
        widths[i] = policy.clamp(override);
        continue;
      }

      switch (policy) {
        case FitGridFixedWidth(:final pixels):
          widths[i] = pixels;

        case FitGridFitHeaderWidth():
          widths[i] = policy.clamp(
            _headerWidth(
              column,
              theme,
              headerChrome,
              textDirection,
              textScaler,
            ),
          );

        case FitGridFlexWidth():
          // Flex columns are sized from the leftover pass below. Seed them with
          // their header width so that a flex column is never narrower than its
          // own label even when there is no leftover to hand out.
          widths[i] = policy.clamp(
            _headerWidth(
              column,
              theme,
              headerChrome,
              textDirection,
              textScaler,
            ),
          );
          flexIndices.add(i);

        case FitGridAutoWidth(:final sampleSize, :final measureAllRows):
          var widest = _headerWidth(
            column,
            theme,
            headerChrome,
            textDirection,
            textScaler,
          );

          // A widget cell's width is whatever the widget wants, which text
          // measurement cannot see. Measuring its fallback string would size the
          // column to something nobody renders, so leave such columns to their
          // header and to any explicit min.
          if (column.cellBuilder == null && rows.isNotEmpty) {
            final candidates = measureAllRows
                ? rows.map(column.value)
                : _longestByChars(rows, column.value, sampleSize);
            for (final text in candidates) {
              if (text.isEmpty) continue;
              final width =
                  _measure(
                    text,
                    theme.cellTextStyle,
                    textDirection,
                    textScaler,
                  ) +
                  cellChrome;
              if (width > widest) widest = width;
            }
          }
          widths[i] = policy.clamp(widest);
      }
    }

    final intrinsicTotal = widths.fold<double>(0.0, (sum, w) => sum + w);
    if (intrinsicTotal < availableWidth) {
      _distributeLeftover(
        widths: widths,
        columns: visible,
        flexIndices: flexIndices,
        leftover: availableWidth - intrinsicTotal,
        stretchToFill: stretchToFill,
      );
    }

    return FitGridColumnLayout(
      ids: <String>[for (final column in visible) column.id],
      widths: widths,
      freezes: <FitGridFreeze>[for (final column in visible) column.freeze],
    );
  }

  /// Width this column needs for its own header, including sort affordance.
  double _headerWidth<T>(
    FitGridColumn<T> column,
    FitGridThemeData theme,
    double chrome,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    final text = _measure(
      column.label,
      theme.headerTextStyle,
      textDirection,
      textScaler,
    );
    final sortAffordance = column.sortable ? theme.sortIconSize + 4 : 0.0;
    return text + chrome + sortAffordance;
  }

  /// Hands unused horizontal space to the columns that asked for it.
  ///
  /// Flex columns take priority and split the leftover by their flex factors —
  /// that is what declaring `flex` means. Only when there are none does the
  /// leftover get spread across auto columns in proportion to what they already
  /// need, so a naturally wide column grows more than a naturally narrow one
  /// rather than every column inflating by the same amount.
  ///
  /// Both passes iterate: clamping a column to its max frees up space that the
  /// remaining columns should get, so the surplus is recirculated until it is
  /// spent or nobody can absorb it.
  static void _distributeLeftover<T>({
    required List<double> widths,
    required List<FitGridColumn<T>> columns,
    required List<int> flexIndices,
    required double leftover,
    required bool stretchToFill,
  }) {
    final growable = flexIndices.isNotEmpty
        ? flexIndices
        : stretchToFill
        ? <int>[
            for (var i = 0; i < columns.length; i++)
              if (columns[i].width is FitGridAutoWidth) i,
          ]
        : const <int>[];
    if (growable.isEmpty) return;

    final byFlex = flexIndices.isNotEmpty;
    var remaining = leftover;
    final open = List<int>.of(growable);

    while (remaining > 0.01 && open.isNotEmpty) {
      var shareTotal = 0.0;
      for (final i in open) {
        shareTotal += byFlex
            ? (columns[i].width as FitGridFlexWidth).flex.toDouble()
            : widths[i];
      }
      if (shareTotal <= 0) return;

      final budget = remaining;
      var consumed = 0.0;
      final saturated = <int>[];

      for (final i in open) {
        final share = byFlex
            ? (columns[i].width as FitGridFlexWidth).flex.toDouble()
            : widths[i];
        final wanted = widths[i] + budget * share / shareTotal;
        final granted = columns[i].width.clamp(wanted);
        consumed += granted - widths[i];
        widths[i] = granted;
        if (granted < wanted) saturated.add(i);
      }

      remaining -= consumed;
      if (saturated.isEmpty) break;
      open.removeWhere(saturated.contains);
    }
  }

  /// The up-to-[k] longest cell strings in a column, by character count.
  ///
  /// A bounded insertion into a short list kept sorted by length descending:
  /// O(rows x k) with a tiny k, and no full-column sort or intermediate list.
  /// Strings tying the k-th length are kept rather than dropped, so a genuine
  /// candidate is never discarded before it has been measured.
  static List<String> _longestByChars<T>(
    List<T> rows,
    String Function(T) value,
    int k,
  ) {
    final top = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final text = value(rows[i]);
      if (text.isEmpty) continue;
      final length = text.length;
      if (top.length >= k && length <= top.last.length) continue;

      var position = top.length;
      while (position > 0 && top[position - 1].length < length) {
        position--;
      }
      top.insert(position, text);

      while (top.length > k && top.last.length < top[k - 1].length) {
        top.removeLast();
      }
    }
    return top;
  }

  double _measure(
    String text,
    TextStyle style,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    _painter
      ..text = TextSpan(text: text, style: style)
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..layout();
    // maxIntrinsicWidth, not width: `width` is the laid-out width, which for a
    // single unconstrained line is the same thing, but the intrinsic value
    // stays correct if maxLines ever changes underneath us.
    return math.max(_painter.width, _painter.maxIntrinsicWidth);
  }

  void dispose() => _painter.dispose();
}
