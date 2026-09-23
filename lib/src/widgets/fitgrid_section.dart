import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
import '../sizing/row_metrics.dart';
import '../theme/fitgrid_theme.dart';

/// Builds the widget for one cell, or null for none. Indices are into the
/// section: rows local to the page, columns into the visible columns.
typedef FitGridSectionCellBuilder = Widget? Function(int row, int column);

/// Builds the full-width widget for one row, or null for none.
typedef FitGridSectionRowBuilder = Widget? Function(int row);

/// Widget wrapper around [RenderFitGridSection].
///
/// [children] are fixed overlay children — the editor — and each must be
/// tagged with a [FitGridCell] naming the cell it occupies.
///
/// Widget cells are different: which of them exist depends on which rows are
/// on screen, and only layout knows that, so they are built during layout by
/// [cellBuilder] for the [widgetColumns] of every row in the window.
class FitGridSection extends RenderObjectWidget {
  const FitGridSection({
    required this.columnLayout,
    required this.paintColumns,
    required this.cellSpec,
    required this.specVersion,
    required this.theme,
    required this.rowMetrics,
    required this.vertical,
    required this.horizontal,
    this.overscanRows = 2,
    this.rowColor,
    this.isRowSelected,
    this.striped = true,
    this.editingCell = (-1, -1),
    this.focusedCell = (-1, -1),
    this.hoveredRow = -1,
    this.selectedRange = RenderFitGridSection.noRange,
    this.dropLine = -1,
    this.fillHandleCell = (-1, -1),
    this.fillPreview = RenderFitGridSection.noRange,
    this.rowIndexOffset = 0,
    this.cellSpan,
    this.rowIndent,
    this.isFullRow,
    this.stickyChain,
    this.groupEnd,
    this.onCellActivate,
    this.cellBuilder,
    this.rowBuilder,
    this.widgetColumns = const <int>[],
    this.children = const <Widget>[],
    super.key,
  });

  /// Fixed overlay children, each wrapped in a [FitGridCell].
  final List<Widget> children;

  /// Builds a widget cell. Null when no column has a builder.
  final FitGridSectionCellBuilder? cellBuilder;

  /// Indices of the columns [cellBuilder] is asked about.
  final List<int> widgetColumns;

  /// Builds a full-width widget for a row — a detail panel. Asked about every
  /// row in the window; return null for the rows that have none.
  final FitGridSectionRowBuilder? rowBuilder;

  /// Rows given over to a [rowBuilder] widget, whose cells are not painted.
  final FitGridRowFlagResolver? isFullRow;

  /// Group headers to pin while their rows scroll. See
  /// [RenderFitGridSection.stickyChain].
  final FitGridStickyChainResolver? stickyChain;
  final FitGridGroupEndResolver? groupEnd;

  @override
  RenderObjectElement createElement() => _FitGridSectionElement(this);

  final FitGridColumnLayout columnLayout;
  final List<FitGridPaintColumn> paintColumns;
  final FitGridCellSpecResolver cellSpec;
  final int specVersion;
  final FitGridThemeData theme;
  final FitGridRowMetrics rowMetrics;
  final ViewportOffset vertical;
  final ViewportOffset horizontal;
  final int overscanRows;
  final FitGridRowColorResolver? rowColor;

  /// Whether a row is selected, for the semantics tree. Separate from
  /// [rowColor] because "selected" is a state a screen reader announces, and a
  /// colour is not.
  final FitGridRowFlagResolver? isRowSelected;
  final bool striped;

  /// The cell carrying the keyboard focus ring, or (-1, -1).
  final (int, int) focusedCell;

  /// The row under the pointer, or -1.
  final int hoveredRow;

  /// The selected block of cells, inclusive, or [RenderFitGridSection.noRange].
  final (int, int, int, int) selectedRange;

  /// Where a dragged row would be dropped, or -1.
  final int dropLine;

  /// The cell carrying the fill handle, or (-1, -1).
  final (int, int) fillHandleCell;

  /// The block a fill drag would write, or [RenderFitGridSection.noRange].
  final (int, int, int, int) fillPreview;

  /// Added to a local row index to name it in the full dataset. Non-zero only
  /// when paginated, and used only by semantics.
  final int rowIndexOffset;

  /// How many columns each cell covers. Null means every cell covers one.
  final FitGridCellSpanResolver? cellSpan;

  /// Extra leading inset for a row's first cell, for nesting.
  final FitGridRowIndentResolver? rowIndent;

  /// Invoked when a screen reader activates a cell.
  final void Function(int row, int column)? onCellActivate;

  /// The cell an editor is covering, as (row, column) indices into this
  /// section, or (-1, -1) when none is open.
  final (int, int) editingCell;

  @override
  RenderFitGridSection createRenderObject(BuildContext context) {
    return RenderFitGridSection(
      columnLayout: columnLayout,
      paintColumns: paintColumns,
      cellSpec: cellSpec,
      specVersion: specVersion,
      theme: theme,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      rowMetrics: rowMetrics,
      vertical: vertical,
      horizontal: horizontal,
      overscanRows: overscanRows,
      rowColor: rowColor,
      isRowSelected: isRowSelected,
      striped: striped,
      editingRow: editingCell.$1,
      editingColumn: editingCell.$2,
      focusedRow: focusedCell.$1,
      focusedColumn: focusedCell.$2,
      hoveredRow: hoveredRow,
      selectedRange: selectedRange,
      dropLine: dropLine,
      fillHandleCell: fillHandleCell,
      fillPreview: fillPreview,
      rowIndexOffset: rowIndexOffset,
      cellSpan: cellSpan,
      rowIndent: rowIndent,
      isFullRow: isFullRow,
      stickyChain: stickyChain,
      groupEnd: groupEnd,
      onCellActivate: onCellActivate,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFitGridSection renderObject,
  ) {
    renderObject
      ..columnLayout = columnLayout
      ..paintColumns = paintColumns
      ..cellSpec = cellSpec
      ..specVersion = specVersion
      ..theme = theme
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context)
      ..rowMetrics = rowMetrics
      ..vertical = vertical
      ..horizontal = horizontal
      ..overscanRows = overscanRows
      ..rowColor = rowColor
      ..isRowSelected = isRowSelected
      ..striped = striped
      ..editingCell = editingCell
      ..focusedCell = focusedCell
      ..hoveredRow = hoveredRow
      ..selectedRange = selectedRange
      ..dropLine = dropLine
      ..fillHandleCell = fillHandleCell
      ..fillPreview = fillPreview
      ..rowIndexOffset = rowIndexOffset
      ..cellSpan = cellSpan
      ..rowIndent = rowIndent
      ..isFullRow = isFullRow
      ..stickyChain = stickyChain
      ..groupEnd = groupEnd
      ..onCellActivate = onCellActivate;
  }
}

/// Tags an overlay child with the cell it occupies.
class FitGridCell extends ParentDataWidget<FitGridCellParentData> {
  const FitGridCell({
    required this.rowIndex,
    required this.columnIndex,
    required super.child,
    super.key,
  });

  final int rowIndex;
  final int columnIndex;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as FitGridCellParentData;
    var changed = false;
    if (data.rowIndex != rowIndex) {
      data.rowIndex = rowIndex;
      changed = true;
    }
    if (data.columnIndex != columnIndex) {
      data.columnIndex = columnIndex;
      changed = true;
    }
    if (changed) {
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FitGridSection;
}

/// The slot every widget cell sits in. Cells are not ordered among themselves
/// — they never overlap — so they share one slot and are appended after the
/// fixed children.
const Object _cellSlot = Object();

/// Manages two kinds of children: the widget's fixed [FitGridSection.children],
/// reconciled in build like any multi-child widget, and the widget cells,
/// reconciled during layout against the rows the render object says are on
/// screen — the same arrangement a sliver list uses, for the same reason.
class _FitGridSectionElement extends RenderObjectElement {
  _FitGridSectionElement(FitGridSection super.widget);

  List<Element> _fixed = <Element>[];
  final Set<Element> _forgottenFixed = <Element>{};
  Map<(int, int), Element> _cells = <(int, int), Element>{};

  FitGridSection get _section => widget as FitGridSection;

  @override
  RenderFitGridSection get renderObject =>
      super.renderObject as RenderFitGridSection;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    Element? previous;
    for (var i = 0; i < _section.children.length; i++) {
      previous = inflateWidget(
        _section.children[i],
        IndexedSlot<Element?>(i, previous),
      );
      _fixed.add(previous);
    }
    _wireBuilder();
  }

  @override
  void update(FitGridSection newWidget) {
    super.update(newWidget);
    _fixed = updateChildren(
      _fixed,
      newWidget.children,
      forgottenChildren: _forgottenFixed,
    );
    _forgottenFixed.clear();
    _wireBuilder();
  }

  /// Points the render object at this element's cell builder, and asks for the
  /// cells to be rebuilt: a new widget means the rows, the columns or the
  /// builders may have changed, even if the window has not.
  void _wireBuilder() {
    final render = renderObject;
    final wantsCells =
        _section.cellBuilder != null && _section.widgetColumns.isNotEmpty;
    if (!wantsCells && _section.rowBuilder == null) {
      render.cellBuilder = null;
      // Nothing will ask again, so the cells go now rather than at a layout
      // that will not build any.
      if (_cells.isNotEmpty) {
        for (final cell in _cells.values) {
          updateChild(cell, null, _cellSlot);
        }
        _cells = <(int, int), Element>{};
      }
      return;
    }
    render
      ..cellBuilder = _buildCells
      ..markCellsNeedBuild();
  }

  /// Called by the render object, inside layout, with the rows now on screen.
  void _buildCells(int first, int last) {
    owner!.buildScope(this, () {
      final build = _section.cellBuilder;
      final columns = build == null ? const <int>[] : _section.widgetColumns;
      final buildRow = _section.rowBuilder;
      final next = <(int, int), Element>{};
      for (var row = first; row < last; row++) {
        if (buildRow != null) {
          const column = FitGridCellParentData.fullRow;
          final key = (row, column);
          final built = buildRow(row);
          final element = updateChild(
            _cells.remove(key),
            built == null
                ? null
                : FitGridCell(rowIndex: row, columnIndex: column, child: built),
            _cellSlot,
          );
          if (element != null) next[key] = element;
        }
        for (final column in columns) {
          final key = (row, column);
          final built = build!(row, column);
          final element = updateChild(
            _cells.remove(key),
            built == null
                ? null
                : FitGridCell(rowIndex: row, columnIndex: column, child: built),
            _cellSlot,
          );
          if (element != null) next[key] = element;
        }
      }
      // Whatever is left scrolled out of the window.
      for (final stale in _cells.values) {
        updateChild(stale, null, _cellSlot);
      }
      _cells = next;
    });
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final child in _fixed) {
      if (!_forgottenFixed.contains(child)) visitor(child);
    }
    _cells.values.forEach(visitor);
  }

  @override
  void forgetChild(Element child) {
    final before = _cells.length;
    _cells.removeWhere((_, cell) => identical(cell, child));
    if (_cells.length == before) _forgottenFixed.add(child);
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    if (slot is IndexedSlot<Element?>) {
      // Fixed children stay at the front, in order.
      renderObject.insert(child, after: slot.value?.renderObject as RenderBox?);
    } else {
      renderObject.insert(child, after: renderObject.lastChild);
    }
  }

  @override
  void moveRenderObjectChild(
    RenderBox child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    if (newSlot is IndexedSlot<Element?>) {
      renderObject.move(
        child,
        after: newSlot.value?.renderObject as RenderBox?,
      );
    }
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) {
    renderObject.remove(child);
  }
}
