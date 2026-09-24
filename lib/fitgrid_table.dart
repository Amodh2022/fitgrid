/// A Flutter data grid that measures your content instead of making you guess
/// column widths, and paints cells instead of building a widget for each one.
///
/// Start with [FitGrid] and [FitGridColumn]. Column widths come from
/// [FitGridColumnWidth], visuals from [FitGridThemeData], and programmatic
/// control from [FitGridController].
///
/// Cells are painted, not built, which means `find.text` will not see them in
/// widget tests. Use `package:fitgrid_table/testing.dart` for that — it has no
/// dependency on the test framework, so it costs applications nothing.
library;

export 'src/controller/fitgrid_controller.dart'
    show
        FitGridColumnState,
        FitGridController,
        FitGridDataState,
        FitGridSelectionState;
export 'src/controller/fitgrid_details.dart' show FitGridDetailState;
export 'src/controller/fitgrid_editing.dart' show FitGridEditingState;
export 'src/controller/fitgrid_filter.dart' show FitGridFilterState;
export 'src/controller/fitgrid_focus.dart' show FitGridFocusState;
export 'src/controller/fitgrid_grouping.dart' show FitGridGroupingState;
export 'src/controller/fitgrid_history.dart'
    show FitGridCellChange, FitGridEditHistory;
export 'src/controller/fitgrid_pagination.dart' show FitGridPaginationState;
export 'src/controller/fitgrid_saved_state.dart' show FitGridSavedState;
export 'src/controller/fitgrid_range.dart'
    show FitGridCellRange, FitGridCellRangeState;
export 'src/model/cell_visual.dart'
    show
        FitGridBarVisual,
        FitGridCellVisual,
        FitGridProgressVisual,
        FitGridSparklineVisual;
export 'src/model/column_filter.dart'
    show
        FitGridColumnFilter,
        FitGridFilterKind,
        FitGridFilterOperator,
        FitGridFilterSpec;
export 'src/model/column_group.dart' show FitGridColumnGroup;
export 'src/model/column_width.dart'
    show
        FitGridAutoWidth,
        FitGridColumnWidth,
        FitGridFitHeaderWidth,
        FitGridFixedWidth,
        FitGridFlexWidth;
export 'src/export/fitgrid_export.dart'
    show
        FitGridExportData,
        FitGridExportRow,
        buildFitGridExport,
        fitGridParseDelimited,
        fitGridToCsv,
        fitGridToDelimited,
        fitGridToTsv;
export 'src/export/fitgrid_xlsx.dart' show fitGridToXlsx;
export 'src/model/data_source.dart'
    show
        FitGridAsyncDataSource,
        FitGridDataSource,
        FitGridPageRequest,
        FitGridPageResult;
export 'src/model/enums.dart'
    show
        FitGridAlignment,
        FitGridDensity,
        FitGridFreeze,
        FitGridOverflow,
        FitGridSelectionMode,
        FitGridSortDirection;
export 'src/model/fill_series.dart' show fitGridFillSeries;
export 'src/model/fitgrid_editor.dart'
    show
        FitGridCellCommit,
        FitGridCellEdit,
        FitGridCellValidator,
        FitGridEditTrigger,
        FitGridEditor,
        FitGridEditorBuilder,
        FitGridEditorSession;
export 'src/model/page_view.dart' show FitGridPageView;
export 'src/model/fitgrid_column.dart'
    show
        FitGridAggregate,
        FitGridCellBuilder,
        FitGridCellIcon,
        FitGridCellIconColor,
        FitGridCellStyle,
        FitGridCellValue,
        FitGridColumn,
        FitGridRowPredicate;
export 'src/model/row_model.dart'
    show
        FitGridDisplayRow,
        FitGridGroup,
        FitGridTree,
        flattenGroups,
        flattenTree,
        insertDetails;
export 'src/model/rows_view.dart' show FitGridRowsView;
export 'src/model/pivot.dart'
    show
        FitGridAggregation,
        FitGridPivotDimension,
        FitGridPivotResult,
        FitGridPivotRow,
        FitGridPivotValue,
        fitGridPivot;
export 'src/model/sort_key.dart' show FitGridSortKey;
export 'src/model/row_height.dart'
    show FitGridContentRowHeight, FitGridFixedRowHeight, FitGridRowHeight;
export 'src/sizing/column_layout.dart' show FitGridColumnLayout;
export 'src/sizing/row_metrics.dart'
    show FitGridMeasuredRowMetrics, FitGridRowMetrics, FitGridUniformRowMetrics;
export 'src/theme/fitgrid_theme.dart' show FitGridTheme, FitGridThemeData;
export 'src/widgets/fitgrid.dart' show FitGrid, FitGridContextMenuTarget;
export 'src/widgets/fitgrid_column_chooser.dart'
    show
        FitGridColumnChooser,
        fitGridColumnChooserItems,
        showFitGridColumnDialog;
export 'src/widgets/fitgrid_filter_dialog.dart' show showFitGridFilterDialog;
export 'src/widgets/fitgrid_footer.dart' show FitGridFooter;
export 'src/widgets/fitgrid_header.dart' show FitGridHeader;
export 'src/widgets/fitgrid_intents.dart'
    show
        FitGridActivateIntent,
        FitGridClearCellsIntent,
        FitGridCopyIntent,
        FitGridDismissIntent,
        FitGridJumpIntent,
        FitGridMoveIntent,
        FitGridMoveRowIntent,
        FitGridPageIntent,
        FitGridPasteIntent,
        FitGridRedoIntent,
        FitGridSelectAllIntent,
        FitGridToggleSelectionIntent,
        FitGridUndoIntent,
        kFitGridShortcuts;
export 'src/widgets/fitgrid_pager.dart' show FitGridPageLabel, FitGridPager;
