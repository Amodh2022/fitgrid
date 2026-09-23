# Changelog

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
- **Context menus** and a painted row hover.

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

- **`flutter_test` is no longer a runtime dependency.** It was one because
  `testing.dart` took a `WidgetTester`; the helpers now find the grid themselves.
  They no longer take a `tester` argument, and `expectFitGridCell` /
  `expectFitGridRow` are gone — use your own `expect` on `fitGridCellText` and
  `fitGridRowText`.
- **Published benchmarks** in `benchmark/`, and golden tests covering light,
  dark, densities, all four overflow policies, RTL, frozen columns, grouping and
  search highlighting.

### Breaking

- `FitGrid.selectionMode` is nullable and defaults to null, meaning "leave the
  controller alone". Previously a default was pushed onto a caller-supplied
  controller and silently cleared any selection set before the first build.
- `FitGridCellStyle`, and the new `FitGridCellIcon` / `FitGridCellIconColor`,
  receive the row's index into the **full** row list rather than into the page.
- `package:fitgrid/testing.dart` helpers no longer take a `WidgetTester`.
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
- `package:fitgrid/testing.dart` for asserting on painted cells
