import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/enums.dart';
import '../sizing/column_layout.dart';
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
    required int rowCount,
    required double rowHeight,
    required ViewportOffset vertical,
    required ViewportOffset horizontal,
    int overscanRows = 2,
    TextScaler textScaler = TextScaler.noScaling,
    FitGridRowColorResolver? rowColor,
    bool striped = true,
  }) : _columnLayout = columnLayout,
       _paintColumns = paintColumns,
       _cellSpec = cellSpec,
       _specVersion = specVersion,
       _theme = theme,
       _textDirection = textDirection,
       _rowCount = rowCount,
       _rowHeight = rowHeight,
       _vertical = vertical,
       _horizontal = horizontal,
       _overscanRows = overscanRows,
       _textScaler = textScaler,
       _rowColor = rowColor,
       _striped = striped;

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

  int _rowCount;
  int get rowCount => _rowCount;
  set rowCount(int value) {
    if (_rowCount == value) return;
    _rowCount = value;
    markNeedsLayout();
  }

  double _rowHeight;
  double get rowHeight => _rowHeight;
  set rowHeight(double value) {
    if (_rowHeight == value) return;
    _rowHeight = value;
    _clearCache();
    markNeedsLayout();
  }

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
      math.min(_firstVisibleRow + _visibleRowCount, _rowCount);

  /// Total height of all rows, whether or not they are in the window.
  double get contentHeight => _rowCount * _rowHeight;

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

    final first = math.max(
      0,
      (_verticalOffset / _rowHeight).floor() - _overscanRows,
    );
    final span = (size.height / _rowHeight).ceil() + 1 + _overscanRows * 2;
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
        child.layout(
          BoxConstraints.tightFor(width: width, height: _rowHeight),
          parentUsesSize: false,
        );
        data.offset = Offset(
          _dx(columnIndex, width) - _horizontalOffset,
          rowIndex * _rowHeight - _verticalOffset,
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
    if (_columnLayout.isEmpty || _rowCount == 0) return;
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
      final top = offset.dy + row * _rowHeight - _verticalOffset;
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, top, size.width, _rowHeight),
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
      final y = offset.dy + (row + 1) * _rowHeight - _verticalOffset;
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
      final top = offset.dy + row * _rowHeight - _verticalOffset;

      for (var column = firstColumn; column < lastColumn; column++) {
        if (_paintColumns[column].isWidgetColumn) continue;

        final width = _columnLayout.widths[column];
        final available = width - padding.horizontal;
        if (available <= 0) continue;

        final cell = _cellFor(row, column, available);
        final left = offset.dx + _dx(column, width) - _horizontalOffset;

        final free = available - cell.painter.width;
        final inset = switch (_resolvedAlignment(column)) {
          FitGridAlignment.start => padding.left,
          FitGridAlignment.center => padding.left + math.max(0, free) / 2,
          FitGridAlignment.end => padding.left + math.max(0, free),
        };

        cell.painter.paint(
          canvas,
          Offset(left + inset, top + (_rowHeight - cell.painter.height) / 2),
        );
      }
    }
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
  _CachedCell _cellFor(int row, int column, double maxWidth) {
    final key = _cellKey(row, column);
    final spec = _cellSpec(row, column);
    final existing = _cells[key];

    if (existing != null &&
        existing.spec == spec &&
        existing.maxWidth == maxWidth) {
      return existing;
    }

    final painter =
        existing?.painter ??
        TextPainter(maxLines: 1, textDirection: _textDirection);
    painter
      ..text = TextSpan(text: spec.text, style: spec.style)
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..ellipsis = switch (spec.overflow) {
        FitGridOverflow.ellipsis || FitGridOverflow.tooltipOnTruncate => '…',
        FitGridOverflow.fade || FitGridOverflow.clip => null,
      }
      ..layout(maxWidth: maxWidth);

    final cell = _CachedCell(
      painter: painter,
      spec: spec,
      maxWidth: maxWidth,
      truncated:
          painter.didExceedMaxLines ||
          painter.maxIntrinsicWidth > maxWidth + 0.5,
    );
    _cells[key] = cell;
    return cell;
  }

  // -------------------------------------------------------------- utilities

  /// The row at a vertical offset in this section's local coordinates, or -1
  /// when the offset falls outside the content.
  ///
  /// With uniform row heights this is arithmetic. It becomes a binary search
  /// over a prefix-sum table once content-sized rows land, which is why callers
  /// go through it rather than dividing themselves.
  int rowAtOffset(double dy) {
    final contentY = dy + _verticalOffset;
    if (contentY < 0 || contentY >= contentHeight) return -1;
    return (contentY ~/ _rowHeight).clamp(0, _rowCount - 1);
  }

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
      ..add(IntProperty('rowCount', _rowCount))
      ..add(IntProperty('firstVisibleRow', _firstVisibleRow))
      ..add(IntProperty('visibleRowCount', _visibleRowCount))
      ..add(IntProperty('cachedPainters', _cells.length))
      ..add(IntProperty('specVersion', _specVersion))
      ..add(DoubleProperty('contentWidth', contentWidth))
      ..add(DoubleProperty('contentHeight', contentHeight));
  }
}

class _CachedCell {
  _CachedCell({
    required this.painter,
    required this.spec,
    required this.maxWidth,
    required this.truncated,
  });

  final TextPainter painter;
  final FitGridCellSpec spec;
  final double maxWidth;
  final bool truncated;
}
