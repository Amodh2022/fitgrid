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

/// Parent data for overlay children — the real widgets layered over the
/// painted grid for cells that need interactivity or chrome.
class FitGridCellParentData extends ContainerBoxParentData<RenderBox> {
  /// Absolute row index, not an index into the visible window.
  int rowIndex = -1;

  /// Index into the visible columns of the section's [FitGridColumnLayout].
  int columnIndex = -1;
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
/// Three things keep that from degrading:
///
/// * **Windowing.** Only rows in `[firstVisibleRow, firstVisibleRow +
///   visibleRowCount)` and columns intersecting the horizontal viewport are
///   touched, so cost tracks the viewport rather than the dataset.
/// * **Painter caching.** A cell's `TextPainter` survives across paints and is
///   re-laid-out only when its spec or its column width changes. The cache is
///   pruned to the window, so it stays bounded by what is on screen.
/// * **Batched rules.** Every divider in the section is one
///   `drawRawPoints(PointMode.lines)` over a reused `Float32List`, not a
///   `drawLine` per edge.
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
    bool striped = true,
    int editingRow = -1,
    int editingColumn = -1,
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
       _striped = striped,
       _editingRow = editingRow,
       _editingColumn = editingColumn;

  // ---------------------------------------------------------------- geometry

  FitGridColumnLayout _columnLayout;

  /// Resolved widths and offsets of the visible columns.
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
  }

  List<FitGridPaintColumn> _paintColumns;
  List<FitGridPaintColumn> get paintColumns => _paintColumns;
  set paintColumns(List<FitGridPaintColumn> value) {
    if (listEquals(_paintColumns, value)) return;
    _paintColumns = value;
    _clearCache();
    markNeedsPaint();
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

  // ------------------------------------------------------------ paint caches

  final Map<int, _CachedCell> _cells = <int, _CachedCell>{};
  Float32List? _rulePoints;
  int _ruleCount = 0;

  int _cellKey(int row, int column) => row * 1000003 + column;

  void _clearCache() {
    for (final cell in _cells.values) {
      cell.painter.dispose();
    }
    _cells.clear();
  }

  /// Drops painters for rows that have scrolled out of the window, which is
  /// what keeps the cache bounded by the viewport rather than the dataset.
  void _pruneCache() {
    if (_cells.isEmpty) return;
    final first = _firstVisibleRow;
    final last = _firstVisibleRow + _visibleRowCount;
    _cells.removeWhere((key, cell) {
      final row = key ~/ 1000003;
      if (row >= first && row < last) return false;
      cell.painter.dispose();
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
    final maxVertical = math.max(0.0, contentHeight - size.height);
    final maxHorizontal = math.max(0.0, contentWidth - size.width);

    _vertical
      ..applyViewportDimension(size.height)
      ..applyContentDimensions(0.0, maxVertical);
    _horizontal
      ..applyViewportDimension(size.width)
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
      _pruneCache();
    }

    // Overlay children are already scoped to the window by the widget layer;
    // all that remains is to give each one its cell box.
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FitGridCellParentData;
      final columnIndex = data.columnIndex;
      final rowIndex = data.rowIndex;

      if (columnIndex < 0 || columnIndex >= _columnLayout.length) {
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
          _dx(columnIndex, width) - _horizontalOffset,
          (inRange ? _rowMetrics.offsetOf(rowIndex) : 0.0) - _verticalOffset,
        );
      }
      child = data.nextSibling;
    }
  }

  /// Leading edge of a column in content space, honouring text direction.
  ///
  /// In RTL the visual order of columns is mirrored: the first column sits at
  /// the right edge of the content. Doing that here, once, is what keeps every
  /// other bit of geometry direction-agnostic.
  double _dx(int columnIndex, double width) {
    final start = _columnLayout.offsets[columnIndex];
    return switch (_textDirection) {
      TextDirection.ltr => start,
      TextDirection.rtl => contentWidth - start - width,
    };
  }

  // ----------------------------------------------------------------- paint

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_columnLayout.isEmpty || rowCount == 0) return;
    context.canvas.save();
    context.canvas.clipRect(offset & size);
    _paintRows(context.canvas, offset);
    _paintRules(context.canvas, offset);
    _paintText(context.canvas, offset);
    context.canvas.restore();
    defaultPaint(context, offset);
  }

  /// Which visible columns intersect the horizontal viewport.
  (int, int) get _visibleColumnRange {
    if (_textDirection == TextDirection.rtl) {
      // Mirrored: a scroll offset from the right maps to a window measured from
      // the far end of content space.
      final fromRight = _horizontalOffset;
      final start = _columnLayout.columnAtOffset(
        math.max(0, contentWidth - fromRight - size.width),
      );
      final end = _columnLayout.columnAtOffset(contentWidth - fromRight);
      return (start, math.min(end + 1, _columnLayout.length));
    }
    final start = _columnLayout.columnAtOffset(_horizontalOffset);
    final end = _columnLayout.columnAtOffset(_horizontalOffset + size.width);
    return (start, math.min(end + 1, _columnLayout.length));
  }

  void _paintRows(Canvas canvas, Offset offset) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      final color =
          _rowColor?.call(row) ??
          (_striped && row.isOdd
              ? _theme.alternateRowBackground
              : _theme.rowBackground);
      if (color.a == 0) continue;
      final top = offset.dy + _rowMetrics.offsetOf(row) - _verticalOffset;
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, top, size.width, _rowMetrics.heightOf(row)),
        paint,
      );
    }
  }

  /// Every rule in the section as one call.
  ///
  /// `drawRawPoints` with [PointMode.lines] consumes pairs of points, so the
  /// buffer holds x,y,x,y per segment. Reusing the `Float32List` across paints
  /// matters more than it looks: this runs on every frame of a scroll.
  void _paintRules(Canvas canvas, Offset offset) {
    final (firstColumn, lastColumn) = _visibleColumnRange;
    final rowRules = _lastVisibleRow - _firstVisibleRow;
    final columnRules = math.max(0, lastColumn - firstColumn - 1);
    final segments = rowRules + columnRules;
    if (segments == 0) return;

    final needed = segments * 4;
    var buffer = _rulePoints;
    if (buffer == null || buffer.length < needed) {
      buffer = _rulePoints = Float32List(needed);
    }

    var i = 0;
    final bottom = offset.dy + size.height;

    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      final y = offset.dy + _rowMetrics.offsetOf(row + 1) - _verticalOffset;
      buffer[i++] = offset.dx;
      buffer[i++] = y;
      buffer[i++] = offset.dx + size.width;
      buffer[i++] = y;
    }

    for (var column = firstColumn; column < lastColumn - 1; column++) {
      final width = _columnLayout.widths[column];
      final x =
          offset.dx +
          _dx(column, width) -
          _horizontalOffset +
          (_textDirection == TextDirection.ltr ? width : 0.0);
      buffer[i++] = x;
      buffer[i++] = offset.dy;
      buffer[i++] = x;
      buffer[i++] = bottom;
    }

    _ruleCount = i;
    canvas.drawRawPoints(
      PointMode.lines,
      _ruleCount == buffer.length
          ? buffer
          : Float32List.sublistView(buffer, 0, _ruleCount),
      Paint()
        ..color = _theme.rowDivider
        ..strokeWidth = _theme.dividerThickness,
    );
  }

  void _paintText(Canvas canvas, Offset offset) {
    final (firstColumn, lastColumn) = _visibleColumnRange;
    final padding = _theme.effectiveCellPadding;

    for (var row = _firstVisibleRow; row < _lastVisibleRow; row++) {
      final top = offset.dy + _rowMetrics.offsetOf(row) - _verticalOffset;
      final height = _rowMetrics.heightOf(row);

      for (var column = firstColumn; column < lastColumn; column++) {
        if (_paintColumns[column].isWidgetColumn) continue;
        if (row == _editingRow && column == _editingColumn) continue;

        final width = _columnLayout.widths[column];
        final available = width - padding.horizontal;
        if (available <= 0) continue;
        final availableHeight = height - padding.vertical;
        if (availableHeight <= 0) continue;

        final cell = _cellFor(row, column, available, availableHeight);
        final left = offset.dx + _dx(column, width) - _horizontalOffset;

        final free = available - cell.painter.width;
        final inset = switch (_resolvedAlignment(column)) {
          FitGridAlignment.start => padding.left,
          FitGridAlignment.center => padding.left + math.max(0, free) / 2,
          FitGridAlignment.end => padding.left + math.max(0, free),
        };
        final origin = Offset(
          left + inset,
          top + (height - cell.painter.height) / 2,
        );

        final fading =
            _paintColumns[column].overflow == FitGridOverflow.fade &&
            cell.truncated;

        // A cell that still does not fit — one line taller than the whole row,
        // say — is clipped to its own box rather than allowed to paint over its
        // neighbours. The save/restore is skipped in the overwhelmingly common
        // case where the text already fits, because this runs per cell per
        // frame of a scroll.
        if (fading) {
          _paintFaded(
            canvas,
            cell,
            origin,
            Rect.fromLTWH(left, top, width, height),
            padding.right,
          );
        } else if (cell.overflows) {
          canvas
            ..save()
            ..clipRect(Rect.fromLTWH(left, top, width, height));
          cell.painter.paint(canvas, origin);
          canvas.restore();
        } else {
          cell.painter.paint(canvas, origin);
        }
      }
    }
  }

  /// Paints a cell that ran out of room with a soft alpha ramp at the edge the
  /// text runs off, instead of an ellipsis.
  ///
  /// The ramp is cut out of the glyphs rather than painted over them: a
  /// translucent overlay in the row colour would be wrong the moment a row is
  /// selected, striped or given a custom colour, and would show as a smear over
  /// whatever is behind. `dstOut` erases the text itself, so the fade reveals
  /// the real background whatever it happens to be.
  void _paintFaded(
    Canvas canvas,
    _CachedCell cell,
    Offset origin,
    Rect cellRect,
    double inset,
  ) {
    final rtl = _textDirection == TextDirection.rtl;
    final rampWidth = math.min(_theme.fadeExtent, cellRect.width);
    final edge = rtl ? cellRect.left : cellRect.right;
    final ramp = Rect.fromLTWH(
      rtl ? edge - inset : edge - inset - rampWidth,
      cellRect.top,
      rampWidth,
      cellRect.height,
    );

    canvas
      ..saveLayer(cellRect, Paint())
      ..clipRect(cellRect);
    cell.painter.paint(canvas, origin);
    canvas
      ..drawRect(
        ramp,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = ui.Gradient.linear(
            rtl ? ramp.centerRight : ramp.centerLeft,
            rtl ? ramp.centerLeft : ramp.centerRight,
            const <Color>[Color(0x00000000), Color(0xFF000000)],
          ),
      )
      ..restore();
  }

  /// Resolves a column's alignment against the text direction, so `start`
  /// means "leading edge" rather than "left".
  FitGridAlignment _resolvedAlignment(int column) {
    final alignment = _paintColumns[column].alignment;
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
  _CachedCell _cellFor(int row, int column, double maxWidth, double maxHeight) {
    final key = _cellKey(row, column);
    final spec = _cellSpec(row, column);
    final existing = _cells[key];

    if (existing != null &&
        existing.spec == spec &&
        existing.maxWidth == maxWidth &&
        existing.maxHeight == maxHeight) {
      return existing;
    }

    final painter =
        existing?.painter ?? TextPainter(textDirection: _textDirection);
    painter
      ..text = TextSpan(text: spec.text, style: spec.style)
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..ellipsis = switch (spec.overflow) {
        FitGridOverflow.ellipsis || FitGridOverflow.tooltipOnTruncate => '…',
        FitGridOverflow.fade || FitGridOverflow.clip => null,
      };

    // The line budget is settled before the layout, not after it. Laying the
    // text out unbounded and trimming it afterwards would cost two layouts, and
    // it does not even work: a `TextPainter` carrying an ellipsis with a null
    // `maxLines` ellipsizes on the first line rather than wrapping, so an
    // unbounded cell would silently come back one line tall.
    //
    // `preferredLineHeight` is available before layout, which is what makes
    // this possible.
    final lineHeight = painter.preferredLineHeight;
    final affordable = lineHeight > 0
        ? math.max(1, maxHeight ~/ lineHeight)
        : 1;
    final lines = spec.maxLines == null
        ? affordable
        : math.min(spec.maxLines!, affordable);

    painter
      ..maxLines = lines
      ..layout(maxWidth: maxWidth);

    final cell = _CachedCell(
      painter: painter,
      spec: spec,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      truncated:
          painter.didExceedMaxLines ||
          painter.maxIntrinsicWidth > maxWidth + 0.5,
      // Whole lines are all the budget above can trim. A single line taller
      // than the row it sits in has nowhere left to go, and gets clipped.
      overflows:
          painter.height > maxHeight + 0.5 || painter.width > maxWidth + 0.5,
    );
    _cells[key] = cell;
    return cell;
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
  int columnAtOffset(double dx) {
    final contentX = _textDirection == TextDirection.ltr
        ? dx + _horizontalOffset
        : contentWidth - (dx + _horizontalOffset);
    if (contentX < 0 || contentX >= contentWidth) return -1;
    final index = _columnLayout.columnAtOffset(contentX);
    return index >= _columnLayout.length ? -1 : index;
  }

  /// How many cell painters are currently held.
  ///
  /// This is the cost of the text pass, made observable. It should track the
  /// viewport — window rows times painted columns — and never the dataset. A
  /// test asserting on it will fail the moment windowing or cache pruning
  /// regresses, which is the failure most likely to slip through unnoticed.
  int get paintedCellCount => _cells.length;

  /// Whether a cell's text is currently ellipsized. Only meaningful for cells
  /// inside the window, since only those have been laid out.
  bool isTruncated(int row, int column) =>
      _cells[_cellKey(row, column)]?.truncated ?? false;

  /// Height of a cell's laid-out text, or null if it is outside the window.
  ///
  /// Observable for the same reason [paintedCellCount] is: a cell taller than
  /// its row paints over its neighbours, and that is a regression a test should
  /// be able to catch without reading pixels.
  double? paintedTextHeight(int row, int column) =>
      _cells[_cellKey(row, column)]?.painter.height;

  /// The text painted into a cell. Used by `package:fitgrid/testing.dart`,
  /// which exists because painted text is invisible to `find.text`.
  String cellText(int row, int column) => _cellSpec(row, column).text;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void dispose() {
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
    required this.spec,
    required this.maxWidth,
    required this.maxHeight,
    required this.truncated,
    required this.overflows,
  });

  final TextPainter painter;
  final FitGridCellSpec spec;
  final double maxWidth;
  final double maxHeight;

  /// Whether any of the cell's text was dropped — by an ellipsis, by the line
  /// cap, or by running past the column edge.
  final bool truncated;

  /// Whether the laid-out text still exceeds its box and so has to be clipped
  /// at paint time.
  final bool overflows;
}
