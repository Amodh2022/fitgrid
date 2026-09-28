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
  FitGridColumnSizer({this.measurementBudget = 2000})
    : assert(measurementBudget > 0);

  /// How many rows one pass of [FitGridAutoWidth.measureAllRows] may measure.
  ///
  /// Measuring a hundred thousand rows takes longer than a frame, and a first
  /// frame that never arrives is worse than a column that is briefly a little
  /// narrow. Past this budget the pass stops, reports itself incomplete through
  /// [isComplete], and resumes on the next build with the widths it has —
  /// which only ever grow, so the column widens towards the truth instead of
  /// jumping around on the way there.
  final int measurementBudget;

  final TextPainter _painter = TextPainter(maxLines: 1);

  /// Identity of the (columns, rows) pair the progress below belongs to.
  Object? _progressKey;

  /// Everything but the rows that the cached measurements depend on.
  Object? _baseKey;

  /// The rows the cached measurements were taken from. Held so the next list
  /// can be compared against it element by element.
  List<Object?>? _measuredList;

  /// The longest cells of each sampled column, with the row each came from.
  final Map<String, List<(int, String)>> _candidates =
      <String, List<(int, String)>>{};

  /// Measured header labels, by label.
  final Map<String, double> _labelWidths = <String, double>{};

  /// The widest measured candidate of each sampled column, so an update that
  /// leaves the candidates alone costs no text layout at all.
  final Map<String, double> _candidateWidest = <String, double>{};

  /// How many rows of each exhaustively-measured column have been seen.
  final Map<String, int> _measuredRows = <String, int>{};

  /// The widest value seen so far in each of those columns.
  final Map<String, double> _widest = <String, double>{};

  bool _isComplete = true;

  /// Whether the last [resolve] measured everything it was asked to.
  ///
  /// False means the widths on screen are provisional and the caller should
  /// build again to continue. [FitGrid] does that for you.
  bool get isComplete => _isComplete;

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
    double headerExtra = 0.0,
    Map<String, (String?, String)> footerTexts =
        const <String, (String?, String)>{},
  }) {
    // Already partitioned when the caller came through the controller; doing
    // it again is O(columns) and keeps a direct caller honest.
    final visible = fitGridVisibleColumns(columns);
    if (visible.isEmpty) {
      _isComplete = true;
      return FitGridColumnLayout.empty;
    }

    // Measurements belong to one set of columns under one style. A new row
    // list under the same columns is usually a live update: most of its rows
    // are the very objects measured last time, and only the replaced ones need
    // looking at. [changed] lists those, or is null when everything must be
    // measured again.
    final baseKey = Object.hash(
      identityHashCode(columns),
      theme,
      textDirection,
      textScaler,
    );
    final previous = _measuredList;
    List<int>? changed;
    if (_baseKey == baseKey && previous != null) {
      changed = identical(previous, rows)
          ? const <int>[]
          : _changedRows(previous, rows);
    }
    if (_baseKey != baseKey) _labelWidths.clear();
    if (changed == null) {
      _candidates.clear();
      _candidateWidest.clear();
    }
    _baseKey = baseKey;
    _measuredList = rows;

    final progressKey = Object.hash(baseKey, identityHashCode(rows));
    if (_progressKey != progressKey) {
      _progressKey = progressKey;
      if (changed == null) {
        _measuredRows.clear();
        _widest.clear();
      }
    }
    _isComplete = true;
    var budget = measurementBudget;

    // [headerExtra] is room for header chrome every column carries — the
    // column menu button — so a column sized to its label still has space
    // to show it.
    final headerChrome =
        theme.effectiveHeaderPadding.horizontal +
        theme.dividerThickness +
        headerExtra;
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
              footerTexts[column.id],
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
              footerTexts[column.id],
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
            footerTexts[column.id],
          );

          // A widget cell's width is whatever the widget wants, which text
          // measurement cannot see. Measuring its fallback string would size the
          // column to something nobody renders, so leave such columns to their
          // header and to any explicit min.
          if (column.cellBuilder == null && rows.isNotEmpty) {
            if (measureAllRows) {
              // Exhaustive measurement is the expensive path, so it is the one
              // that gets rationed. Each pass picks up where the last left off.
              var from = _measuredRows[column.id] ?? 0;
              widest = math.max(widest, _widest[column.id] ?? 0);
              // Replaced rows already passed over are measured now; the rest
              // are reached by the pass as it continues. A value that got
              // shorter does not narrow the column until the rows are
              // replaced wholesale — under a live feed that is what keeps the
              // columns still.
              for (final index in changed ?? const <int>[]) {
                if (index >= from) continue;
                final text = column.value(rows[index]);
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
              final to = math.min(rows.length, from + budget);
              for (; from < to; from++) {
                final text = column.value(rows[from]);
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
              budget -= to - (_measuredRows[column.id] ?? 0);
              _measuredRows[column.id] = to;
              _widest[column.id] = widest;
              if (to < rows.length) _isComplete = false;
              if (budget <= 0) budget = 0;
            } else {
              final cached = _candidates[column.id];
              var candidates = cached;
              if (cached == null ||
                  !_updateCandidates(
                    column.id,
                    cached,
                    rows,
                    changed!,
                    column.value,
                    sampleSize,
                  )) {
                candidates = _longestByChars(rows, column.value, sampleSize);
                _candidates[column.id] = candidates;
                _candidateWidest.remove(column.id);
              }
              var sampled = _candidateWidest[column.id];
              if (sampled == null) {
                sampled = 0.0;
                for (final (_, text) in candidates!) {
                  final width =
                      _measure(
                        text,
                        theme.cellTextStyle,
                        textDirection,
                        textScaler,
                      ) +
                      cellChrome;
                  if (width > sampled!) sampled = width;
                }
                _candidateWidest[column.id] = sampled!;
              }
              widest = math.max(widest, sampled);
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
        resized: overrides,
      );
    }

    return FitGridColumnLayout(
      ids: <String>[for (final column in visible) column.id],
      widths: widths,
      freezes: <FitGridFreeze>[for (final column in visible) column.freeze],
    );
  }

  /// Width this column needs for its own header, including sort affordance.
  /// Width this column needs for its own header — and for its footer total,
  /// when it has one, so a sum wider than every cell above it is not cut off.
  double _headerWidth<T>(
    FitGridColumn<T> column,
    FitGridThemeData theme,
    double chrome,
    TextDirection textDirection,
    TextScaler textScaler, [
    (String?, String)? footer,
  ]) {
    // Labels do not change with the rows, so they are measured once per set
    // of columns and style — the cache is dropped with the others.
    final text = _labelWidths[column.label] ??= _measure(
      column.label,
      theme.headerTextStyle,
      textDirection,
      textScaler,
    );
    final sortAffordance = column.sortable ? theme.sortIconSize + 4 : 0.0;
    final header = text + chrome + sortAffordance;
    if (footer == null) return header;
    final (label, value) = footer;
    // Measured as the footer paints it: one line, the label and two spaces
    // before the value, in the header style (only the colours differ), inside
    // the header padding.
    final footerWidth =
        _measure(
          label == null ? value : '$label  $value',
          theme.headerTextStyle,
          textDirection,
          textScaler,
        ) +
        theme.effectiveHeaderPadding.horizontal +
        theme.dividerThickness;
    return math.max(header, footerWidth);
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
  ///
  /// A column in [resized] keeps the width it was dragged to. Stretching it
  /// would move its divider away from the pointer that is holding it: the drag
  /// sets a width and the stretch scales it up again, so the edge would jump
  /// on the first move and then run ahead of the finger.
  static void _distributeLeftover<T>({
    required List<double> widths,
    required List<FitGridColumn<T>> columns,
    required List<int> flexIndices,
    required double leftover,
    required bool stretchToFill,
    required Map<String, double> resized,
  }) {
    final growable = flexIndices.isNotEmpty
        ? flexIndices
        : stretchToFill
        ? <int>[
            for (var i = 0; i < columns.length; i++)
              if (columns[i].width is FitGridAutoWidth &&
                  !resized.containsKey(columns[i].id))
                i,
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

  /// The indices at which [next] holds a different object from [previous],
  /// or null when so much has changed — a different length, or a sizeable
  /// share of the rows — that measuring from scratch is the cheaper answer.
  static List<int>? _changedRows(List<Object?> previous, List<Object?> next) {
    if (previous.length != next.length) return null;
    final limit = next.length ~/ 4;
    final changed = <int>[];
    for (var i = 0; i < next.length; i++) {
      if (identical(previous[i], next[i])) continue;
      if (changed.length >= limit) return null;
      changed.add(i);
    }
    return changed;
  }

  /// Folds the replaced rows into a column's candidates in place. Returns
  /// false when that cannot be done honestly — one of the candidates was
  /// itself replaced, so its row may now be shorter and the true top-k is
  /// unknown — and the column has to be scanned again.
  ///
  /// Clears the column's cached width when a candidate was added.
  bool _updateCandidates<T>(
    String id,
    List<(int, String)> candidates,
    List<T> rows,
    List<int> changed,
    String Function(T) value,
    int k,
  ) {
    if (changed.isEmpty) return true;
    for (final (index, _) in candidates) {
      // Both short lists; the candidates are at most a few dozen.
      if (changed.contains(index)) return false;
    }
    var grew = false;
    for (final index in changed) {
      grew = _offer(candidates, index, value(rows[index]), k) || grew;
    }
    if (grew) _candidateWidest.remove(id);
    return true;
  }

  /// The up-to-[k] longest cell strings in a column, by character count, with
  /// the row each came from.
  ///
  /// A bounded insertion into a short list kept sorted by length descending:
  /// O(rows x k) with a tiny k, and no full-column sort or intermediate list.
  /// Strings tying the k-th length are kept rather than dropped, so a genuine
  /// candidate is never discarded before it has been measured.
  static List<(int, String)> _longestByChars<T>(
    List<T> rows,
    String Function(T) value,
    int k,
  ) {
    final top = <(int, String)>[];
    for (var i = 0; i < rows.length; i++) {
      _offer(top, i, value(rows[i]), k);
    }
    return top;
  }

  /// Offers one cell to a candidate list. Returns whether it was kept.
  static bool _offer(List<(int, String)> top, int index, String text, int k) {
    if (text.isEmpty) return false;
    final length = text.length;
    if (top.length >= k && length <= top.last.$2.length) return false;

    var position = top.length;
    while (position > 0 && top[position - 1].$2.length < length) {
      position--;
    }
    top.insert(position, (index, text));

    while (top.length > k && top.last.$2.length < top[k - 1].$2.length) {
      top.removeLast();
    }
    return true;
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
