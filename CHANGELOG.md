# Changelog

## 0.1.0

The release that turns a fast table into a grid people can work in. Every
feature below is opt-in or invisible until used: an existing grid looks and
behaves as it did, and the package still has no dependency beyond Flutter.

### Sorting, columns and filters

- **Multi-column sort.** Shift+click adds a column to the sort; sorted headers
  show their priority. `FitGridController.setSort` / `clearSort`,
  `toggleSort(additive:)`, `FitGridSortKey`, and a stable multi-key sort. Data
  sources get `sortByKeys` and `FitGridPageRequest.sortKeys`, defaulting to the
  primary key so existing sources keep working. `FitGrid.multiSort` turns the
  gesture off.
- **Column menu.** `FitGrid.showColumnMenu` puts a menu on every header: sort,
  filter, pin to either edge, size to fit, hide, and the column chooser.
  `columnMenuBuilder` edits it.
- **Column chooser.** `FitGridColumnChooser`, `showFitGridColumnDialog` and
  `fitGridColumnChooserItems`. `FitGridColumn.hideable`; the column state gains
  `showAll` and `setFreeze`.
- **Filter UI.** `FitGridColumn.filter` with `FitGridFilterSpec.text`,
  `.number`, `.date` or `.values` (a searchable checklist). Filters are data —
  `FitGridColumnFilter`, JSON round-trippable — held in
  `FitGridFilterState.filters`, shown as a header glyph, and forwarded to data
  sources through `filterBy` and `FitGridPageRequest.filters`.
- **Header bands.** `FitGrid.columnGroups` with `FitGridColumnGroup`.
- **Saved layouts.** `controller.saveState()` / `restoreState()` with
  `FitGridSavedState`: order, visibility, pins, widths, sort, filters, search
  and page.

### Cells

- **Range selection.** `FitGrid.cellSelection`: mouse drag with edge
  auto-scroll, Shift+click, Shift+arrows. Ranges copy as blocks, and live on
  `FitGridController.range`.
- **Paste and clear.** Ctrl+V pastes a block, or fills a range with one value;
  Delete/Backspace clears. Every value goes through the column's validator and
  commit. `fitGridParseDelimited`, `FitGridCellEdit`.
- **Fill handle.** Drag the range's corner to continue series or repeat values
  — `fitGridFillSeries`.
- **Undo and redo.** Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y over typed edits, pastes,
  clears and fills; `controller.undo()` / `redo()` and
  `FitGridController.history`. `FitGrid.enableUndo`.
- **Charts in cells.** `FitGridColumn.visual` with `FitGridCellVisual.bar`,
  `.progress` and `.sparkline`, painted by the text pass.

### Rows

- **Detail rows.** `FitGrid.detailBuilder` opens a full-width panel under a row
  from a chevron column; panels follow their row by `FitGrid.rowKey` and compose
  with grouping, trees and pagination. `FitGridController.details`.
- **Sticky group headers**, stacked and pushed away by the next group. On by
  default (`FitGrid.stickyGroupHeaders`); a grid at rest is unchanged.
- **Row reordering.** `FitGrid.reorderableRows` with drag handles and
  Alt+Up/Down; `onRowReorder` for hosts that own their list.
- **Infinite scroll.** `FitGrid.onLoadMore`, `hasMoreRows`,
  `loadMoreThreshold`, `loadingRowCount`, with skeleton rows while loading.
  Rows a data source has not delivered now paint as skeletons too.

### Export and analysis

- **xlsx export.** `fitGridToXlsx` writes a workbook in pure Dart — no new
  dependency, and it runs on the web.
- **Pivots.** `fitGridPivot` with `FitGridPivotDimension`,
  `FitGridPivotValue` and `FitGridAggregation` produces an ordinary grid's rows
  and columns, with grand totals reduced from the source rows.

### Theming

- `FitGridThemeData.rowDividerDash` draws row rules dashed;
  `columnDividerExtent` and `headerDividerExtent` draw column dividers as short
  centred ticks in the body and the header. All off by default.

### Fixes

- Keys typed into an open editor no longer reach the grid: Space used to toggle
  the row's selection and the arrow keys moved the grid's focus. Grid shortcuts
  now act only while the grid itself holds focus.
- Each cell's spec is resolved once per paint rather than twice.
- Footer totals are no longer cut off: columns size to fit their footer total
  as well as their header and cells, and the footer lays its label and value
  out as one line instead of giving each half the room.

### Other

- The minimum Flutter version is now stated correctly as 3.35 (Dart 3.9), which
  the package already required.
- Agents working with the package can install its skill with
  `dart run skills@ get` — see `skills/`.
- The example gallery gains six pages: spreadsheet editing; columns, filters
  and saved layouts; pivot and export; detail rows with nested grids; infinite
  scroll against a slow, failing feed; reorderable rows; and charts in cells.

## 0.1.0-dev

The release that closes the gaps between "interesting approach" and "you could
ship this".

### Accessibility

- **Painted cells now reach the accessibility tree.** The render object
  assembles its own: a `table` node holding one `row` per visible row and one
  `cell` per visible cell, recycled across updates and bounded by the window, so
  a screen reader sees a real table while the cost still tracks the viewport.
  This was the structural objection to painting rather than building, and it is
  answered in the render layer rather than left to the caller.
- `FitGridColumn.semanticValue` says something different from the painted text
  when the painted text is written for the eye.
- Headers announce as headers, and a selected row announces as selected.

### Frozen columns

- `FitGridColumn.freeze` does what it always claimed to. Pinned columns are
  pulled to the edges whatever order they were declared in, and the header, the
  body and the footer share one band geometry rather than three that drift.
- All horizontal placement now goes through a single leading-edge function,
  which makes RTL one mirror instead of a special case in painting, hit testing,
  semantics and overlay placement.

### Selection and keyboard

- `FitGridSelectionMode`, a selection anchor, and the replace / toggle / extend
  gestures every desktop table has.
- `FitGrid.showSelectionColumn` adds a pinned checkbox column — painted as a
  glyph, so a selectable grid does not put a widget back into every row — with a
  tri-state select-all box in the header.
- A focus model with a focused *cell*: arrows, Home/End, Ctrl+Home/End,
  Page Up/Down, Space, Enter, Ctrl+A, Escape, and Ctrl+C copying as TSV. Tab is
  deliberately unbound: a widget a keyboard user cannot leave is worse than one
  they cannot enter.
- `FitGridController.scrollTo` brings a row, and optionally a column, into view —
  turning the page first when paginated, and never behind a pinned column.

### Data

- **Filtering and search** in their own notifier, so a keystroke re-derives the
  row view without re-measuring a column. Matches are highlighted from the
  painter that has already been laid out, which costs a rectangle rather than a
  rebuilt span tree.
- **Data sources**: `FitGridDataSource` and `FitGridAsyncDataSource` for rows the
  grid does not hold, fetched a page at a time behind a bounded cache. Sorting
  and filtering are forwarded rather than applied to a window.
- **Grouping and tree rows**, which flatten to the same list of display lines, so
  neither gets its own path through the renderer, the hit tests or the
  semantics. Collapsing never renumbers the rows below it.
- **Merged cells** underneath both: a span resolver lets one cell cover several
  columns, across a pinned boundary if it has to.
- **Aggregate footer** via `FitGridColumn.aggregate`, computed over the rows on
  screen — filter included, because a total the user cannot add up themselves is
  a total they are right not to trust.
- **Export**: `FitGridExportData`, `fitGridToCsv`, `fitGridToTsv`. Rows, not
  files — see the type's docs for why the format writers are not in here.
- **Column reordering** by dragging a header, opt-in through
  `FitGrid.reorderableColumns`.
- **Context menus**, a painted row hover, and `FitGrid.rowColor` for conditional
  formatting that costs a `drawRect` per row rather than a `Container`.
- **Widget cells.** `FitGridColumn.cellBuilder` now renders: real widgets in
  cells, built during layout for the rows on screen and dropped as they scroll
  away, as a sliver list does. They are clipped to their band beneath pinned
  columns and hit-tested within it. A widget that handles its own taps keeps
  them rather than also selecting the row. Overlay children, the editor
  included, are now clipped to their band as well.
- A data source that starts with no known rows now loads. With the default
  `initialRowCount: 0` the grid had nothing to lay out, so nothing reported a
  window and the first page was never requested. A search, which resets the
  count, stranded the grid the same way.
- `FitGridAsyncDataSource.dispose` drops fetches still in flight, instead of
  notifying from a disposed source when the answer lands after the screen that
  owned it has gone.

### Performance

- Painters are keyed by **what they contain** rather than by where they are, so a
  column of four hundred rows reading "Active" lays that word out once, and a
  scroll reuses what it is scrolling over.
- `FitGridOverflow.fade` no longer opens a `saveLayer` per truncated cell per
  frame. The ramp is painted into the glyphs through a gradient foreground.
- `measureAllRows` is rationed to a budget per pass and resumed on the next
  build, so a large table gets a first frame. Widths only grow towards the truth.
- Cached `visible` columns, so a scroll frame stops rebuilding the list.

### Packaging

- Published on pub.dev as **`fitgrid_table`**. Import
  `package:fitgrid_table/fitgrid_table.dart`, and `package:fitgrid_table/testing.dart`
  for the test helpers.
- **`flutter_test` is no longer a runtime dependency.** It was one because
  `testing.dart` took a `WidgetTester`; the helpers now find the grid themselves.
  They no longer take a `tester` argument, and `expectFitGridCell` /
  `expectFitGridRow` are gone — use your own `expect` on `fitGridCellText` and
  `fitGridRowText`.
- **Published benchmarks** in `benchmark/`, and golden tests covering light,
  dark, densities, all four overflow policies, RTL, frozen columns, grouping and
  search highlighting.

### Example

- The example app is now a gallery: two unrelated designs over the same data,
  pagination three ways, conditional formatting, sizing with live frame timings,
  lazy loading against a fake server, controller patterns with a rebuild
  counter, grouping and tree rows, and the full playground. Each page explains
  what to copy and what to avoid.

### Breaking

- `FitGrid.selectionMode` is nullable and defaults to null, meaning "leave the
  controller alone". Previously a default was pushed onto a caller-supplied
  controller and silently cleared any selection set before the first build.
- `FitGridCellStyle`, and the new `FitGridCellIcon` / `FitGridCellIconColor`,
  receive the row's index into the **full** row list rather than into the page.
- `package:fitgrid_table/testing.dart` helpers no longer take a `WidgetTester`.
- `FitGridRowSizer.resolve` takes a `FitGridRowsView` rather than a `List`.

## 0.0.1-dev

Foundation release. Not published.

- `FitGrid` with content-measured column widths (`auto`, `fixed`, `flex`,
  `fitHeader`, each with min/max clamps)
- Content-measured row heights (`FitGridRowHeight.contentSized`) paired with
  `FitGridColumn.maxLines` for wrapping cells; row geometry lives in
  `FitGridRowMetrics`, arithmetic when rows share a height and a prefix-sum
  binary search when they do not
- Interactive column resizing: a grip on every resizable divider, drag it to
  set a width,
  double-click it to re-fit. Clamped by the column's own policy, mirrored for
  RTL, and available programmatically as `FitGridColumnState.setWidth` /
  `autoSize` / `autoSizeAll`
- Cell text is capped to the lines its row can afford, and clipped to its own
  box if it still does not fit, so a wrapped or clamped cell can no longer paint
  over its neighbours
- All four `FitGridOverflow` policies implemented: `fade` cuts an alpha ramp out
  of the glyphs so it reveals the real background, and `tooltipOnTruncate` shows
  a label on exactly the cells that lost text, using truncation the renderer had
  already recorded
- Pagination with no dependency and no copying: `FitGridPageView` is a read-only
  window onto the row list, widths are still measured against the whole dataset
  so columns do not jump between pages, and row indices stay global so selection
  survives paging. Built-in `FitGridPager`, or replace it with `pagerBuilder`
- Inline editing via `FitGridColumn.editor`: one editor widget exists, and only
  while a cell is open, as an overlay child of the painted section. Validation,
  Enter/Escape/Tab, commit-or-discard on focus loss, custom editor builders, and
  row indices that stay global under sorting and pagination
- Painted text cells via `RenderFitGridSection`, with pruned `TextPainter`
  caching and batched rule drawing
- Row windowing driven by the viewport, so layout cost tracks the screen rather
  than the dataset
- `FitGridController` — data, column and selection state as separate
  `ChangeNotifier`s
- `FitGridThemeData`, derivable from `ThemeData`, with three densities
- Right-to-left support in measurement, layout and paint
- `package:fitgrid_table/testing.dart` for asserting on painted cells
