# Changelog

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
