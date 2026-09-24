import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/enums.dart';
import '../sizing/column_layout.dart';
import '../sizing/row_metrics.dart';
import '../theme/fitgrid_theme.dart';
import 'cell_spec.dart';

/// Pulls the spec for one cell on demand.
///
/// A callback rather than a precomputed list, because precomputing specs for
/// every row is exactly the O(rows) work that virtualization exists to avoid.
/// It is only ever called for cells inside the current window.
typedef FitGridCellSpecResolver =
    FitGridCellSpec Function(int rowIndex, int columnIndex);

/// Resolves a row's background, or null to use the theme's striping.
typedef FitGridRowColorResolver = Color? Function(int rowIndex);

/// Whether a row is selected. Used for semantics, where "selected" is a state
/// a screen reader announces rather than merely a colour.
typedef FitGridRowFlagResolver = bool Function(int rowIndex);

/// How many columns a cell covers, starting at its own. 1 is an ordinary cell.
///
/// Merged cells are how a group header gets to be a sentence rather than a
/// sentence clipped to the width of the first column, and they are the same
/// mechanism a host uses to span a banner across a row.
typedef FitGridCellSpanResolver = int Function(int rowIndex, int columnIndex);

/// Extra indentation for a row's first cell, in pixels. Drives the nesting of
/// grouped and tree rows without any of them being a separate kind of row.
typedef FitGridRowIndentResolver = double Function(int rowIndex);

/// The headers to keep pinned while [firstRow] is the first row on screen,
/// outermost first — the group the row is in, the group around that, and so
/// on. Rows are indices into the section.
typedef FitGridStickyChainResolver = List<int> Function(int firstRow);

/// The first row after a pinned header's group — where the next header at its
/// level, or the end, begins. It is what pushes the pinned header up and off.
typedef FitGridGroupEndResolver = int Function(int headerRow);

/// Parent data for overlay children — the real widgets layered over the
/// painted grid for cells that need interactivity or chrome.
class FitGridCellParentData extends ContainerBoxParentData<RenderBox> {
  /// Absolute row index, not an index into the visible window.
  int rowIndex = -1;

  /// Index into the visible columns of the section's [FitGridColumnLayout],
  /// or [fullRow] for a child that spans the whole row.
  int columnIndex = -1;

  /// The [columnIndex] of a child laid across the full width of the section —
  /// a detail panel — rather than into one column. It ignores the bands: it
  /// neither scrolls sideways nor hides beneath a pinned column.
  static const int fullRow = -2;
}

/// Paints a rectangular block of grid cells as text, with real widgets layered
/// over the cells that need them.
///
/// The point of the exercise: a 40 x 8 block of text is 320 widgets, elements
/// and render objects in a conventional table, each with its own layout and
/// paint. Here it is one `RenderBox`, a handful of cached `TextPainter`s, and a
/// single batched line draw for the grid rules. Widgets are spent only where
/// they buy something.
///
/// Four things keep that from degrading:
///
/// * **Windowing.** Only rows in `[firstVisibleRow, firstVisibleRow +
///   visibleRowCount)` and columns intersecting the horizontal viewport are
///   touched, so cost tracks the viewport rather than the dataset.
/// * **Painter caching.** A cell's `TextPainter` survives across paints and is
///   re-laid-out only when its spec or its column width changes. The cache is
///   pruned to the window, so it stays bounded by what is on screen.
/// * **Batched rules.** Every divider in a band is one
///   `drawRawPoints(PointMode.lines)` over a reused `Float32List`, not a
///   `drawLine` per edge.
/// * **Banded painting.** Pinned columns are not a second render object. They
///   are index ranges at either end of the same layout, painted into their own
///   clip after the scrolling band, which is why freezing a column costs a
///   clip rather than a parallel widget tree.
///
/// Painted cells are invisible to the accessibility tree unless someone puts
/// them there, so this render object assembles its own: a `table` node holding
/// one `row` per visible row and one `cell` per visible cell. That is the price
/// of painting rather than building, and it is paid here, once, instead of
/// being left to the caller.
class RenderFitGridSection extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FitGridCellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FitGridCellParentData> {
  RenderFitGridSection({
    required FitGridColumnLayout columnLayout,
    required List<FitGridPaintColumn> paintColumns,
    required FitGridCellSpecResolver cellSpec,
    required int specVersion,
    required FitGridThemeData theme,
    required TextDirection textDirection,
    required FitGridRowMetrics rowMetrics,
    required ViewportOffset vertical,
    required ViewportOffset horizontal,
    int overscanRows = 2,
    TextScaler textScaler = TextScaler.noScaling,
    FitGridRowColorResolver? rowColor,
    FitGridRowFlagResolver? isRowSelected,
    bool striped = true,
    int editingRow = -1,
    int editingColumn = -1,
    int focusedRow = -1,
    int focusedColumn = -1,
    int hoveredRow = -1,
    (int, int, int, int) selectedRange = noRange,
    int dropLine = -1,
    (int, int) fillHandleCell = (-1, -1),
    (int, int, int, int) fillPreview = noRange,
    int rowIndexOffset = 0,
    FitGridCellSpanResolver? cellSpan,
    FitGridRowIndentResolver? rowIndent,
    FitGridRowFlagResolver? isFullRow,
    FitGridStickyChainResolver? stickyChain,
    FitGridGroupEndResolver? groupEnd,
    void Function(int row, int column)? onCellActivate,
  }) : _columnLayout = columnLayout,
       _paintColumns = paintColumns,
       _cellSpec = cellSpec,
       _specVersion = specVersion,
       _theme = theme,
       _textDirection = textDirection,
       _rowMetrics = rowMetrics,
       _vertical = vertical,
       _horizontal = horizontal,
       _overscanRows = overscanRows,
       _textScaler = textScaler,
       _rowColor = rowColor,
       _isRowSelected = isRowSelected,
       _striped = striped,
       _editingRow = editingRow,
       _editingColumn = editingColumn,
       _focusedRow = focusedRow,
       _focusedColumn = focusedColumn,
       _hoveredRow = hoveredRow,
       _selectedRange = selectedRange,
       _dropLine = dropLine,
       _fillHandleCell = fillHandleCell,
       _fillPreview = fillPreview,
       _rowIndexOffset = rowIndexOffset,
       _cellSpan = cellSpan,
       _rowIndent = rowIndent,
       _isFullRow = isFullRow,
       _stickyChain = stickyChain,
       _groupEnd = groupEnd,
       _onCellActivate = onCellActivate;

  // ---------------------------------------------------------------- geometry

  FitGridColumnLayout _columnLayout;

  /// Resolved widths, offsets and pinning of the visible columns.
  ///
  /// Not named `layout` because [RenderObject.layout] already owns that name,
  /// and shadowing it makes `section.layout(constraints)` silently resolve to a
  /// field.
  FitGridColumnLayout get columnLayout => _columnLayout;
  set columnLayout(FitGridColumnLayout value) {
    if (_columnLayout == value) return;
    _columnLayout = value;
    // Column widths changed, so every cached painter's line-break width is
    // stale.
    _clearCache();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  List<FitGridPaintColumn> _paintColumns;
  List<FitGridPaintColumn> get paintColumns => _paintColumns;
  set paintColumns(List<FitGridPaintColumn> value) {
    if (listEquals(_paintColumns, value)) return;
    _paintColumns = value;
    _clearCache();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  FitGridRowMetrics _rowMetrics;

  /// Where every row sits and how tall it is.
  ///
  /// Row count lives here rather than beside it: a count without the heights
  /// that go with it is half a geometry, and keeping them in one object is what
  /// stops the two from ever disagreeing mid-layout.
  FitGridRowMetrics get rowMetrics => _rowMetrics;
  set rowMetrics(FitGridRowMetrics value) {
    if (identical(_rowMetrics, value) || _rowMetrics == value) return;
    _rowMetrics = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  int get rowCount => _rowMetrics.rowCount;

  /// Height of a single row.
  double rowHeightAt(int row) => _rowMetrics.heightOf(row);

  /// Top edge of a row in content space.
  double rowOffsetAt(int row) => _rowMetrics.offsetOf(row);

  // ----------------------------------------------------------------- window

  // The window is derived, not supplied. It falls out of the viewport size
  // (known at layout) and the scroll position (known from the offsets), so
  // nothing upstream has to compute it — and, more to the point, no ancestor
  // has to reach in and mutate this render object during its own layout, which
  // the framework rightly forbids.

  ViewportOffset _vertical;
  ViewportOffset get vertical => _vertical;
  set vertical(ViewportOffset value) {
    if (_vertical == value) return;
    if (attached) _vertical.removeListener(markNeedsLayout);
    _vertical = value;
    if (attached) _vertical.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  ViewportOffset _horizontal;
  ViewportOffset get horizontal => _horizontal;
  set horizontal(ViewportOffset value) {
    if (_horizontal == value) return;
    if (attached) _horizontal.removeListener(markNeedsLayout);
    _horizontal = value;
    if (attached) _horizontal.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  int _overscanRows;

  /// Extra rows laid out above and below the viewport, so a fast fling has
  /// something to show while the next frame is being built.
  int get overscanRows => _overscanRows;
  set overscanRows(int value) {
    if (_overscanRows == value) return;
    _overscanRows = value;
    markNeedsLayout();
  }

  /// Builds the widget cells for a window of rows, `[first, last)`.
  ///
  /// Set by the section's element. It runs inside [performLayout], through
  /// [invokeLayoutCallback], because only layout knows which rows are on
  /// screen: the grid scrolls by relaying this object out, not by rebuilding,
  /// so a list of children decided in build would always be a frame behind.
  void Function(int first, int last)? cellBuilder;

  bool _cellsNeedBuild = true;
  (int, int) _builtWindow = (-1, -1);

  /// Asks for the widget cells to be rebuilt at the next layout, because what
  /// they show may have changed even though the window has not.
  void markCellsNeedBuild() {
    _cellsNeedBuild = true;
    markNeedsLayout();
  }

  int _firstVisibleRow = 0;

  /// First row in the current window, including overscan.
  int get firstVisibleRow => _firstVisibleRow;

  int _visibleRowCount = 0;

  /// How many rows the current window spans, including overscan.
  int get visibleRowCount => _visibleRowCount;

  double _horizontalOffset = 0.0;

  /// Current horizontal scroll position, in content pixels.
  double get horizontalOffset => _horizontalOffset;

  double _verticalOffset = 0.0;

  /// Current vertical scroll position, in content pixels.
  double get verticalOffset => _verticalOffset;

  /// Furthest the scrolling band can be scrolled horizontally.
  double get maxHorizontalOffset =>
      math.max(0.0, _columnLayout.scrollableWidth - _scrollableExtent);

  /// Screen width left for the columns that actually scroll, once both pinned
  /// bands have taken their share.
  double get _scrollableExtent => math.max(
    0.0,
    size.width -
        _columnLayout.leadingFrozenWidth -
        _columnLayout.trailingFrozenWidth,
  );

  // ----------------------------------------------------------------- content

  FitGridCellSpecResolver _cellSpec;

  /// The resolver itself is swapped freely without invalidating anything: the
  /// widget layer rebuilds the closure on every build, so its identity says
  /// nothing about whether the underlying data moved. [specVersion] is what
  /// actually reports that.
  set cellSpec(FitGridCellSpecResolver value) => _cellSpec = value;

  int _specVersion;

  /// Changes whenever the data behind [cellSpec] changes.
  ///
  /// Without this the cache would either be cleared on every build (throwing
  /// away the painters that make scrolling cheap) or never (painting stale
  /// text after a sort). The widget layer derives it from the identity of the
  /// row list, the columns and the theme.
  int get specVersion => _specVersion;
  set specVersion(int value) {
    if (_specVersion == value) return;
    _specVersion = value;
    _clearCache();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  FitGridThemeData _theme;
  FitGridThemeData get theme => _theme;
  set theme(FitGridThemeData value) {
    if (_theme == value) return;
    _theme = value;
    _clearCache();
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _clearCache();
    markNeedsLayout();
  }

  TextScaler _textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    _clearCache();
    markNeedsLayout();
  }

  FitGridRowColorResolver? _rowColor;
  set rowColor(FitGridRowColorResolver? value) {
    if (_rowColor == value) return;
    _rowColor = value;
    markNeedsPaint();
  }

  FitGridRowFlagResolver? _isRowSelected;
  set isRowSelected(FitGridRowFlagResolver? value) {
    if (_isRowSelected == value) return;
    _isRowSelected = value;
    markNeedsSemanticsUpdate();
  }

  bool _striped;
  set striped(bool value) {
    if (_striped == value) return;
    _striped = value;
    markNeedsPaint();
  }

  int _editingRow;
  int _editingColumn;

  /// The cell currently covered by an editor, or (-1, -1).
  ///
  /// Its painted text is skipped: the editor is an overlay child sitting on top
  /// of it, and painting the old value underneath would show through anything
  /// translucent and double up on anything that is not.
  (int, int) get editingCell => (_editingRow, _editingColumn);
  set editingCell((int, int) value) {
    final (row, column) = value;
    if (_editingRow == row && _editingColumn == column) return;
    _editingRow = row;
    _editingColumn = column;
    markNeedsPaint();
  }

  int _focusedRow;
  int _focusedColumn;

  /// The cell carrying the keyboard focus ring, or (-1, -1).
  (int, int) get focusedCell => (_focusedRow, _focusedColumn);
  set focusedCell((int, int) value) {
    final (row, column) = value;
    if (_focusedRow == row && _focusedColumn == column) return;
    _focusedRow = row;
    _focusedColumn = column;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int _hoveredRow;

  /// The row under the pointer, or -1. Painted rather than built, for the same
  /// reason everything else here is: a hover highlight should not cost a
  /// `MouseRegion` per row.
  int get hoveredRow => _hoveredRow;
  set hoveredRow(int value) {
    if (_hoveredRow == value) return;
    _hoveredRow = value;
    markNeedsPaint();
  }

  /// The empty range: nothing selected.
  static const (int, int, int, int) noRange = (-1, -1, -1, -1);

  (int, int, int, int) _selectedRange;

  /// The selected block of cells as (first row, last row, first column, last
  /// column), inclusive and in this section's own indices, or [noRange].
  ///
  /// Painted as a wash with an outline, in the same pass as everything else,
  /// so a range over ten thousand cells costs one rectangle per band.
  (int, int, int, int) get selectedRange => _selectedRange;
  set selectedRange((int, int, int, int) value) {
    if (_selectedRange == value) return;
    _selectedRange = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int _dropLine;

  /// Where a dragged row would land: a line is drawn along the top edge of
  /// this row, or along the bottom of the last row when it equals the row
  /// count. -1 draws nothing.
  int get dropLine => _dropLine;
  set dropLine(int value) {
    if (_dropLine == value) return;
    _dropLine = value;
    markNeedsPaint();
  }

  (int, int) _fillHandleCell;

  /// The cell whose far corner carries the fill handle — the corner of the
  /// selected range — or (-1, -1) for none.
  (int, int) get fillHandleCell => _fillHandleCell;
  set fillHandleCell((int, int) value) {
    if (_fillHandleCell == value) return;
    _fillHandleCell = value;
    markNeedsPaint();
  }

  (int, int, int, int) _fillPreview;

  /// The block a fill drag would write, outlined while the drag is under way.
  set fillPreview((int, int, int, int) value) {
    if (_fillPreview == value) return;
    _fillPreview = value;
    markNeedsPaint();
  }

  /// The fill handle's box in this box's own coordinates, or null.
  Rect? get fillHandleRect {
    final (row, column) = _fillHandleCell;
    if (row < 0 || row >= rowCount) return null;
    if (column < 0 || column >= _columnLayout.length) return null;
    final side = _theme.fillHandleSize;
    final left = _screenLeft(column);
    final x = _textDirection == TextDirection.ltr
        ? left + _columnLayout.widths[column]
        : left;
    final y = _rowMetrics.offsetOf(row + 1) - _verticalOffset;
    // Kept inside the section: on the last column, or the last row at the
    // bottom of the viewport, a handle centred on the corner would hang half
    // outside — half hidden, and half beyond where a press can reach it.
    final half = side / 2;
    return Rect.fromCenter(
      center: Offset(
        x.clamp(half, math.max(half, size.width - half)),
        y.clamp(half, math.max(half, size.height - half)),
      ),
      width: side,
      height: side,
    );
  }

  /// Whether a local position is on the fill handle, with a margin: a
  /// seven-pixel square is a fine thing to see and a poor thing to aim at.
  bool hitsFillHandle(Offset position, {double slop = 6}) =>
      fillHandleRect?.inflate(slop).contains(position) ?? false;

  bool _inRange(int row, int column) {
    final (r0, r1, c0, c1) = _selectedRange;
    return r0 >= 0 && row >= r0 && row <= r1 && column >= c0 && column <= c1;
  }

  int _rowIndexOffset;

  /// What to add to a local row index to get the index into the whole dataset.
  /// Non-zero when the grid is paginated; used only for semantics labels, which
  /// should say "row 603" rather than "row 3 of the page you happen to be on".
  int get rowIndexOffset => _rowIndexOffset;
  set rowIndexOffset(int value) {
    if (_rowIndexOffset == value) return;
    _rowIndexOffset = value;
    markNeedsSemanticsUpdate();
  }

  FitGridCellSpanResolver? _cellSpan;

  /// How many columns each cell covers. Null means every cell covers one.
  set cellSpan(FitGridCellSpanResolver? value) {
    if (_cellSpan == value) return;
    final had = _cellSpan != null;
    _cellSpan = value;
    markNeedsPaint();
    if (had != (value != null)) markNeedsSemanticsUpdate();
  }

  int _spanAt(int row, int column) {
    final span = _cellSpan?.call(row, column) ?? 1;
    if (span <= 1) return 1;
    return math.min(span, _columnLayout.length - column);
  }

  FitGridRowIndentResolver? _rowIndent;

  /// Extra leading inset for a row's first cell.
  set rowIndent(FitGridRowIndentResolver? value) {
    if (_rowIndent == value) return;
    _rowIndent = value;
    markNeedsPaint();
  }

  FitGridRowFlagResolver? _isFullRow;

  /// Rows given over entirely to a full-width child — detail panels. Their
  /// cells are not painted and not announced: the child is the content, and
  /// it carries its own semantics.
  set isFullRow(FitGridRowFlagResolver? value) {
    if (_isFullRow == value) return;
    _isFullRow = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  bool _fullRow(int row) => _isFullRow?.call(row) ?? false;

  FitGridStickyChainResolver? _stickyChain;
  FitGridGroupEndResolver? _groupEnd;

  /// Group headers pinned to the top while their rows scroll beneath them.
  /// Null pins nothing.
  set stickyChain(FitGridStickyChainResolver? value) {
    if (_stickyChain == value) return;
    _stickyChain = value;
    markNeedsPaint();
  }

  set groupEnd(FitGridGroupEndResolver? value) {
    if (_groupEnd == value) return;
    _groupEnd = value;
    markNeedsPaint();
  }

  /// Where each pinned header was last painted: (row, top, height), top in
  /// this box's coordinates. Kept for hit testing, which has to find a tap on
  /// a pinned header rather than on the row scrolled beneath it.
  final List<(int, double, double)> _stickySlots = <(int, double, double)>[];

  /// Computes where the pinned headers go: stacked from the top, each pushed
  /// up by the end of its own group so the next header slides it away rather
  /// than overlapping it.
  void _layoutSticky() {
    _stickySlots.clear();
    final chain = _stickyChain;
    final end = _groupEnd;
    if (chain == null || end == null || rowCount == 0) return;
    final first = _rowMetrics.clampedRowAt(_verticalOffset);
    var y = 0.0;
    for (final row in chain(first)) {
      if (row < 0 || row >= rowCount) continue;
      final height = _rowMetrics.heightOf(row);
      final natural = _rowMetrics.offsetOf(row) - _verticalOffset;
      // A header still in its own place needs no pinning — and every header
      // below it in the chain is in its place too.
      if (natural >= y) break;
      final groupEnd = end(row).clamp(0, rowCount);
      final limit = _rowMetrics.offsetOf(groupEnd) - _verticalOffset - height;
      final top = math.min(y, limit);
      _stickySlots.add((row, top, height));
      y = top + height;
    }
  }

  /// The pinned header row under a local vertical offset, or -1.
  int stickyRowAtOffset(double dy) {
    for (final (row, top, height) in _stickySlots.reversed) {
      if (dy >= top && dy < top + height) return row;
    }
    return -1;
  }

  void _paintSticky(Canvas canvas, Offset offset) {
    if (_stickySlots.isEmpty) return;
    final padding = _theme.effectiveCellPadding;
    final background = Paint();
    final rule = Paint()
      ..color = _theme.border
      ..strokeWidth = _theme.dividerThickness;
    for (final (row, top, height) in _stickySlots) {
      final y = offset.dy + top;
      background.color = _rowColor?.call(row) ?? _theme.rowBackground;
      // Opaque, whatever the header colour: the rows are scrolling under it.
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, y, size.width, height),
        Paint()..color = _theme.rowBackground,
      );
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, y, size.width, height),
        background,
      );
      final span = _spanAt(row, 0);
      _paintCell(canvas, offset, row, 0, span, padding, topOverride: y);
      canvas.drawLine(
        Offset(offset.dx, y + height),
        Offset(offset.dx + size.width, y + height),
        rule,
      );
    }
  }

  void Function(int row, int column)? _onCellActivate;
  set onCellActivate(void Function(int row, int column)? value) {
    if (_onCellActivate == value) return;
    final had = _onCellActivate != null;
    _onCellActivate = value;
    if (had != (value != null)) markNeedsSemanticsUpdate();
  }

  // ------------------------------------------------------------ paint caches

  /// Laid-out cells, keyed by *what they contain* rather than by where they
  /// are.
  ///
  /// Keying by position means a column of 400 rows all reading "Active" lays
  /// that word out 400 times, and means a one-row scroll throws away every
  /// painter it passes. Keying by content collapses repeats to a single
  /// painter and survives scrolling, which is where a grid spends its frames.
  ///
  /// The key is the spec's hash together with the box it was laid out into. A
  /// collision would be a cell painting another cell's text, so the entry is
  /// verified on every hit and rebuilt if it does not match.
  final Map<int, _CachedCell> _cells = <int, _CachedCell>{};

  /// Where each painted cell ended up, so the truncation and height queries can
  /// still be asked positionally. Rebuilt as the text pass runs.
  final Map<int, _CachedCell> _byCell = <int, _CachedCell>{};

  Float32List? _rulePoints;

  /// Bumped on every paint, so an entry can record when it was last wanted.
  int _paintEpoch = 0;

  static const int _columnStride = 1 << 20;

  int _cellKey(int row, int column) => row * _columnStride + column;

  void _clearCache() {
    for (final cell in _cells.values) {
      cell.dispose();
    }
    _cells.clear();
    _byCell.clear();
  }

  /// Drops painters nothing has asked for recently.
  ///
  /// The bound is the window — rows on screen times columns on screen, with
  /// room for a scroll's worth of churn — so the cache tracks the viewport and
  /// never the dataset, whatever the content happens to be.
  void _pruneCache() {
    final budget = math.max(
      64,
      (_visibleRowCount + 2 * _overscanRows) *
          math.max(1, _columnLayout.length) *
          2,
    );
    if (_cells.length <= budget) return;
    final epoch = _paintEpoch;
    _cells.removeWhere((_, cell) {
      if (cell.epoch >= epoch - 1) return false;
      cell.dispose();
      return true;
    });
  }

  // ---------------------------------------------------------------- layout

  int get _lastVisibleRow =>
      math.min(_firstVisibleRow + _visibleRowCount, rowCount);

  /// Total height of all rows, whether or not they are in the window.
  double get contentHeight => _rowMetrics.totalHeight;

  /// Total width of all columns.
  double get contentWidth => _columnLayout.totalWidth;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! FitGridCellParentData) {
      child.parentData = FitGridCellParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) => contentWidth;

  @override
  double computeMinIntrinsicHeight(double width) => 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => contentHeight;

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _vertical.addListener(markNeedsLayout);
    _horizontal.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _vertical.removeListener(markNeedsLayout);
    _horizontal.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    // Content extents come from the row count and the resolved column widths,
    // so the scroll positions can be settled before any child does work.
    //
    // The horizontal extent is the *scrolling* band's, not the whole content's:
    // pinned columns occupy screen width that the scroll never recovers, so
    // measuring the scrollable range against the full viewport would let the
    // user scroll past the last unpinned column by exactly the pinned width.
    final maxVertical = math.max(0.0, contentHeight - size.height);
    final maxHorizontal = maxHorizontalOffset;

    _vertical
      ..applyViewportDimension(size.height)
      ..applyContentDimensions(0.0, maxVertical);
    _horizontal
      ..applyViewportDimension(_scrollableExtent)
      ..applyContentDimensions(0.0, maxHorizontal);

    _verticalOffset = _vertical.hasPixels
        ? _vertical.pixels.clamp(0.0, maxVertical)
        : 0.0;
    _horizontalOffset = _horizontal.hasPixels
        ? _horizontal.pixels.clamp(0.0, maxHorizontal)
        : 0.0;

    // Windowing goes through the metrics rather than dividing by a height, so
    // the uniform case stays arithmetic and the measured case becomes a binary
    // search without anything here changing.
    final anchor = _rowMetrics.clampedRowAt(_verticalOffset);
    final first = math.max(0, anchor - _overscanRows);
    final span =
        _rowMetrics.rowsSpanning(anchor, size.height) + _overscanRows * 2;
    if (first != _firstVisibleRow || span != _visibleRowCount) {
      _firstVisibleRow = first;
      _visibleRowCount = span;
      _byCell.clear();
      markNeedsSemanticsUpdate();
    }

    final window = (_firstVisibleRow, _lastVisibleRow);
    final build = cellBuilder;
    if (build != null && (_cellsNeedBuild || window != _builtWindow)) {
      _cellsNeedBuild = false;
      _builtWindow = window;
      invokeLayoutCallback<BoxConstraints>((_) => build(window.$1, window.$2));
    }

    // Overlay children are scoped to the window — widget cells by the builder
    // above, the editor by the widget layer — so all that remains is to give
    // each one its cell box.
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FitGridCellParentData;
      final columnIndex = data.columnIndex;
      final rowIndex = data.rowIndex;

      if (columnIndex == FitGridCellParentData.fullRow) {
        final inRange = rowIndex >= 0 && rowIndex < rowCount;
        child.layout(
          BoxConstraints.tightFor(
            width: size.width,
            height: inRange ? _rowMetrics.heightOf(rowIndex) : 0.0,
          ),
          parentUsesSize: false,
        );
        data.offset = Offset(
          0,
          (inRange ? _rowMetrics.offsetOf(rowIndex) : 0.0) - _verticalOffset,
        );
      } else if (columnIndex < 0 || columnIndex >= _columnLayout.length) {
        // Stale tag — lay out degenerately rather than throwing. A child that
        // cannot be placed must still be laid out, or the semantics and paint
        // phases will trip over an unlaid-out render object.
        child.layout(BoxConstraints.tight(Size.zero), parentUsesSize: false);
        data.offset = Offset.zero;
      } else {
        final width = _columnLayout.widths[columnIndex];
        final inRange = rowIndex >= 0 && rowIndex < rowCount;
        child.layout(
          BoxConstraints.tightFor(
            width: width,
            height: inRange ? _rowMetrics.heightOf(rowIndex) : 0.0,
          ),
          parentUsesSize: false,
        );
        data.offset = Offset(
          _screenLeft(columnIndex),
          (inRange ? _rowMetrics.offsetOf(rowIndex) : 0.0) - _verticalOffset,
        );
      }
      child = data.nextSibling;
    }
    _layoutSticky();
  }

  // --------------------------------------------------------- band geometry

  /// Distance from the *leading* edge of the viewport to a column's leading
  /// edge, with pinning and scrolling already applied.
  ///
  /// Everything horizontal goes through here. Doing the three cases once, in
  /// leading-edge space, is what keeps painting, hit testing, semantics and
  /// overlay placement from each growing their own subtly different version of
  /// the same arithmetic — and what makes RTL a single mirror at the end
  /// rather than a special case in every one of them.
  double _logicalStart(int columnIndex) {
    final layout = _columnLayout;
    if (columnIndex < layout.leadingFrozenCount) {
      return layout.offsets[columnIndex];
    }
    if (columnIndex >= layout.trailingFrozenStart) {
      return size.width - (layout.totalWidth - layout.offsets[columnIndex]);
    }
    return layout.offsets[columnIndex] - _horizontalOffset;
  }

  /// Left edge of a column in this box's own coordinates.
  double _screenLeft(int columnIndex) {
    final start = _logicalStart(columnIndex);
    return _textDirection == TextDirection.ltr
        ? start
        : size.width - start - _columnLayout.widths[columnIndex];
  }

  /// A band, given its span in leading-edge space.
  Rect _bandRect(double start, double end, Offset offset) {
    if (_textDirection == TextDirection.ltr) {
      return Rect.fromLTRB(
        offset.dx + start,
        offset.dy,
        offset.dx + end,
        offset.dy + size.height,
      );
    }
    return Rect.fromLTRB(
      offset.dx + size.width - end,
      offset.dy,
      offset.dx + size.width - start,
      offset.dy + size.height,
    );
  }

  /// Which scrolling columns intersect their band.
  (int, int) get _visibleScrollableRange {
    final layout = _columnLayout;
    if (layout.trailingFrozenStart <= layout.leadingFrozenCount) return (0, 0);
    final from = layout.leadingFrozenCount;
    final to = layout.trailingFrozenStart;
    final start = layout
        .columnAtOffset(layout.offsets[from] + _horizontalOffset)
        .clamp(from, to - 1);
    final end = layout
        .columnAtOffset(
          layout.offsets[from] + _horizontalOffset + _scrollableExtent,
        )
        .clamp(from, to - 1);
    return (start, math.min(end + 1, to));
  }

  // ----------------------------------------------------------------- paint

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_columnLayout.isEmpty || rowCount == 0) return;
    final layout = _columnLayout;
    final canvas = context.canvas;
    _paintEpoch++;

    canvas
      ..save()
      ..clipRect(offset & size);

    // The scrolling band is painted first and clipped to its own strip, so the
    // pinned bands laid over it never have to erase anything: the scrolling
    // text simply never reaches underneath them.
    final (firstScroll, lastScroll) = _visibleScrollableRange;
    _paintBand(
      canvas,
      offset,
      firstScroll,
      lastScroll,
      _bandRect(
        layout.leadingFrozenWidth,
        size.width - layout.trailingFrozenWidth,
        offset,
      ),
    );

    if (layout.leadingFrozenCount > 0) {
      _paintBand(
        canvas,
        offset,
        0,
        layout.leadingFrozenCount,
        _bandRect(0, layout.leadingFrozenWidth, offset),
      );
      _paintFrozenEdge(
        canvas,
        offset,
        layout.leadingFrozenWidth,
        leading: true,
        active: _horizontalOffset > 0.5,
      );
    }
    if (layout.trailingFrozenStart < layout.length) {
      _paintBand(
        canvas,
        offset,
        layout.trailingFrozenStart,
        layout.length,
        _bandRect(size.width - layout.trailingFrozenWidth, size.width, offset),
      );
      _paintFrozenEdge(
        canvas,
        offset,
        size.width - layout.trailingFrozenWidth,
        leading: false,
        active: _horizontalOffset < maxHorizontalOffset - 0.5,
      );
    }

    _paintSpans(canvas, offset);
    _paintSticky(canvas, offset);
    _paintDropLine(canvas, offset);
    _paintFill(canvas, offset);
    canvas.restore();
    _pruneCache();
    _paintChildren(context, offset);
  }

  void _paintFill(Canvas canvas, Offset offset) {
    final (r0, r1, c0, c1) = _fillPreview;
    if (r0 >= 0 && c0 >= 0 && r1 < rowCount && c1 < _columnLayout.length) {
      final a = _screenLeft(c0);
      final b = _screenLeft(c1);
      final rect = Rect.fromLTRB(
        offset.dx + math.min(a, b),
        offset.dy + _rowMetrics.offsetOf(r0) - _verticalOffset,
        offset.dx +
            math.max(
              a + _columnLayout.widths[c0],
              b + _columnLayout.widths[c1],
            ),
        offset.dy + _rowMetrics.offsetOf(r1 + 1) - _verticalOffset,
      );
      canvas.drawRect(
        rect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _theme.focusOutline.withValues(alpha: 0.8),
      );
    }
    final handle = fillHandleRect;
    if (handle == null) return;
    final box = handle.shift(offset);
    // A ring in the row colour around it, so it reads against the outline
    // it sits on and against a selected row alike.
    canvas
      ..drawRect(box.inflate(1), Paint()..color = _theme.rowBackground)
      ..drawRect(box, Paint()..color = _theme.focusOutline);
  }

  void _paintDropLine(Canvas canvas, Offset offset) {
    if (_dropLine < 0 || _dropLine > rowCount) return;
    final y = offset.dy + _rowMetrics.offsetOf(_dropLine) - _verticalOffset;
    final stroke = _theme.focusRingWidth;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, y - stroke / 2, size.width, stroke),
      Paint()..color = _theme.focusOutline,
    );
  }

  /// Which band a column is painted in: 0 leading pinned, 1 scrolling, 2
  /// trailing pinned. Null for a stale column index.
  int? _bandOf(int columnIndex) {
    final layout = _columnLayout;
    if (columnIndex == FitGridCellParentData.fullRow) return 3;
    if (columnIndex < 0 || columnIndex >= layout.length) return null;
    if (columnIndex < layout.leadingFrozenCount) return 0;
    if (columnIndex >= layout.trailingFrozenStart) return 2;
    return 1;
  }

  /// A band's strip in this box's own coordinates.
  Rect _bandLocalRect(int band) {
    final layout = _columnLayout;
    return switch (band) {
      3 => Offset.zero & size,
      0 => _bandRect(0, layout.leadingFrozenWidth, Offset.zero),
      2 => _bandRect(
        size.width - layout.trailingFrozenWidth,
        size.width,
        Offset.zero,
      ),
      _ => _bandRect(
        layout.leadingFrozenWidth,
        size.width - layout.trailingFrozenWidth,
        Offset.zero,
      ),
    };
  }

  final List<LayerHandle<ClipRectLayer>> _bandClips =
      List<LayerHandle<ClipRectLayer>>.generate(
        4,
        (_) => LayerHandle<ClipRectLayer>(),
      );

  /// Paints the overlay children, each clipped to the band its column lives
  /// in — the same rule the painted text follows — so a widget scrolled under
  /// a pinned column disappears beneath it instead of drawing over it, and a
  /// row scrolled half off the top is cut at the edge.
  ///
  /// At most four clips per frame, one per band and one for the full-width
  /// children, however many children there are.
  void _paintChildren(PaintingContext context, Offset offset) {
    for (var band = 0; band < 4; band++) {
      var any = false;
      var child = firstChild;
      while (child != null && !any) {
        final data = child.parentData! as FitGridCellParentData;
        any = _bandOf(data.columnIndex) == band;
        child = data.nextSibling;
      }
      if (!any) {
        _bandClips[band].layer = null;
        continue;
      }
      _bandClips[band].layer = context.pushClipRect(
        needsCompositing,
        offset,
        _bandLocalRect(band),
        (context, offset) {
          var child = firstChild;
          while (child != null) {
            final data = child.parentData! as FitGridCellParentData;
            if (_bandOf(data.columnIndex) == band) {
              context.paintChild(child, offset + data.offset);
            }
            child = data.nextSibling;
          }
        },
        oldLayer: _bandClips[band].layer,
      );
    }
  }

  /// Backgrounds, rules and text for one contiguous range of columns, confined
  /// to [band].
  void _paintBand(
    Canvas canvas,
    Offset offset,
    int firstColumn,
    int lastColumn,
    Rect band,
  ) {
    if (band.width <= 0) return;
    canvas
      ..save()
      ..clipRect(band);
    _paintRowBackgrounds(canvas, offset, band);
    _paintRange(canvas, offset, firstColumn, lastColumn, fill: true);
    _paintRules(canvas, offset, band, firstColumn, lastColumn);
    _paintText(canvas, offset, firstColumn, lastColumn);
    _paintRange(canvas, offset, firstColumn, lastColumn, fill: false);
    _paintFocusRing(canvas, offset, firstColumn, lastColumn);
    canvas.restore();
  }

  /// The part of the selected range inside one band: a wash under the text on
  /// the first call, and an outline over it on the second.
  ///
  /// One rectangle per band rather than one per cell, because a range is
  /// contiguous within a band whatever its size.
  void _paintRange(
    Canvas canvas,
    Offset offset,
    int firstColumn,
    int lastColumn, {
    required bool fill,
  }) {
    final (r0, r1, c0, c1) = _selectedRange;
    if (r0 < 0) return;
    final from = math.max(c0, firstColumn);
    final to = math.min(c1, lastColumn - 1);
    if (from > to) return;
    final top = math.max(r0, _firstVisibleRow);
    final bottom = math.min(r1, _lastVisibleRow - 1);
    if (top > bottom) return;

    final leftA = _screenLeft(from);
    final leftB = _screenLeft(to);
    final left = math.min(leftA, leftB);
    final right = math.max(
      leftA + _columnLayout.widths[from],
      leftB + _columnLayout.widths[to],
    );
    final rect = Rect.fromLTRB(
      offset.dx + left,
      offset.dy + _rowMetrics.offsetOf(top) - _verticalOffset,
      offset.dx + right,
      offset.dy + _rowMetrics.offsetOf(bottom + 1) - _verticalOffset,
    );
    if (fill) {
      canvas.drawRect(
        rect,
        Paint()..color = _theme.effectiveRangeSelectionBackground,
      );
      return;
    }
    final stroke = _theme.focusRingWidth / 2;
    canvas.drawRect(
      rect.deflate(stroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _theme.focusOutline,
    );
  }

  void _paintRowBackgrounds(Canvas canvas, Offset offset, Rect band) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      var color =
          _rowColor?.call(row) ??
          (_striped && row.isOdd
              ? _theme.alternateRowBackground
              : _theme.rowBackground);
      if (row == _hoveredRow) {
        color = Color.alphaBlend(_theme.hoverBackground, color);
      }
      if (color.a == 0) continue;
      final top = offset.dy + _rowMetrics.offsetOf(row) - _verticalOffset;
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(band.left, top, band.width, _rowMetrics.heightOf(row)),
        paint,
      );
    }
  }

  /// Every rule in a band as one call.
  ///
  /// `drawRawPoints` with [PointMode.lines] consumes pairs of points, so the
  /// buffer holds x,y,x,y per segment. Reusing the `Float32List` across paints
  /// matters more than it looks: this runs on every frame of a scroll.
  void _paintRules(
    Canvas canvas,
    Offset offset,
    Rect band,
    int firstColumn,
    int lastColumn,
  ) {
    final dash = _theme.rowDividerDash;
    final dashed =
        dash != null &&
        dash.length >= 2 &&
        dash.fold<double>(0, (a, b) => a + b) > 0;
    final tickExtent = _theme.columnDividerExtent;
    final rowCountInWindow = _lastVisibleRow - _firstVisibleRow;

    // Row rules, solid or dashed.
    var rowSegments = rowCountInWindow;
    if (dashed) {
      final period = dash.fold<double>(0, (a, b) => a + b);
      // An upper bound: every period touching the band, one more for the dash
      // cut by its leading edge, at most half the pattern's entries dashes.
      rowSegments *=
          ((band.width / period).ceil() + 1) * ((dash.length + 1) ~/ 2);
    }
    // Column rules: one full-height line per column, or a tick per row.
    var columnSegments = 0;
    for (var column = firstColumn; column < lastColumn; column++) {
      if (column == _columnLayout.length - 1) continue;
      columnSegments += tickExtent == null ? 1 : rowCountInWindow;
    }
    // Ticks take the column colour and so need a draw of their own; full-height
    // column rules share the row rules' call, as they always have.
    final sharedCall = tickExtent == null;
    final segments = rowSegments + (sharedCall ? columnSegments : 0);
    if (segments == 0 && columnSegments == 0) return;

    final needed = math.max(segments, columnSegments) * 4;
    var buffer = _rulePoints;
    if (buffer == null || buffer.length < needed) {
      buffer = _rulePoints = Float32List(needed);
    }

    void draw(int count, Color color) {
      if (count == 0) return;
      canvas.drawRawPoints(
        PointMode.lines,
        count == buffer!.length
            ? buffer
            : Float32List.sublistView(buffer, 0, count),
        Paint()
          ..color = color
          ..strokeWidth = _theme.dividerThickness,
      );
    }

    var i = 0;
    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      final y = offset.dy + _rowMetrics.offsetOf(row + 1) - _verticalOffset;
      if (!dashed) {
        buffer[i++] = band.left;
        buffer[i++] = y;
        buffer[i++] = band.right;
        buffer[i++] = y;
        continue;
      }
      // Dashes are laid from the section's own left edge, not the band's, so a
      // pinned band and the scrolling band beside it keep one rhythm.
      var x = offset.dx;
      var k = 0;
      while (x < band.right) {
        final length = dash[k % dash.length];
        if (k.isEven) {
          final from = math.max(x, band.left);
          final to = math.min(x + length, band.right);
          if (to > from) {
            buffer[i++] = from;
            buffer[i++] = y;
            buffer[i++] = to;
            buffer[i++] = y;
          }
        }
        x += length;
        k++;
      }
    }

    // The trailing rule of the last column in a band is drawn too, unless it is
    // the very last column of the grid: it is the seam between the band and
    // whatever sits beside it, and without it a pinned band floats.
    void columnRules() {
      for (var column = firstColumn; column < lastColumn; column++) {
        if (column == _columnLayout.length - 1) continue;
        final width = _columnLayout.widths[column];
        final left = offset.dx + _screenLeft(column);
        final x = _textDirection == TextDirection.ltr ? left + width : left;
        if (tickExtent == null) {
          buffer![i++] = x;
          buffer[i++] = band.top;
          buffer[i++] = x;
          buffer[i++] = band.bottom;
          continue;
        }
        for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
          if (_fullRow(row)) continue;
          final top = offset.dy + _rowMetrics.offsetOf(row) - _verticalOffset;
          final height = _rowMetrics.heightOf(row);
          final extent = math.min(tickExtent, height);
          final y0 = top + (height - extent) / 2;
          buffer![i++] = x;
          buffer[i++] = y0;
          buffer[i++] = x;
          buffer[i++] = y0 + extent;
        }
      }
    }

    if (sharedCall) {
      columnRules();
      draw(i, _theme.rowDivider);
      return;
    }
    draw(i, _theme.rowDivider);
    i = 0;
    columnRules();
    draw(i, _theme.columnDivider);
  }

  /// The seam where a pinned band meets the scrolling one.
  ///
  /// Solid while the band is flush against the content, and given a short
  /// gradient once the content has scrolled under it — the shadow is what says
  /// "there is more over here", and showing it when there is not would be a
  /// lie the user has to check.
  void _paintFrozenEdge(
    Canvas canvas,
    Offset offset,
    double logicalEdge, {
    required bool leading,
    required bool active,
  }) {
    final rtl = _textDirection == TextDirection.rtl;
    final x = offset.dx + (rtl ? size.width - logicalEdge : logicalEdge);
    canvas.drawLine(
      Offset(x, offset.dy),
      Offset(x, offset.dy + size.height),
      Paint()
        ..color = _theme.border
        ..strokeWidth = _theme.dividerThickness,
    );
    if (!active) return;

    // The shadow falls away from the pinned band, which under RTL is the other
    // way along the x axis.
    final outward = (leading != rtl) ? 1.0 : -1.0;
    final shadow = Rect.fromLTRB(
      math.min(x, x + outward * _theme.frozenShadowExtent),
      offset.dy,
      math.max(x, x + outward * _theme.frozenShadowExtent),
      offset.dy + size.height,
    );
    canvas.drawRect(
      shadow,
      Paint()
        ..shader = ui.Gradient.linear(
          outward > 0 ? shadow.centerLeft : shadow.centerRight,
          outward > 0 ? shadow.centerRight : shadow.centerLeft,
          <Color>[
            _theme.frozenShadow,
            _theme.frozenShadow.withValues(alpha: 0),
          ],
        ),
    );
  }

  void _paintText(
    Canvas canvas,
    Offset offset,
    int firstColumn,
    int lastColumn,
  ) {
    final padding = _theme.effectiveCellPadding;

    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      if (_fullRow(row)) continue;
      for (var column = firstColumn; column < lastColumn; column++) {
        final span = _spanAt(row, column);
        // A merged cell can reach past the band it starts in — a group header
        // beginning inside a pinned column is the ordinary case — so it is left
        // to `_paintSpans`, which runs outside every band clip. Here it only
        // costs the columns it covers.
        if (span > 1) {
          column += span - 1;
          continue;
        }
        _paintCell(canvas, offset, row, column, 1, padding);
      }
    }
  }

  /// The merged cells, painted after the bands and clipped only by the section.
  ///
  /// A span is the one thing that does not belong to a band: pinning a column
  /// should not cut a group header off at 44 pixels.
  void _paintSpans(Canvas canvas, Offset offset) {
    if (_cellSpan == null) return;
    final padding = _theme.effectiveCellPadding;

    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      if (_fullRow(row)) continue;
      for (var column = 0; column < _columnLayout.length; column++) {
        final span = _spanAt(row, column);
        if (span <= 1) continue;
        _paintCell(canvas, offset, row, column, span, padding);
        column += span - 1;
      }
    }
  }

  /// One cell, covering [span] columns from [column].
  void _paintCell(
    Canvas canvas,
    Offset offset,
    int row,
    int column,
    int span,
    EdgeInsets padding, {
    double? topOverride,
  }) {
    if (_paintColumns[column].isWidgetColumn) return;
    if (row == _editingRow && column == _editingColumn) return;

    final top =
        topOverride ?? offset.dy + _rowMetrics.offsetOf(row) - _verticalOffset;
    final height = _rowMetrics.heightOf(row);

    final width = span == 1
        ? _columnLayout.widths[column]
        : _columnLayout.offsets[column + span] - _columnLayout.offsets[column];
    final indent = column == 0 ? (_rowIndent?.call(row) ?? 0.0) : 0.0;
    final available = width - padding.horizontal - indent;
    if (available <= 0) return;
    final availableHeight = height - padding.vertical;
    if (availableHeight <= 0) return;

    final spec = _cellSpec(row, column);
    if (spec.placeholder) {
      return _paintPlaceholder(
        canvas,
        offset,
        row,
        column,
        top,
        height,
        available,
        padding,
      );
    }

    final cell = _cellFor(spec, available, availableHeight);
    final leadingEdge = offset.dx + _screenLeft(column);
    // Under RTL a span grows leftwards from its own column, so its box starts
    // where the last covered column does.
    final rtl = _textDirection == TextDirection.rtl;
    final left = rtl
        ? leadingEdge + _columnLayout.widths[column] - width
        : leadingEdge;

    final contentWidth = cell.painter.width + cell.iconAdvance;
    final free = available - contentWidth;
    // The indent belongs on the leading edge. Under RTL that is the right, and
    // the reduced `available` above has already put it there — adding it here
    // as well would count it twice.
    final leading = padding.left + (rtl ? 0.0 : indent);
    final inset = switch (_resolvedAlignment(cell.spec.alignment)) {
      FitGridAlignment.start => leading,
      FitGridAlignment.center => leading + math.max(0, free) / 2,
      FitGridAlignment.end => leading + math.max(0, free),
    };
    final contentLeft = left + inset;
    final textLeft = rtl ? contentLeft : contentLeft + cell.iconAdvance;
    final origin = Offset(textLeft, top + (height - cell.painter.height) / 2);
    final cellRect = Rect.fromLTWH(left, top, width, height);

    final visual = spec.visual;
    if (visual != null) {
      _paintVisual(
        canvas,
        visual,
        Rect.fromLTRB(
          cellRect.left + padding.left,
          cellRect.top + padding.top,
          cellRect.right - padding.right,
          cellRect.bottom - padding.bottom,
        ),
        hasText: spec.text.isNotEmpty,
      );
    }

    // A cell that still does not fit — one line taller than the whole row, say
    // — is clipped to its own box rather than allowed to paint over its
    // neighbours. The save/restore is skipped in the overwhelmingly common case
    // where the text already fits, because this runs per cell per frame of a
    // scroll.
    final needsClip = cell.overflows;
    if (needsClip) {
      canvas
        ..save()
        ..clipRect(cellRect);
    }

    if (cell.icon != null) {
      final iconLeft = rtl
          ? contentLeft + contentWidth - cell.iconAdvance
          : contentLeft;
      cell.icon!.paint(
        canvas,
        Offset(iconLeft, top + (height - cell.icon!.height) / 2),
      );
    }

    if (cell.hasHighlights) _paintHighlights(canvas, cell, origin);

    if (cell.faded) {
      canvas
        ..save()
        ..translate(origin.dx, origin.dy);
      cell.painter.paint(canvas, Offset.zero);
      canvas.restore();
    } else {
      cell.painter.paint(canvas, origin);
    }
    if (needsClip) canvas.restore();
    _byCell[_cellKey(row, column)] = cell;
  }

  /// A chart in a cell's content box.
  ///
  /// Bars and tracks grow from the leading edge, so under RTL they grow from
  /// the right. A sparkline does not mirror: its axis is time, and time runs
  /// left to right on a chart whatever the script around it.
  void _paintVisual(
    Canvas canvas,
    FitGridCellVisualSpec visual,
    Rect box, {
    required bool hasText,
  }) {
    if (box.width <= 0 || box.height <= 0) return;
    final rtl = _textDirection == TextDirection.rtl;
    final base =
        visual.color ??
        (visual.negative
            ? _theme.effectiveChartNegativeColor
            : _theme.effectiveChartColor);

    Rect span(double from, double to, double top, double height) {
      final a = box.left + box.width * (rtl ? 1 - to : from);
      final b = box.left + box.width * (rtl ? 1 - from : to);
      return Rect.fromLTRB(a, top, b, top + height);
    }

    switch (visual.kind) {
      case FitGridVisualKind.bar:
        // Translucent, so the value painted over it stays readable.
        final rect = span(visual.from, visual.to, box.top, box.height);
        if (rect.width <= 0) return;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = base.withValues(alpha: base.a * 0.35),
        );
      case FitGridVisualKind.progress:
        // With text, a slim track along the bottom leaves the text its line;
        // alone, a thicker one sits in the middle.
        final thickness = math.min(box.height, hasText ? 4.0 : 8.0);
        final top = hasText
            ? box.bottom - thickness
            : box.top + (box.height - thickness) / 2;
        final radius = Radius.circular(thickness / 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(span(0, 1, top, thickness), radius),
          Paint()..color = base.withValues(alpha: base.a * 0.18),
        );
        if (visual.to > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(span(0, visual.to, top, thickness), radius),
            Paint()..color = base,
          );
        }
      case FitGridVisualKind.sparkline:
        final points = visual.points;
        if (points.length < 2) return;
        final step = box.width / (points.length - 1);
        final path = Path();
        for (var i = 0; i < points.length; i++) {
          final x = box.left + step * i;
          final y = box.bottom - points[i] * box.height;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        if (visual.filled) {
          final area = Path.from(path)
            ..lineTo(box.right, box.bottom)
            ..lineTo(box.left, box.bottom)
            ..close();
          canvas.drawPath(
            area,
            Paint()..color = base.withValues(alpha: base.a * 0.15),
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
        // The last point is the one people read, so it gets a dot.
        canvas.drawCircle(
          Offset(box.right, box.bottom - points.last * box.height),
          2.5,
          Paint()..color = base,
        );
    }
  }

  /// A skeleton bar where content is on its way.
  ///
  /// Its length varies with the row and column, deterministically, so a block
  /// of loading rows looks like text of uneven length rather than a ruled
  /// grid — and does not flicker from one frame to the next.
  void _paintPlaceholder(
    Canvas canvas,
    Offset offset,
    int row,
    int column,
    double top,
    double height,
    double available,
    EdgeInsets padding,
  ) {
    final fraction = 0.45 + ((row * 7 + column * 13) % 5) * 0.1;
    final width = available * fraction;
    final barHeight = math.min(
      height - padding.vertical,
      (_theme.cellTextStyle.fontSize ?? 14) * 0.8,
    );
    if (width <= 0 || barHeight <= 0) return;
    final leadingEdge = offset.dx + _screenLeft(column) + padding.left;
    final left = _textDirection == TextDirection.ltr
        ? leadingEdge
        : offset.dx +
              _screenLeft(column) +
              _columnLayout.widths[column] -
              padding.right -
              width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top + (height - barHeight) / 2, width, barHeight),
        Radius.circular(barHeight / 2),
      ),
      Paint()
        ..color = _theme.placeholderForeground.withValues(
          alpha: _theme.placeholderForeground.a * 0.25,
        ),
    );
  }

  /// A wash behind the characters a search matched.
  ///
  /// The boxes come from the painter that has already been laid out, so a
  /// match highlight costs a rectangle per match and no second text layout —
  /// the thing that makes highlighting expensive in a widget table, where the
  /// text has to be rebuilt as a span tree to carry it.
  void _paintHighlights(Canvas canvas, _CachedCell cell, Offset origin) {
    final paint = Paint()..color = _theme.searchHighlight;
    final highlights = cell.spec.highlights;
    for (var i = 0; i + 1 < highlights.length; i += 2) {
      final boxes = cell.painter.getBoxesForSelection(
        TextSelection(
          baseOffset: highlights[i],
          extentOffset: highlights[i + 1],
        ),
      );
      for (final box in boxes) {
        canvas.drawRect(box.toRect().shift(origin), paint);
      }
    }
  }

  /// The keyboard's current cell, outlined.
  void _paintFocusRing(
    Canvas canvas,
    Offset offset,
    int firstColumn,
    int lastColumn,
  ) {
    final row = _focusedRow;
    final column = _focusedColumn;
    if (row < _firstVisibleRow || row >= _lastVisibleRow) return;
    if (column < firstColumn || column >= lastColumn) return;

    final width = _columnLayout.widths[column];
    final rect = Rect.fromLTWH(
      offset.dx + _screenLeft(column),
      offset.dy + _rowMetrics.offsetOf(row) - _verticalOffset,
      width,
      _rowMetrics.heightOf(row),
    );
    final stroke = _theme.focusRingWidth;
    canvas.drawRect(
      rect.deflate(stroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _theme.focusOutline,
    );
  }

  /// Resolves an alignment against the text direction, so `start` means
  /// "leading edge" rather than "left".
  ///
  /// Taken from the cell's spec rather than its column, because a merged cell
  /// spanning from a centred column is not thereby centred — a group header
  /// beginning in the checkbox column still reads left to right.
  FitGridAlignment _resolvedAlignment(FitGridAlignment alignment) {
    if (_textDirection == TextDirection.ltr) return alignment;
    return switch (alignment) {
      FitGridAlignment.start => FitGridAlignment.end,
      FitGridAlignment.end => FitGridAlignment.start,
      FitGridAlignment.center => FitGridAlignment.center,
    };
  }

  /// The cached painter for a cell, laid out only when something it depends on
  /// has actually changed.
  ///
  /// [maxHeight] is the cell's content box, and a wrapping cell is capped to the
  /// lines that fit inside it. Without that cap a row clamped by
  /// `FitGridRowHeight.contentSized(max: ...)` — or a wrapping column under a
  /// fixed row height — lays its text out at full height and paints it straight
  /// over the rows above and below.
  _CachedCell _cellFor(
    FitGridCellSpec spec,
    double maxWidth,
    double maxHeight,
  ) {
    final key = Object.hash(spec, maxWidth, maxHeight);
    final existing = _cells[key];

    // Verified, not trusted: the key is a hash, and a collision would be one
    // cell painting another cell's text.
    if (existing != null &&
        existing.spec == spec &&
        existing.maxWidth == maxWidth &&
        existing.maxHeight == maxHeight) {
      existing.epoch = _paintEpoch;
      return existing;
    }

    final cell = _layOutCell(spec, maxWidth, maxHeight);
    existing?.dispose();
    _cells[key] = cell;
    return cell;
  }

  _CachedCell _layOutCell(
    FitGridCellSpec spec,
    double maxWidth,
    double maxHeight,
  ) {
    // An icon is a glyph, so it is laid out by a painter of its own rather than
    // reserved as blank space and drawn by hand. It also has to be measured
    // before the text is, because what it takes is what the text does not get.
    TextPainter? icon;
    var iconAdvance = 0.0;
    if (spec.icon != null) {
      final size = spec.iconSize ?? _theme.cellIconSize;
      icon = TextPainter(textDirection: _textDirection)
        ..text = TextSpan(
          text: String.fromCharCode(spec.icon!.codePoint),
          style: TextStyle(
            fontSize: size,
            fontFamily: spec.icon!.fontFamily,
            package: spec.icon!.fontPackage,
            color: spec.iconColor ?? spec.style.color,
            height: 1.0,
          ),
        )
        ..layout();
      iconAdvance = icon.width + _theme.cellIconGap;
    }

    final painter = TextPainter(textDirection: _textDirection)
      ..textScaler = _textScaler
      ..ellipsis = switch (spec.overflow) {
        FitGridOverflow.ellipsis || FitGridOverflow.tooltipOnTruncate => '…',
        FitGridOverflow.fade || FitGridOverflow.clip => null,
      };

    void layOut(TextStyle style) {
      painter.text = TextSpan(text: spec.text, style: style);
      // The line budget is settled before the layout, not after it. Laying the
      // text out unbounded and trimming it afterwards would cost two layouts,
      // and it does not even work: a `TextPainter` carrying an ellipsis with a
      // null `maxLines` ellipsizes on the first line rather than wrapping, so
      // an unbounded cell would silently come back one line tall.
      //
      // `preferredLineHeight` is available before layout, which is what makes
      // this possible.
      final lineHeight = painter.preferredLineHeight;
      final affordable = lineHeight > 0
          ? math.max(1, maxHeight ~/ lineHeight)
          : 1;
      painter
        ..maxLines = spec.maxLines == null
            ? affordable
            : math.min(spec.maxLines!, affordable)
        ..layout(maxWidth: math.max(0.0, maxWidth - iconAdvance));
    }

    layOut(spec.style);

    final textWidth = math.max(0.0, maxWidth - iconAdvance);
    final truncated =
        painter.didExceedMaxLines ||
        painter.maxIntrinsicWidth > textWidth + 0.5;
    var faded = false;

    // The fade is cut into the glyphs themselves, by painting them through an
    // alpha gradient, rather than by erasing them afterwards with `dstOut`.
    // The result looks the same — the real background shows through, whatever
    // it is — but it costs one extra layout once, when the cell is first seen,
    // instead of a `saveLayer` on every cell on every frame of a scroll. An
    // offscreen render target per truncated cell is the most expensive thing a
    // grid can do sixty times a second.
    if (spec.overflow == FitGridOverflow.fade &&
        truncated &&
        spec.style.foreground == null) {
      final color = spec.style.color ?? const Color(0xFF000000);
      final ramp = math.min(_theme.fadeExtent, painter.width);
      if (ramp > 0) {
        final rtl = _textDirection == TextDirection.rtl;
        layOut(
          spec.style.copyWith(
            color: null,
            foreground: Paint()
              ..shader = ui.Gradient.linear(
                Offset(rtl ? ramp : painter.width - ramp, 0),
                Offset(rtl ? 0 : painter.width, 0),
                <Color>[color, color.withValues(alpha: 0)],
              ),
          ),
        );
        faded = true;
      }
    }

    return _CachedCell(
      painter: painter,
      icon: icon,
      iconAdvance: iconAdvance,
      spec: spec,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      truncated: truncated,
      faded: faded,
      // Whole lines are all the budget above can trim. A single line taller
      // than the row it sits in has nowhere left to go, and gets clipped.
      overflows:
          painter.height > maxHeight + 0.5 ||
          painter.width + iconAdvance > maxWidth + 0.5,
    )..epoch = _paintEpoch;
  }

  // ------------------------------------------------------------- semantics

  final Map<int, SemanticsNode> _rowNodes = <int, SemanticsNode>{};
  final Map<int, SemanticsNode> _cellNodes = <int, SemanticsNode>{};
  SemanticsNode? _tableNode;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true;
  }

  /// Builds the accessibility tree the paint pass would otherwise have thrown
  /// away.
  ///
  /// A widget table gets this for free and pays for it in widgets. Here it is
  /// assembled from the same cell specs the painter reads, for the window only,
  /// and the nodes are recycled across updates — so a screen reader sees a
  /// proper table of rows and cells while the cost still tracks the viewport
  /// rather than the dataset.
  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final rows = <SemanticsNode>[];
    final liveRowKeys = <int>{};
    final liveCellKeys = <int>{};

    final (firstScroll, lastScroll) = _visibleScrollableRange;
    final layout = _columnLayout;

    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      if (_fullRow(row)) continue;
      final cells = <SemanticsNode>[];
      final rowTop = _rowMetrics.offsetOf(row) - _verticalOffset;
      final rowHeight = _rowMetrics.heightOf(row);

      void addColumn(int column) {
        final width = layout.widths[column];
        final left = _screenLeft(column);
        // A cell scrolled entirely out of its band is laid out but not
        // announced: it is not on screen, and a screen reader that walks it
        // would read the grid in an order the eye cannot follow.
        if (left + width <= 0 || left >= size.width) return;

        final key = _cellKey(row, column);
        liveCellKeys.add(key);
        final cellNode = _cellNodes.putIfAbsent(key, SemanticsNode.new);
        final spec = _cellSpec(row, column);
        final cellConfig = SemanticsConfiguration()
          ..role = SemanticsRole.cell
          ..isReadOnly = true
          ..label = _semanticLabelFor(column, spec)
          ..textDirection = _textDirection;
        if (_onCellActivate != null) {
          cellConfig.onTap = () => _onCellActivate!(row, column);
        }
        if (row == _focusedRow && column == _focusedColumn) {
          cellConfig.isFocused = true;
        }
        if (_inRange(row, column)) cellConfig.isSelected = true;
        cellNode
          ..rect = Rect.fromLTWH(left, 0, width, rowHeight)
          ..updateWith(config: cellConfig, childrenInInversePaintOrder: null);
        cells.add(cellNode);
      }

      for (var c = 0; c < layout.leadingFrozenCount; c++) {
        addColumn(c);
      }
      for (var c = firstScroll; c < lastScroll; c++) {
        addColumn(c);
      }
      for (var c = layout.trailingFrozenStart; c < layout.length; c++) {
        addColumn(c);
      }
      if (cells.isEmpty) continue;

      liveRowKeys.add(row);
      final rowNode = _rowNodes.putIfAbsent(row, SemanticsNode.new);
      final rowConfig = SemanticsConfiguration()
        ..role = SemanticsRole.row
        ..isSelected = _isRowSelected?.call(row) ?? false
        ..indexInParent = _rowIndexOffset + row
        ..sortKey = OrdinalSortKey((_rowIndexOffset + row).toDouble());
      rowNode
        ..rect = Rect.fromLTWH(0, rowTop, size.width, rowHeight)
        ..updateWith(config: rowConfig, childrenInInversePaintOrder: cells);
      rows.add(rowNode);
    }

    _rowNodes.removeWhere((key, _) => !liveRowKeys.contains(key));
    _cellNodes.removeWhere((key, _) => !liveCellKeys.contains(key));

    // The rows hang off a node of their own rather than off this one. A node
    // with the `table` role may only have rows beneath it, and an open editor
    // is a real render object with real semantics that has to go somewhere —
    // so the table is a child here, and the overlay children are its siblings.
    final table = _tableNode ??= SemanticsNode();
    table
      ..rect = Offset.zero & size
      ..updateWith(
        config: SemanticsConfiguration()..role = SemanticsRole.table,
        childrenInInversePaintOrder: rows,
      );

    node.updateWith(
      config: config,
      childrenInInversePaintOrder: <SemanticsNode>[table, ...children],
    );
  }

  String _semanticLabelFor(int column, FitGridCellSpec spec) {
    final value = spec.semanticLabel ?? spec.text;
    final label = _paintColumns[column].label;
    if (label.isEmpty) return value;
    if (value.isEmpty) return '$label, blank';
    return '$label, $value';
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _rowNodes.clear();
    _cellNodes.clear();
    _tableNode = null;
  }

  // -------------------------------------------------------------- utilities

  /// The row at a vertical offset in this section's local coordinates, or -1
  /// when the offset falls outside the content.
  ///
  /// Arithmetic when rows share a height, a binary search over a prefix-sum
  /// table when they do not — which is why callers go through it rather than
  /// dividing themselves.
  int rowAtOffset(double dy) => _rowMetrics.rowAtOffset(dy + _verticalOffset);

  /// The visible-column index at a horizontal offset in local coordinates, or
  /// -1 when outside the content.
  ///
  /// The pinned bands are tested first and in screen space, because that is
  /// where they are: a pointer over a pinned column is nowhere near the content
  /// offset the same x would mean in the scrolling band.
  int columnAtOffset(double dx) {
    final layout = _columnLayout;
    if (layout.isEmpty) return -1;
    final logical = _textDirection == TextDirection.ltr ? dx : size.width - dx;
    if (logical < 0 || logical > size.width) return -1;

    if (logical < layout.leadingFrozenWidth) {
      return layout.columnAtOffset(logical);
    }
    final trailingEdge = size.width - layout.trailingFrozenWidth;
    if (layout.trailingFrozenStart < layout.length && logical >= trailingEdge) {
      final index = layout.columnAtOffset(
        layout.totalWidth - (size.width - logical),
      );
      return index >= layout.length ? layout.length - 1 : index;
    }
    return layout.scrollableColumnAtOffset(logical + _horizontalOffset);
  }

  /// The scroll offsets that would bring a cell fully into view, or null for an
  /// axis that already shows it.
  ///
  /// Lives here because it is the only place that knows both the row geometry
  /// and how much of the width the pinned bands have already taken — scrolling
  /// a cell into view behind a pinned column is the bug this exists to avoid.
  (double? vertical, double? horizontal) revealOffsetsFor(
    int row,
    int column, {
    double padding = 0.0,
  }) {
    double? dy;
    if (row >= 0 && row < rowCount) {
      final top = _rowMetrics.offsetOf(row);
      final bottom = top + _rowMetrics.heightOf(row);
      if (top - padding < _verticalOffset) {
        dy = math.max(0.0, top - padding);
      } else if (bottom + padding > _verticalOffset + size.height) {
        dy = math.min(
          math.max(0.0, contentHeight - size.height),
          bottom + padding - size.height,
        );
      }
    }

    double? dx;
    final layout = _columnLayout;
    if (column >= 0 && column < layout.length && layout.scrolls(column)) {
      // Measured from the leading edge of the scrolling band, not the viewport,
      // so a pinned column never gets to hide the cell we just scrolled to.
      final bandStart = layout.offsets[layout.leadingFrozenCount];
      final start = layout.offsets[column] - bandStart;
      final end = start + layout.widths[column];
      if (start - padding < _horizontalOffset) {
        dx = math.max(0.0, start - padding);
      } else if (end + padding > _horizontalOffset + _scrollableExtent) {
        dx = math.min(maxHorizontalOffset, end + padding - _scrollableExtent);
      }
    }
    return (dy, dx);
  }

  /// How many cell painters are currently held.
  ///
  /// This is the cost of the text pass, made observable. It should track the
  /// viewport — window rows times painted columns — and never the dataset. A
  /// test asserting on it will fail the moment windowing or cache pruning
  /// regresses, which is the failure most likely to slip through unnoticed.
  int get paintedCellCount => _cells.length;

  /// How many semantics nodes the accessibility tree currently holds. Observable
  /// for the same reason [paintedCellCount] is: emitting a node per row of the
  /// dataset would undo virtualization from the one direction nobody watches.
  int get semanticsNodeCount => _rowNodes.length + _cellNodes.length;

  /// Whether a cell's text is currently ellipsized. Only meaningful for cells
  /// inside the window, since only those have been laid out.
  bool isTruncated(int row, int column) =>
      _byCell[_cellKey(row, column)]?.truncated ?? false;

  /// Height of a cell's laid-out text, or null if it is outside the window.
  ///
  /// Observable for the same reason [paintedCellCount] is: a cell taller than
  /// its row paints over its neighbours, and that is a regression a test should
  /// be able to catch without reading pixels.
  double? paintedTextHeight(int row, int column) =>
      _byCell[_cellKey(row, column)]?.painter.height;

  /// The text painted into a cell. Used by `package:fitgrid_table/testing.dart`,
  /// which exists because painted text is invisible to `find.text`.
  String cellText(int row, int column) => _cellSpec(row, column).text;

  /// The full spec behind a cell, for tests that need more than its text.
  FitGridCellSpec cellSpecAt(int row, int column) => _cellSpec(row, column);

  /// Whether a horizontal position falls inside the disclosure glyph of a
  /// nested row's first cell.
  ///
  /// Lives here because the indent and the glyph are geometry the render layer
  /// owns; the widget layer would have to reconstruct both to ask the same
  /// question, and would get it wrong under RTL.
  bool isWithinDisclosure(int row, double dx) {
    if (_columnLayout.isEmpty) return false;
    final indent = _rowIndent?.call(row) ?? 0.0;
    final padding = _theme.effectiveCellPadding;
    final start = _screenLeft(0) + indent + padding.left;
    final extent = _theme.sortIconSize + _theme.cellIconGap;
    return _textDirection == TextDirection.ltr
        ? dx >= start && dx <= start + extent
        : dx <=
                  _screenLeft(0) +
                      _columnLayout.widths[0] -
                      indent -
                      padding.left &&
              dx >=
                  _screenLeft(0) +
                      _columnLayout.widths[0] -
                      indent -
                      padding.left -
                      extent;
  }

  /// On-screen left edge of a column. Exposed for
  /// `package:fitgrid_table/testing.dart`, where it is how a test proves a pinned
  /// column stayed put while the rest scrolled.
  double debugColumnLeft(int columnIndex) => _screenLeft(columnIndex);

  @override
  bool hitTestSelf(Offset position) => true;

  /// Hits only a child whose band contains the position, so a widget scrolled
  /// under a pinned column cannot be pressed through it.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as FitGridCellParentData;
      final band = _bandOf(data.columnIndex);
      if (band != null && _bandLocalRect(band).contains(position)) {
        final box = child;
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (result, transformed) =>
              box.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void dispose() {
    for (final clip in _bandClips) {
      clip.layer = null;
    }
    _clearCache();
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('rowCount', rowCount))
      ..add(IntProperty('firstVisibleRow', _firstVisibleRow))
      ..add(IntProperty('visibleRowCount', _visibleRowCount))
      ..add(IntProperty('cachedPainters', _cells.length))
      ..add(IntProperty('specVersion', _specVersion))
      ..add(DoubleProperty('contentWidth', contentWidth))
      ..add(DoubleProperty('contentHeight', contentHeight))
      ..add(
        IntProperty(
          'frozenColumns',
          _columnLayout.leadingFrozenCount,
          defaultValue: 0,
        ),
      )
      ..add(
        FlagProperty(
          'uniformRows',
          value: _rowMetrics.isUniform,
          ifFalse: 'content-sized rows',
        ),
      );
  }
}

class _CachedCell {
  _CachedCell({
    required this.painter,
    required this.icon,
    required this.iconAdvance,
    required this.spec,
    required this.maxWidth,
    required this.maxHeight,
    required this.truncated,
    required this.faded,
    required this.overflows,
  });

  final TextPainter painter;

  /// Laid-out glyph for [FitGridCellSpec.icon], or null.
  final TextPainter? icon;

  /// Horizontal space the icon and its gap take from the text.
  final double iconAdvance;

  final FitGridCellSpec spec;
  final double maxWidth;
  final double maxHeight;

  /// Whether any of the cell's text was dropped — by an ellipsis, by the line
  /// cap, or by running past the column edge.
  final bool truncated;

  /// Whether the glyphs carry the fade gradient.
  ///
  /// A shader is resolved in canvas coordinates, so a faded cell has to be
  /// painted with the canvas translated to its own origin — otherwise the ramp
  /// sits wherever the section's top-left happens to be, and the text comes out
  /// entirely transparent.
  final bool faded;

  /// Whether the laid-out text still exceeds its box and so has to be clipped
  /// at paint time.
  final bool overflows;

  /// The paint this entry was last wanted for. What the cache evicts on.
  int epoch = 0;

  bool get hasHighlights => spec.hasHighlights;

  void dispose() {
    painter.dispose();
    icon?.dispose();
  }
}
