import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/enums.dart';

/// Visual configuration for a grid.
///
/// Everything the render layer needs to paint is resolved into plain [Color]s
/// and [TextStyle]s here, at build time. That is not incidental: painting
/// happens in a `RenderBox` where there is no `BuildContext`, so nothing
/// downstream can look a token up. The whole object is also the cache key for
/// measured widths and cell specs, so it must be cheap to compare — hence the
/// value equality below.
@immutable
class FitGridThemeData {
  const FitGridThemeData({
    required this.headerBackground,
    required this.headerForeground,
    required this.headerTextStyle,
    required this.rowBackground,
    required this.alternateRowBackground,
    required this.cellTextStyle,
    required this.rowDivider,
    required this.columnDivider,
    required this.border,
    required this.hoverBackground,
    required this.selectedBackground,
    required this.focusOutline,
    required this.sortIconColor,
    required this.placeholderForeground,
    required this.tooltipBackground,
    required this.tooltipForeground,
    required this.searchHighlight,
    required this.frozenShadow,
    required this.groupHeaderBackground,
    this.density = FitGridDensity.standard,
    this.dividerThickness = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.resizeHandleWidth = 8.0,
    this.resizeTouchTargetWidth = 32.0,
    this.minColumnWidth = 24.0,
    this.fadeExtent = 28.0,
    this.tooltipMaxWidth = 360.0,
    this.tooltipBorderRadius = const BorderRadius.all(Radius.circular(6)),
    this.sortAscendingIcon = Icons.arrow_upward_rounded,
    this.sortDescendingIcon = Icons.arrow_downward_rounded,
    this.sortUnsortedIcon = Icons.unfold_more_rounded,
    this.resizeGripIcon = Icons.drag_indicator,
    this.checkboxIcon = Icons.check_box_outline_blank_rounded,
    this.checkboxCheckedIcon = Icons.check_box_rounded,
    this.checkboxIndeterminateIcon = Icons.indeterminate_check_box_rounded,
    this.selectionColumnWidth = 44.0,
    this.expandedIcon = Icons.keyboard_arrow_down_rounded,
    this.collapsedIcon = Icons.keyboard_arrow_right_rounded,
    this.nestingIndent = 20.0,
    this.groupHeaderTextStyle,
    this.sortIconSize = 18.0,
    this.cellIconSize = 16.0,
    this.cellIconGap = 6.0,
    this.focusRingWidth = 2.0,
    this.frozenShadowExtent = 8.0,
    this.headerPadding,
    this.cellPadding,
    this.headerHeight,
    this.rowHeight,
    this.columnMenuIcon = Icons.more_vert_rounded,
    this.filterIcon = Icons.filter_alt_outlined,
    this.filterActiveIcon = Icons.filter_alt_rounded,
    this.rowDragHandleIcon = Icons.drag_indicator,
    this.rangeSelectionBackground,
    this.chartColor,
    this.chartNegativeColor,
    this.detailBackground,
    this.fillHandleSize = 7.0,
    this.rowDragHandleWidth = 32.0,
    this.rowDividerDash,
    this.columnDividerExtent,
    this.headerDividerExtent,
  });

  /// A grid theme derived from the ambient Material theme. This is what a user
  /// who never configures anything gets, so it should look deliberate in both
  /// brightness modes rather than merely legible.
  factory FitGridThemeData.fromTheme(
    ThemeData theme, {
    FitGridDensity density = FitGridDensity.standard,
  }) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final text = theme.textTheme;

    // Dividers read very differently against dark surfaces: the same alpha that
    // looks like a hairline on white looks like a gap on near-black, so the
    // dark variant leans on a lighter colour at lower alpha instead.
    final divider = isDark
        ? scheme.outlineVariant.withValues(alpha: 0.28)
        : scheme.outlineVariant.withValues(alpha: 0.7);

    return FitGridThemeData(
      headerBackground: isDark
          ? Color.alphaBlend(
              scheme.surfaceTint.withValues(alpha: 0.06),
              scheme.surface,
            )
          : scheme.surfaceContainerLow,
      headerForeground: scheme.onSurfaceVariant,
      headerTextStyle: (text.labelLarge ?? const TextStyle(fontSize: 13))
          .copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
      rowBackground: scheme.surface,
      alternateRowBackground: isDark
          ? Color.alphaBlend(
              scheme.onSurface.withValues(alpha: 0.025),
              scheme.surface,
            )
          : scheme.surfaceContainerLowest,
      cellTextStyle: (text.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(color: scheme.onSurface),
      rowDivider: divider,
      columnDivider: divider,
      border: scheme.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.8),
      hoverBackground: scheme.onSurface.withValues(alpha: 0.04),
      selectedBackground: scheme.primary.withValues(
        alpha: isDark ? 0.18 : 0.10,
      ),
      focusOutline: scheme.primary,
      sortIconColor: scheme.onSurfaceVariant,
      placeholderForeground: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      tooltipBackground: scheme.inverseSurface,
      tooltipForeground: scheme.onInverseSurface,
      // A highlight has to survive being painted behind text that was never
      // chosen to contrast with it, so it is a wash rather than a fill.
      searchHighlight: scheme.tertiary.withValues(alpha: isDark ? 0.38 : 0.28),
      frozenShadow: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
      groupHeaderBackground: isDark
          ? Color.alphaBlend(
              scheme.onSurface.withValues(alpha: 0.06),
              scheme.surface,
            )
          : scheme.surfaceContainer,
      density: density,
    );
  }

  final Color headerBackground;
  final Color headerForeground;
  final TextStyle headerTextStyle;

  final Color rowBackground;

  /// Background for odd rows when zebra striping is on. Set equal to
  /// [rowBackground] to turn striping off.
  final Color alternateRowBackground;
  final TextStyle cellTextStyle;

  final Color rowDivider;
  final Color columnDivider;
  final Color border;

  final Color hoverBackground;
  final Color selectedBackground;
  final Color focusOutline;
  final Color sortIconColor;

  /// Foreground for the empty state and loading placeholders.
  final Color placeholderForeground;

  /// Background of the label shown over a cell whose text was truncated. See
  /// [FitGridOverflow.tooltipOnTruncate].
  final Color tooltipBackground;

  /// Text colour of that label.
  final Color tooltipForeground;

  /// Wash painted behind characters matched by the active search.
  final Color searchHighlight;

  /// Colour of the gradient cast by a pinned column band over the content
  /// scrolling beneath it.
  final Color frozenShadow;

  /// Background of a group header row.
  final Color groupHeaderBackground;

  /// Text style for a group header. Null follows [cellTextStyle].
  final TextStyle? groupHeaderTextStyle;

  /// Disclosure glyphs for an open and a closed group or tree node.
  final IconData expandedIcon;
  final IconData collapsedIcon;

  /// How far each level of grouping or nesting indents the first column.
  final double nestingIndent;

  /// Vertical rhythm. Drives the defaults for padding and row height.
  final FitGridDensity density;

  final double dividerThickness;
  final BorderRadius borderRadius;

  /// Visual width of the grip drawn on a column divider.
  final double resizeHandleWidth;

  /// Hit width of the draggable region straddling a column divider.
  ///
  /// Deliberately much wider than [resizeHandleWidth]: the grip only has to be
  /// seen, while the target has to be hit — on a touch screen, by a finger with
  /// no cursor to aim with. The header narrows this for a column too thin to
  /// give up the space, so a wide target never swallows a narrow column's own
  /// tap.
  final double resizeTouchTargetWidth;

  /// Narrowest a resize drag may make a column, whatever the pointer does. A
  /// column dragged to nothing cannot be grabbed again.
  final double minColumnWidth;

  /// How far the alpha ramp reaches back from the edge under
  /// [FitGridOverflow.fade].
  final double fadeExtent;

  /// Widest the truncation tooltip may grow before it wraps.
  final double tooltipMaxWidth;

  final BorderRadius tooltipBorderRadius;

  /// Header affordance for a column sorted ascending.
  final IconData sortAscendingIcon;

  /// Header affordance for a column sorted descending.
  final IconData sortDescendingIcon;

  /// Header affordance for a sortable column that is not currently sorting.
  final IconData sortUnsortedIcon;

  /// Grip drawn on a resizable column divider.
  final IconData resizeGripIcon;

  /// Glyphs for the built-in selection column. They are painted as text, not
  /// built as `Checkbox` widgets, which is what keeps a selectable grid from
  /// putting a widget back into every row.
  final IconData checkboxIcon;
  final IconData checkboxCheckedIcon;
  final IconData checkboxIndeterminateIcon;

  /// Width of the built-in selection column.
  final double selectionColumnWidth;
  final double sortIconSize;

  /// Size of a glyph painted inside a cell by [FitGridColumn.icon].
  final double cellIconSize;

  /// Gap between that glyph and the cell's text.
  final double cellIconGap;

  /// Stroke width of the ring drawn around the keyboard's current cell.
  final double focusRingWidth;

  /// How far the pinned-band shadow reaches over the scrolling content.
  final double frozenShadowExtent;

  /// Overrides for the density-derived defaults. Null means "follow
  /// [density]", which is what the `effective*` getters resolve.
  final EdgeInsets? headerPadding;
  final EdgeInsets? cellPadding;
  final double? headerHeight;
  final double? rowHeight;

  /// Glyph of the button that opens a column's menu.
  final IconData columnMenuIcon;

  /// Glyph for the "Filter…" item of the column menu.
  final IconData filterIcon;

  /// Glyph shown in the header of a column that is being filtered.
  final IconData filterActiveIcon;

  /// Glyph painted in the drag column of a grid with reorderable rows.
  final IconData rowDragHandleIcon;

  /// Wash over a selected range of cells. Null derives one from [focusOutline].
  final Color? rangeSelectionBackground;

  /// Colour of painted bars, sparklines and progress fills. Null follows
  /// [focusOutline].
  final Color? chartColor;

  /// Colour of painted bars for negative values. Null uses a red that holds
  /// up against both light and dark surfaces.
  final Color? chartNegativeColor;

  /// Background behind an expanded detail row. Null follows
  /// [groupHeaderBackground].
  final Color? detailBackground;

  /// Side of the square drag handle at the corner of a selected range.
  final double fillHandleSize;

  /// Width of the drag column added by `FitGrid.reorderableRows`.
  final double rowDragHandleWidth;

  /// Draws the row rules dashed: alternating dash and gap lengths, such as
  /// `[3, 2]`. Null draws them solid.
  final List<double>? rowDividerDash;

  /// Length of the column rules in the body, centred in each row — short
  /// ticks between cells rather than lines down the whole grid. Null draws
  /// them full height. The ticks take [columnDivider]'s colour.
  final double? columnDividerExtent;

  /// Length of the dividers between header cells, centred vertically. Null
  /// draws them full height.
  final double? headerDividerExtent;

  EdgeInsets get effectiveCellPadding =>
      cellPadding ??
      switch (density) {
        FitGridDensity.compact => const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        FitGridDensity.standard => const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        FitGridDensity.comfortable => const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      };

  EdgeInsets get effectiveHeaderPadding =>
      headerPadding ?? effectiveCellPadding;

  double get effectiveRowHeight =>
      rowHeight ??
      switch (density) {
        FitGridDensity.compact => 34.0,
        FitGridDensity.standard => 44.0,
        FitGridDensity.comfortable => 56.0,
      };

  double get effectiveHeaderHeight => headerHeight ?? effectiveRowHeight + 4;

  Color get effectiveRangeSelectionBackground =>
      rangeSelectionBackground ?? focusOutline.withValues(alpha: 0.12);

  Color get effectiveChartColor => chartColor ?? focusOutline;

  Color get effectiveChartNegativeColor =>
      chartNegativeColor ?? const Color(0xFFD64545);

  Color get effectiveDetailBackground =>
      detailBackground ?? groupHeaderBackground;

  FitGridThemeData copyWith({
    Color? headerBackground,
    Color? headerForeground,
    TextStyle? headerTextStyle,
    Color? rowBackground,
    Color? alternateRowBackground,
    TextStyle? cellTextStyle,
    Color? rowDivider,
    Color? columnDivider,
    Color? border,
    Color? hoverBackground,
    Color? selectedBackground,
    Color? focusOutline,
    Color? sortIconColor,
    Color? placeholderForeground,
    Color? tooltipBackground,
    Color? tooltipForeground,
    Color? searchHighlight,
    Color? frozenShadow,
    Color? groupHeaderBackground,
    TextStyle? groupHeaderTextStyle,
    IconData? expandedIcon,
    IconData? collapsedIcon,
    double? nestingIndent,
    FitGridDensity? density,
    double? dividerThickness,
    BorderRadius? borderRadius,
    double? resizeHandleWidth,
    double? resizeTouchTargetWidth,
    double? minColumnWidth,
    double? fadeExtent,
    double? tooltipMaxWidth,
    BorderRadius? tooltipBorderRadius,
    IconData? sortAscendingIcon,
    IconData? sortDescendingIcon,
    IconData? sortUnsortedIcon,
    IconData? resizeGripIcon,
    IconData? checkboxIcon,
    IconData? checkboxCheckedIcon,
    IconData? checkboxIndeterminateIcon,
    double? selectionColumnWidth,
    double? sortIconSize,
    double? cellIconSize,
    double? cellIconGap,
    double? focusRingWidth,
    double? frozenShadowExtent,
    EdgeInsets? headerPadding,
    EdgeInsets? cellPadding,
    double? headerHeight,
    double? rowHeight,
    IconData? columnMenuIcon,
    IconData? filterIcon,
    IconData? filterActiveIcon,
    IconData? rowDragHandleIcon,
    Color? rangeSelectionBackground,
    Color? chartColor,
    Color? chartNegativeColor,
    Color? detailBackground,
    double? fillHandleSize,
    double? rowDragHandleWidth,
    List<double>? rowDividerDash,
    double? columnDividerExtent,
    double? headerDividerExtent,
  }) {
    return FitGridThemeData(
      headerBackground: headerBackground ?? this.headerBackground,
      headerForeground: headerForeground ?? this.headerForeground,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      rowBackground: rowBackground ?? this.rowBackground,
      alternateRowBackground:
          alternateRowBackground ?? this.alternateRowBackground,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      rowDivider: rowDivider ?? this.rowDivider,
      columnDivider: columnDivider ?? this.columnDivider,
      border: border ?? this.border,
      hoverBackground: hoverBackground ?? this.hoverBackground,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      focusOutline: focusOutline ?? this.focusOutline,
      sortIconColor: sortIconColor ?? this.sortIconColor,
      placeholderForeground:
          placeholderForeground ?? this.placeholderForeground,
      tooltipBackground: tooltipBackground ?? this.tooltipBackground,
      tooltipForeground: tooltipForeground ?? this.tooltipForeground,
      searchHighlight: searchHighlight ?? this.searchHighlight,
      frozenShadow: frozenShadow ?? this.frozenShadow,
      groupHeaderBackground:
          groupHeaderBackground ?? this.groupHeaderBackground,
      groupHeaderTextStyle: groupHeaderTextStyle ?? this.groupHeaderTextStyle,
      expandedIcon: expandedIcon ?? this.expandedIcon,
      collapsedIcon: collapsedIcon ?? this.collapsedIcon,
      nestingIndent: nestingIndent ?? this.nestingIndent,
      density: density ?? this.density,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      borderRadius: borderRadius ?? this.borderRadius,
      resizeHandleWidth: resizeHandleWidth ?? this.resizeHandleWidth,
      resizeTouchTargetWidth:
          resizeTouchTargetWidth ?? this.resizeTouchTargetWidth,
      minColumnWidth: minColumnWidth ?? this.minColumnWidth,
      fadeExtent: fadeExtent ?? this.fadeExtent,
      tooltipMaxWidth: tooltipMaxWidth ?? this.tooltipMaxWidth,
      tooltipBorderRadius: tooltipBorderRadius ?? this.tooltipBorderRadius,
      sortAscendingIcon: sortAscendingIcon ?? this.sortAscendingIcon,
      sortDescendingIcon: sortDescendingIcon ?? this.sortDescendingIcon,
      sortUnsortedIcon: sortUnsortedIcon ?? this.sortUnsortedIcon,
      resizeGripIcon: resizeGripIcon ?? this.resizeGripIcon,
      checkboxIcon: checkboxIcon ?? this.checkboxIcon,
      checkboxCheckedIcon: checkboxCheckedIcon ?? this.checkboxCheckedIcon,
      checkboxIndeterminateIcon:
          checkboxIndeterminateIcon ?? this.checkboxIndeterminateIcon,
      selectionColumnWidth: selectionColumnWidth ?? this.selectionColumnWidth,
      sortIconSize: sortIconSize ?? this.sortIconSize,
      cellIconSize: cellIconSize ?? this.cellIconSize,
      cellIconGap: cellIconGap ?? this.cellIconGap,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
      frozenShadowExtent: frozenShadowExtent ?? this.frozenShadowExtent,
      headerPadding: headerPadding ?? this.headerPadding,
      cellPadding: cellPadding ?? this.cellPadding,
      headerHeight: headerHeight ?? this.headerHeight,
      rowHeight: rowHeight ?? this.rowHeight,
      columnMenuIcon: columnMenuIcon ?? this.columnMenuIcon,
      filterIcon: filterIcon ?? this.filterIcon,
      filterActiveIcon: filterActiveIcon ?? this.filterActiveIcon,
      rowDragHandleIcon: rowDragHandleIcon ?? this.rowDragHandleIcon,
      rangeSelectionBackground:
          rangeSelectionBackground ?? this.rangeSelectionBackground,
      chartColor: chartColor ?? this.chartColor,
      chartNegativeColor: chartNegativeColor ?? this.chartNegativeColor,
      detailBackground: detailBackground ?? this.detailBackground,
      fillHandleSize: fillHandleSize ?? this.fillHandleSize,
      rowDragHandleWidth: rowDragHandleWidth ?? this.rowDragHandleWidth,
      rowDividerDash: rowDividerDash ?? this.rowDividerDash,
      columnDividerExtent: columnDividerExtent ?? this.columnDividerExtent,
      headerDividerExtent: headerDividerExtent ?? this.headerDividerExtent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FitGridThemeData &&
        other.headerBackground == headerBackground &&
        other.headerForeground == headerForeground &&
        other.headerTextStyle == headerTextStyle &&
        other.rowBackground == rowBackground &&
        other.alternateRowBackground == alternateRowBackground &&
        other.cellTextStyle == cellTextStyle &&
        other.rowDivider == rowDivider &&
        other.columnDivider == columnDivider &&
        other.border == border &&
        other.hoverBackground == hoverBackground &&
        other.selectedBackground == selectedBackground &&
        other.focusOutline == focusOutline &&
        other.sortIconColor == sortIconColor &&
        other.placeholderForeground == placeholderForeground &&
        other.tooltipBackground == tooltipBackground &&
        other.tooltipForeground == tooltipForeground &&
        other.searchHighlight == searchHighlight &&
        other.frozenShadow == frozenShadow &&
        other.groupHeaderBackground == groupHeaderBackground &&
        other.groupHeaderTextStyle == groupHeaderTextStyle &&
        other.expandedIcon == expandedIcon &&
        other.collapsedIcon == collapsedIcon &&
        other.nestingIndent == nestingIndent &&
        other.cellIconSize == cellIconSize &&
        other.cellIconGap == cellIconGap &&
        other.focusRingWidth == focusRingWidth &&
        other.frozenShadowExtent == frozenShadowExtent &&
        other.density == density &&
        other.dividerThickness == dividerThickness &&
        other.borderRadius == borderRadius &&
        other.resizeHandleWidth == resizeHandleWidth &&
        other.sortIconSize == sortIconSize &&
        other.headerPadding == headerPadding &&
        other.cellPadding == cellPadding &&
        other.headerHeight == headerHeight &&
        other.rowHeight == rowHeight &&
        other.resizeTouchTargetWidth == resizeTouchTargetWidth &&
        other.minColumnWidth == minColumnWidth &&
        other.fadeExtent == fadeExtent &&
        other.tooltipMaxWidth == tooltipMaxWidth &&
        other.tooltipBorderRadius == tooltipBorderRadius &&
        other.sortAscendingIcon == sortAscendingIcon &&
        other.sortDescendingIcon == sortDescendingIcon &&
        other.sortUnsortedIcon == sortUnsortedIcon &&
        other.resizeGripIcon == resizeGripIcon &&
        other.checkboxIcon == checkboxIcon &&
        other.checkboxCheckedIcon == checkboxCheckedIcon &&
        other.checkboxIndeterminateIcon == checkboxIndeterminateIcon &&
        other.selectionColumnWidth == selectionColumnWidth &&
        other.columnMenuIcon == columnMenuIcon &&
        other.filterIcon == filterIcon &&
        other.filterActiveIcon == filterActiveIcon &&
        other.rowDragHandleIcon == rowDragHandleIcon &&
        other.rangeSelectionBackground == rangeSelectionBackground &&
        other.chartColor == chartColor &&
        other.chartNegativeColor == chartNegativeColor &&
        other.detailBackground == detailBackground &&
        other.fillHandleSize == fillHandleSize &&
        other.rowDragHandleWidth == rowDragHandleWidth &&
        listEquals(other.rowDividerDash, rowDividerDash) &&
        other.columnDividerExtent == columnDividerExtent &&
        other.headerDividerExtent == headerDividerExtent;
  }

  @override
  int get hashCode => Object.hashAll([
    headerBackground,
    headerForeground,
    headerTextStyle,
    rowBackground,
    alternateRowBackground,
    cellTextStyle,
    rowDivider,
    columnDivider,
    border,
    hoverBackground,
    selectedBackground,
    focusOutline,
    sortIconColor,
    placeholderForeground,
    tooltipBackground,
    tooltipForeground,
    searchHighlight,
    frozenShadow,
    groupHeaderBackground,
    groupHeaderTextStyle,
    expandedIcon,
    collapsedIcon,
    nestingIndent,
    cellIconSize,
    cellIconGap,
    focusRingWidth,
    frozenShadowExtent,
    density,
    dividerThickness,
    borderRadius,
    resizeHandleWidth,
    sortIconSize,
    headerPadding,
    cellPadding,
    headerHeight,
    rowHeight,
    resizeTouchTargetWidth,
    minColumnWidth,
    fadeExtent,
    tooltipMaxWidth,
    tooltipBorderRadius,
    sortAscendingIcon,
    sortDescendingIcon,
    sortUnsortedIcon,
    resizeGripIcon,
    checkboxIcon,
    checkboxCheckedIcon,
    checkboxIndeterminateIcon,
    selectionColumnWidth,
    columnMenuIcon,
    filterIcon,
    filterActiveIcon,
    rowDragHandleIcon,
    rangeSelectionBackground,
    chartColor,
    chartNegativeColor,
    detailBackground,
    fillHandleSize,
    rowDragHandleWidth,
    if (rowDividerDash != null) Object.hashAll(rowDividerDash!),
    columnDividerExtent,
    headerDividerExtent,
  ]);
}

/// Supplies a [FitGridThemeData] to the grids beneath it.
class FitGridTheme extends InheritedWidget {
  const FitGridTheme({required this.data, required super.child, super.key});

  final FitGridThemeData data;

  /// The nearest grid theme, or one derived from the ambient Material theme
  /// when no [FitGridTheme] is in scope.
  static FitGridThemeData of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<FitGridTheme>();
    return inherited?.data ?? FitGridThemeData.fromTheme(Theme.of(context));
  }

  @override
  bool updateShouldNotify(FitGridTheme oldWidget) => data != oldWidget.data;
}
