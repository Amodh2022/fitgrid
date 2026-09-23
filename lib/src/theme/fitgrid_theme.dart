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
    this.sortIconSize = 18.0,
    this.cellIconSize = 16.0,
    this.cellIconGap = 6.0,
    this.focusRingWidth = 2.0,
    this.frozenShadowExtent = 8.0,
    this.headerPadding,
    this.cellPadding,
    this.headerHeight,
    this.rowHeight,
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
    double? sortIconSize,
    double? cellIconSize,
    double? cellIconGap,
    double? focusRingWidth,
    double? frozenShadowExtent,
    EdgeInsets? headerPadding,
    EdgeInsets? cellPadding,
    double? headerHeight,
    double? rowHeight,
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
      sortIconSize: sortIconSize ?? this.sortIconSize,
      cellIconSize: cellIconSize ?? this.cellIconSize,
      cellIconGap: cellIconGap ?? this.cellIconGap,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
      frozenShadowExtent: frozenShadowExtent ?? this.frozenShadowExtent,
      headerPadding: headerPadding ?? this.headerPadding,
      cellPadding: cellPadding ?? this.cellPadding,
      headerHeight: headerHeight ?? this.headerHeight,
      rowHeight: rowHeight ?? this.rowHeight,
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
        other.resizeGripIcon == resizeGripIcon;
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
