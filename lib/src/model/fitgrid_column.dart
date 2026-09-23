import 'package:flutter/widgets.dart';

import 'column_width.dart';
import 'enums.dart';
import 'fitgrid_editor.dart';

/// Resolves the painted text for one cell.
typedef FitGridCellValue<T> = String Function(T row);

/// Builds a real widget for one cell, instead of painted text.
///
/// Cells with a builder are meant for the overlay layer — real render children
/// sitting over the painted grid — so they cost what a widget costs. Use them
/// for the handful of columns that need interactivity or chrome (status pills,
/// avatars, buttons) and leave the rest as painted text.
///
/// Not yet instantiated: the render layer already reserves these columns and
/// skips them in the text pass, but building the widgets lazily as they scroll
/// into view needs the same child-management contract a sliver has, and that
/// lands with virtualized overlay children. Until then a builder column
/// reserves its space and renders nothing.
typedef FitGridCellBuilder<T> =
    Widget Function(BuildContext context, T row, int rowIndex);

/// Per-cell text style override, layered on top of the theme's cell style.
///
/// The index is into the full row list, not into the page on screen.
typedef FitGridCellStyle<T> = TextStyle? Function(T row, int rowIndex);

/// Resolves a glyph to paint before a cell's text, or null for none.
///
/// The index is into the full row list, as every index the grid hands out is.
typedef FitGridCellIcon<T> = IconData? Function(T row, int rowIndex);

/// Resolves the colour of that glyph, or null to follow the text.
typedef FitGridCellIconColor<T> = Color? Function(T row, int rowIndex);

/// Whether a row passes a column's filter.
typedef FitGridRowPredicate<T> = bool Function(T row);

/// Reduces the rows under a column to one string for the footer.
typedef FitGridAggregate<T> = String Function(List<T> rows);

/// One column of a [FitGridColumn]-driven grid.
///
/// Columns are typed against the row type, so the value getter and comparator
/// receive your model rather than a map entry. New capabilities in later
/// releases (filters, aggregates, inline editors) arrive as additional optional
/// fields here rather than as new constructor parameters on the grid itself —
/// that is deliberate, and it is what keeps the grid's own constructor from
/// growing to forty arguments.
@immutable
class FitGridColumn<T> {
  const FitGridColumn({
    required this.id,
    required this.label,
    required this.value,
    this.width = const FitGridColumnWidth.auto(),
    this.alignment = FitGridAlignment.start,
    this.headerAlignment,
    this.overflow = FitGridOverflow.ellipsis,
    this.maxLines = 1,
    this.freeze = FitGridFreeze.none,
    this.visible = true,
    this.resizable = true,
    this.reorderable = true,
    this.sortable = false,
    this.searchable = true,
    this.icon,
    this.iconColor,
    this.semanticValue,
    this.copyValue,
    this.aggregate,
    this.footerLabel,
    this.comparator,
    this.cellBuilder,
    this.headerBuilder,
    this.cellStyle,
    this.tooltip,
    this.editor,
  }) : assert(maxLines == null || maxLines > 0, 'maxLines must be positive');

  /// Stable identity for this column. Used as the key for widths, sort state,
  /// column order and selection, so it must be unique within a grid and must
  /// not change across rebuilds. Do not use the display index.
  final String id;

  /// Header text. Also the string measured by
  /// [FitGridColumnWidth.fitHeader] and included in `auto` measurement.
  final String label;

  /// The cell text for a given row.
  final FitGridCellValue<T> value;

  /// How this column decides its width.
  final FitGridColumnWidth width;

  /// Horizontal alignment of cell content.
  final FitGridAlignment alignment;

  /// Horizontal alignment of the header, defaulting to [alignment].
  final FitGridAlignment? headerAlignment;

  /// What happens when the text is wider than the column.
  final FitGridOverflow overflow;

  /// How many lines a cell may wrap onto before [overflow] takes over. Null
  /// means as many as the text needs.
  ///
  /// Worth anything only under [FitGridRowHeight.contentSized]: a fixed row
  /// height has no room to give a second line, so the extra lines would be
  /// clipped by the row below. Pairing it with a width that actually constrains
  /// the text matters too — a [FitGridColumnWidth.auto] column measures its
  /// longest cell on one line and then sizes itself to fit it, so nothing ever
  /// wraps. Give a wrapping column a `fixed` width, or an `auto` one with a
  /// `max`.
  final int? maxLines;

  /// Whether this column is pinned to an edge during horizontal scroll.
  final FitGridFreeze freeze;

  /// Whether the column is shown at all. Hidden columns keep their width and
  /// sort state, so toggling visibility is cheap and lossless.
  final bool visible;

  /// Whether the user can drag this column's trailing divider to resize it,
  /// and double-click that divider to re-fit it to its content.
  final bool resizable;

  /// Whether the user can drag this column's header to move it. A pinned
  /// column can still be reordered, but only within its own band.
  final bool reorderable;

  /// Whether the grid's search looks at this column. Turn it off for ids,
  /// checksums and anything else where a coincidental match is noise.
  final bool searchable;

  /// A glyph painted before the cell's text.
  ///
  /// Painted by the same painter that draws the text, so a status icon costs a
  /// glyph rather than turning the column into an overlay of `Icon` widgets.
  final FitGridCellIcon<T>? icon;

  /// Colour for [icon]. Null follows the cell's text colour.
  final FitGridCellIconColor<T>? iconColor;

  /// What a screen reader should announce for a cell, when the painted text is
  /// not the right thing to say — "3m ago" painted, "3 minutes ago" spoken.
  final FitGridCellValue<T>? semanticValue;

  /// What the clipboard should receive for a cell. Defaults to [value], which
  /// is right until the painted text is formatted for the eye rather than for
  /// a spreadsheet.
  final FitGridCellValue<T>? copyValue;

  /// Reduces this column to a single footer value — a sum, a mean, a count.
  /// Null leaves the footer cell blank.
  final FitGridAggregate<T>? aggregate;

  /// A label painted before the aggregate, such as `Total`.
  final String? footerLabel;

  /// Whether tapping the header cycles this column's sort state.
  final bool sortable;

  /// Orders two rows by this column. Defaults to a string comparison of
  /// [value] when null, which is right for text and wrong for numbers and
  /// dates — supply one for those.
  final Comparator<T>? comparator;

  /// Builds a real widget for each cell instead of painting text. See
  /// [FitGridCellBuilder].
  final FitGridCellBuilder<T>? cellBuilder;

  /// Replaces the default header cell.
  final WidgetBuilder? headerBuilder;

  /// Per-cell text style override.
  final FitGridCellStyle<T>? cellStyle;

  /// Tooltip shown on the header cell.
  final String? tooltip;

  /// Makes this column's cells editable. Null leaves them read-only.
  ///
  /// The editor is a real widget, but only one exists and only while a cell is
  /// open — see [FitGridEditor].
  final FitGridEditor<T>? editor;

  /// Whether a cell in this column can be opened for editing.
  bool get isEditable => editor != null;

  /// The text the clipboard should carry for [row].
  String copyTextFor(T row) => (copyValue ?? value)(row);

  /// What a screen reader should say for [row].
  String semanticTextFor(T row) => (semanticValue ?? value)(row);

  /// Effective header alignment.
  FitGridAlignment get effectiveHeaderAlignment => headerAlignment ?? alignment;

  /// Orders [a] and [b] by this column, falling back to comparing the rendered
  /// text when no [comparator] was supplied.
  int compare(T a, T b) =>
      comparator?.call(a, b) ?? value(a).compareTo(value(b));

  FitGridColumn<T> copyWith({
    String? id,
    String? label,
    FitGridCellValue<T>? value,
    FitGridColumnWidth? width,
    FitGridAlignment? alignment,
    FitGridAlignment? headerAlignment,
    FitGridOverflow? overflow,
    int? maxLines,
    FitGridFreeze? freeze,
    bool? visible,
    bool? resizable,
    bool? reorderable,
    bool? sortable,
    bool? searchable,
    FitGridCellIcon<T>? icon,
    FitGridCellIconColor<T>? iconColor,
    FitGridCellValue<T>? semanticValue,
    FitGridCellValue<T>? copyValue,
    FitGridAggregate<T>? aggregate,
    String? footerLabel,
    Comparator<T>? comparator,
    FitGridCellBuilder<T>? cellBuilder,
    WidgetBuilder? headerBuilder,
    FitGridCellStyle<T>? cellStyle,
    String? tooltip,
    FitGridEditor<T>? editor,
  }) {
    return FitGridColumn<T>(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      width: width ?? this.width,
      alignment: alignment ?? this.alignment,
      headerAlignment: headerAlignment ?? this.headerAlignment,
      overflow: overflow ?? this.overflow,
      maxLines: maxLines ?? this.maxLines,
      freeze: freeze ?? this.freeze,
      visible: visible ?? this.visible,
      resizable: resizable ?? this.resizable,
      reorderable: reorderable ?? this.reorderable,
      sortable: sortable ?? this.sortable,
      searchable: searchable ?? this.searchable,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      semanticValue: semanticValue ?? this.semanticValue,
      copyValue: copyValue ?? this.copyValue,
      aggregate: aggregate ?? this.aggregate,
      footerLabel: footerLabel ?? this.footerLabel,
      comparator: comparator ?? this.comparator,
      cellBuilder: cellBuilder ?? this.cellBuilder,
      headerBuilder: headerBuilder ?? this.headerBuilder,
      cellStyle: cellStyle ?? this.cellStyle,
      tooltip: tooltip ?? this.tooltip,
      editor: editor ?? this.editor,
    );
  }

  @override
  String toString() => 'FitGridColumn($id)';
}
