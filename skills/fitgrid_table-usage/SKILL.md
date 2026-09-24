---
name: fitgrid_table-usage
description: >-
  Use when writing, reviewing, styling or testing Flutter code that uses the
  fitgrid_table package (FitGrid, FitGridColumn, FitGridController,
  FitGridThemeData) — data grids with sorting, filtering, editing, selection,
  ranges, grouping, detail rows, theming, export, pivots or server-backed rows
  — to follow its patterns and avoid its pitfalls.
---

# fitgrid_table

`FitGrid<T>` is a data grid that measures column widths from content and
**paints** cells rather than building a widget per cell. Most mistakes come
from treating it like a widget-per-cell table.

## Core concepts

1. **Cells are painted.** A block of cells is one render object, not widgets.
   Colours, glyphs, highlights and charts are *values* the paint pass reads.
   `find.text` cannot see a cell. `cellBuilder` builds real widgets only where
   asked, for visible rows only.
2. **Columns are typed and keyed by `id`.** `value: (row) => String` reads the
   model; the `id` keys widths, sort, filters, focus, saved layouts.
3. **The controller is a cluster of `ChangeNotifier`s**: `data`, `columns`,
   `selection`, `focus`, `filter`, `grouping`, `pagination`, `range`,
   `details`, `editing`, `history`. Each changes independently.
4. **Indices are into the rows as displayed** — filtered and sorted, never the
   page. Under a sort they are not indices into the source list.
5. **The grid never writes to rows.** Edits, pastes, fills and undo come back
   through `FitGridEditor.onCommit`; the host updates its data and hands it
   back.

## Guidelines

### Rows and columns

- Give every `FitGridColumn` a **stable, unique `id`**. Never the display
  index; never starting with `__fitgrid` (reserved for built-in columns).
- **Keep the rows list's identity stable.** Caches key on it: pass the same
  `List` between builds and replace it only when the data changes. A new list
  each `build` re-measures every column every frame.
- Give numeric and date columns a `comparator` (the default compares painted
  text: "10" before "9") and a `copyValue` when the text is formatted
  (`$72,000` → `72000`) so copy and export stay usable.
- Widget cells (`cellBuilder`) and charts (`visual`) are not measured: use
  `FitGridColumnWidth.fixed(...)`.
- Wrapping needs three things: `maxLines` on the column,
  `rowHeight: FitGridRowHeight.contentSized()` on the grid, and a width that
  constrains the text (`fixed`, or `auto` with a `max`).
- Set `rowKey` when rows are recreated as new objects on every change. Detail
  panels and undo find rows by it; the default key is the row object itself.
- A column whose `value` reads `controller.data.view` (a serial number, a
  rank) must be `searchable: false`: the search builds the view, so a
  searchable column that reads it recurses.

### State and the controller

- Without a `controller`, the grid owns one and syncs from `rows`/`columns`.
  With one, **those arguments are ignored** — update `controller.data.rows` and
  `controller.columns.columns`.
- **Whoever constructs a controller disposes it**, as with `ScrollController`.
- Listen to the one notifier you need (`controller.history`,
  `controller.range`, …) with `ListenableBuilder`; do not rebuild the grid
  from outside to reflect its own state.

### Theming

- All visuals live in one `FitGridThemeData`. Resolution order: `FitGrid.theme`,
  then the nearest `FitGridTheme` ancestor, then
  `FitGridThemeData.fromTheme(Theme.of(context))`. With nothing set, the grid
  follows the app's `ColorScheme`, text theme and brightness.
- Customise with `FitGridThemeData.fromTheme(Theme.of(context)).copyWith(...)`;
  build it when the theme changes, not per frame (it is a cache key).
- Fonts go in `headerTextStyle` and `cellTextStyle`; widths and row heights
  are measured in them.
- Density (`compact` 34 / `standard` 44 / `comfortable` 56 row height) is
  `fromTheme(theme, density: ...)`; `rowHeight`, `headerHeight`,
  `cellPadding`, `headerPadding` override it.
- Divider shapes: `rowDividerDash: [3, 2]` (dashed rows),
  `columnDividerExtent: 12` (short ticks between cells, in `columnDivider`),
  `headerDividerExtent: 34` (short header dividers). All null = full lines.
- Data-driven colour is not the theme's job: use `rowColor`, `cellStyle`,
  `icon`/`iconColor`. Selection wins over `rowColor`.
- A design system's own footer goes in `pagerBuilder`, which receives
  `FitGridPaginationState` and renders inside the grid's border.
- Full colour mapping and every property: [references/theming.md](references/theming.md).

### Editing, ranges and undo

- `onCommit(row, index, value)` must update the host's data and push it back.
  Update by the row's id, not by `index`, whenever the grid can be sorted.
- `initialText` makes the editor (and paste, fill, undo) work in raw values;
  `validator` guards typed edits, paste and fill alike.
- `cellSelection: true` enables block selection, block copy, paste, Delete and
  the fill handle; only columns with an `editor` receive values.
- Undo (`controller.undo()`/`redo()`, Ctrl+Z/Ctrl+Shift+Z/Ctrl+Y) replays
  through `onCommit`. Turn off with `enableUndo: false`.

### Server-backed rows

- With a `FitGridDataSource` the grid **does not sort or filter**; it forwards
  `sortByKeys` and `filterBy`, and the host calls `source.search(query)`.
  `FitGridAsyncDataSource` covers the common case; its `FitGridPageRequest`
  carries `sortKeys`, `filters` (JSON) and `query`.
- A data source cannot be combined with `paginated`, `onLoadMore`,
  `detailBuilder`, `reorderableRows` or undo. For "append the next page to an
  in-memory list", use `onLoadMore`.

### Keyboard

- Shortcuts act only while the grid itself holds focus (`autofocus: true`, or a
  tapped cell); keys in an open editor or a widget cell go there.
- Arrows / Tab move cells; Shift+arrows extend; Home/End, Ctrl+Home/End jump;
  Space toggles a row; Enter edits or opens a detail panel; Ctrl+A/C/V; Delete
  clears a range; Ctrl+Z/Y; Alt+Up/Down moves a row; Escape backs out. Rebind
  by intent through a `Shortcuts` ancestor (`kFitGridShortcuts`).

### Testing

- **`find.text` never finds a cell.** Import
  `package:fitgrid_table/testing.dart`: `fitGridCellText(row:, column:)`,
  `fitGridRowText`, `fitGridCellSpec`, `fitGridRowCount`, `fitGridColumnIds`,
  `fitGridSection()`. Header labels are widgets, so `find.text` works for
  headers only.
- On a grid with editable columns a single tap waits out the double-tap
  window: `await tester.pump(const Duration(milliseconds: 400))` after `tapAt`.

## Gotchas

| Symptom | Cause |
|---|---|
| Edits change nothing | `onCommit` did not update the data and push it back. |
| Edit lands on the wrong row after sorting | Wrote by `index`; find the row by id. |
| Panels/undo lose their row after a refresh | Rows are new objects; set `rowKey`. |
| Numbers sort as text | Missing `comparator`. |
| Widget or chart column too narrow | Needs a `fixed` width. |
| Nothing wraps | Missing `contentSized()` or a constraining width. |
| `rows:` changes ignored | A controller is supplied; update the controller. |
| Stack overflow when searching | A searchable column reads `data.view`. |
| Shortcut does nothing | The grid does not have focus. |

## Examples

A typed grid with a controller and a theme:

```dart
late final controller = FitGridController<Employee>(
  rows: employees,
  columns: [
    FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name, sortable: true,
        filter: const FitGridFilterSpec.text()),
    FitGridColumn(
      id: 'salary',
      label: 'Salary',
      value: (e) => money(e.salary),
      copyValue: (e) => '${e.salary}',
      comparator: (a, b) => a.salary.compareTo(b.salary),
      alignment: FitGridAlignment.end,
      sortable: true,
      filter: FitGridFilterSpec.number((e) => e.salary),
    ),
  ],
);

@override
void dispose() {
  controller.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) => FitGrid<Employee>(
  controller: controller,
  selectionMode: FitGridSelectionMode.multiple,
  showColumnMenu: true,
  theme: FitGridThemeData.fromTheme(Theme.of(context)).copyWith(
    headerBackground: const Color(0xFF0F172A),
    headerTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    borderRadius: BorderRadius.circular(8),
  ),
);
```

An editable column whose commit writes back by id:

```dart
FitGridColumn<Employee>(
  id: 'name',
  label: 'Name',
  value: (e) => e.name,
  editor: FitGridEditor(
    validator: (row, v) => v.trim().isEmpty ? 'Required' : null,
    onCommit: (row, index, value) {
      employees = [
        for (final e in employees) e.id == row.id ? e.copyWith(name: value) : e,
      ];
      controller.data.rows = employees;
    },
  ),
)
```

A widget test:

```dart
import 'package:fitgrid_table/testing.dart';

await tester.pumpWidget(app);
expect(fitGridCellText(row: 0, column: 0), 'Amit');
controller.toggleSort('salary');
await tester.pump();
expect(fitGridRowText(0).last, '\$50,000');
```

## More

- [references/theming.md](references/theming.md) — theme resolution, the
  `ColorScheme` mapping in light and dark, every `FitGridThemeData` property,
  and styling recipes.
- [references/recipes.md](references/recipes.md) — widths, row heights,
  sorting, filters, column menu, selection, editing, ranges, grouping, detail
  rows, reordering, pagination, infinite scroll, data sources, export, pivots,
  saved layouts, charts and the controller API.
