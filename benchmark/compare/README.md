# Sort benchmark: fitgrid vs other Flutter grids

The same rows, viewport, sorts and measurements for fitgrid, Syncfusion
DataGrid, TrinaGrid and PlutoGrid. TrinaGrid is the maintained fork of
PlutoGrid; PlutoGrid is included for anyone still using it.

This is a package of its own so the other grids never become dependencies of
`fitgrid_table`, and it is left out of the published package.

```
cd benchmark/compare
tool/run.sh                                  # 100k and 1M rows, every grid
ROWS="20000" GRIDS="fitgrid trina" tool/run.sh   # a quick subset
```

Each grid × size runs in its own process, so peak memory is that grid's
alone. `tool/combine.dart` turns the output into one markdown table per size.

## What is measured

- **Build the row model**: the app's cost of handing the grid its rows in the
  shape it wants (`DataGridRow`, `TrinaRow`, `PlutoRow`; fitgrid takes the
  objects as they are).
- **Mount + first frame**, and **scroll one viewport**.
- **Sort by text, number and date**, 3 runs each:
  - *longest UI stall*: the longest the UI thread went without returning to
    the event loop during the sort. A sort on the UI thread shows its whole
    duration here; over 16 ms is a dropped frame at 60 Hz.
  - *until sorted*: request to model in the new order.
  - *frame*: the frame that shows it.
- **Memory**: the row model, mounting, and peak RSS.
- **Same order**: the first 20 rows' sort keys are compared across grids, so
  every grid is shown to produce the same result. Keys rather than ids,
  because tied rows may come out in any order in a sort that is not stable.

## Fairness

Every grid is set up the way its documentation shows: typed cell values
(`int`, `DateTime`, `String`) for Syncfusion, so its default compare calls
`compareTo` directly; Trina's and Pluto's own `number` and `date` column
types; `sortValue` for fitgrid's number and date columns. Sorts are triggered
through each grid's public API (`DataGridSource.sort`,
`TrinaGridStateManager.sortAscending`, `FitGridController.setSort`).

Under 50,000 rows fitgrid sorts on the UI thread like the others; from 50,000
it sorts on a background isolate.

Numbers come from `flutter test` in debug mode, headless, the same for every
grid. Absolute times are higher than a profile or release build on a device.
