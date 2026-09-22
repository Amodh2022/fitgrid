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
    this.density = FitGridDensity.standard,
    this.dividerThickness = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.resizeHandleWidth = 8.0,
    this.sortIconSize = 18.0,
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

  /// Vertical rhythm. Drives the defaults for padding and row height.
  final FitGridDensity density;

  final double dividerThickness;
  final BorderRadius borderRadius;

  /// Hit width of the draggable region straddling a column divider.
  final double resizeHandleWidth;
  final double sortIconSize;

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
    FitGridDensity? density,
    double? dividerThickness,
    BorderRadius? borderRadius,
    double? resizeHandleWidth,
    double? sortIconSize,
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
      density: density ?? this.density,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      borderRadius: borderRadius ?? this.borderRadius,
      resizeHandleWidth: resizeHandleWidth ?? this.resizeHandleWidth,
      sortIconSize: sortIconSize ?? this.sortIconSize,
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
        other.density == density &&
        other.dividerThickness == dividerThickness &&
        other.borderRadius == borderRadius &&
        other.resizeHandleWidth == resizeHandleWidth &&
        other.sortIconSize == sortIconSize &&
        other.headerPadding == headerPadding &&
        other.cellPadding == cellPadding &&
        other.headerHeight == headerHeight &&
        other.rowHeight == rowHeight;
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
    density,
    dividerThickness,
    borderRadius,
    resizeHandleWidth,
    sortIconSize,
    headerPadding,
    cellPadding,
    headerHeight,
    rowHeight,
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
