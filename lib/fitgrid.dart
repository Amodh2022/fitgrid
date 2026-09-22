/// A Flutter data grid that measures your content instead of making you guess
/// column widths, and paints cells instead of building a widget for each one.
///
/// Start with [FitGrid] and [FitGridColumn]. Column widths come from
/// [FitGridColumnWidth], visuals from [FitGridThemeData], and programmatic
/// control from [FitGridController].
///
/// Cells are painted, not built, which means `find.text` will not see them in
/// widget tests. Use `package:fitgrid/testing.dart` for that.
library;

export 'src/controller/fitgrid_controller.dart'
    show
        FitGridColumnState,
        FitGridController,
        FitGridDataState,
        FitGridSelectionState;
export 'src/model/column_width.dart'
    show
        FitGridAutoWidth,
        FitGridColumnWidth,
        FitGridFitHeaderWidth,
        FitGridFixedWidth,
        FitGridFlexWidth;
export 'src/model/enums.dart'
    show
        FitGridAlignment,
        FitGridDensity,
        FitGridFreeze,
        FitGridOverflow,
        FitGridSortDirection;
export 'src/model/fitgrid_column.dart'
    show FitGridCellBuilder, FitGridCellStyle, FitGridCellValue, FitGridColumn;
export 'src/model/row_height.dart'
    show FitGridContentRowHeight, FitGridFixedRowHeight, FitGridRowHeight;
export 'src/sizing/column_layout.dart' show FitGridColumnLayout;
export 'src/theme/fitgrid_theme.dart' show FitGridTheme, FitGridThemeData;
export 'src/widgets/fitgrid.dart' show FitGrid;
