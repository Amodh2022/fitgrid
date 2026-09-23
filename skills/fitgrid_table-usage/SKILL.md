---
name: fitgrid_table-usage
description: >-
  Use when writing, reviewing or testing Flutter code that uses the
  fitgrid_table package (FitGrid, FitGridColumn, FitGridController) — data
  grids with sorting, filtering, editing, selection, grouping, export or
  server-backed rows — to follow its patterns and avoid its pitfalls.
---

# fitgrid_table

`FitGrid<T>` is a data grid that measures column widths from content and
**paints** cells rather than building a widget per cell. Most mistakes come
from treating it like a widget-per-cell table.

## Guidelines

### Rows and columns

- Give every `FitGridColumn` a **stable, unique `id`**. Ids key widths, sort,
  filters, focus, saved state and detail panels. Never use the display index,
  and never start an id with `__fitgrid` (reserved for built-in columns).
- **Keep the rows list's identity stable.** Caches are keyed on identity: pass
  the same `List` between builds and replace it only when the data changes.
  Building a new list in every `build` re-measures every column every frame.
- Set `rowKey` when rows are recreated on every change (immutable models,
  fresh objects from an API). It is how detail panels and undo find a row
  again. The default key is the row object itself.
- Numeric and date columns need a `comparator`: the default compares the
  painted text, which sorts "10" before "9". Add a `copyValue` when the painted
  text is formatted (`$72,000` → `72000`) so copy and export stay usable.
- Widget cells (`cellBuilder`) and charts (`visual`) are not measured: give
  those columns `FitGridColumnWidth.fixed(...)`.

### State and the controller

- Without a `controller`, the grid owns its state and syncs from `rows` and
  `columns`. Pass a `FitGridController` to drive sorting, selection, filters,
  scrolling or saved layouts from outside. **Whoever constructs it disposes
  it**, as with `ScrollController`.
- Once a controller is supplied, the grid's `rows` and `columns` arguments are
  ignored. Update `controller.data.rows` and `controller.columns.columns`.
- The controller is a set of plain `ChangeNotifier`s (`data`, `columns`,
  `selection`, `focus`, `filter`, `grouping`, `range`, `details`, `history`,
  `pagination`). Listen to the piece you need; do not wrap the grid in a
  state-management rebuild.

### Editing

- **The grid never writes to a row.** `FitGridEditor.onCommit(row, index,
  value)` must update the host's data and push it back, e.g.
  `controller.data.rows = updated`. Paste, clear, fill and undo all go through
  the same `onCommit`, so one correct commit makes all of them work.
- The `index` handed to callbacks is into the rows **as displayed**: after
  sort and filter, not limited to the page. Under a sort that is not the
  index into your source list, so update rows by identity or id, not by
  position.
- Use `initialText` when the painted text is formatted, so the editor (and
  undo) work in raw values. Use `validator` to reject input; it also guards
  paste and fill.

### Server-backed rows

- With a `FitGridDataSource` the grid **does not sort or filter**. It forwards
  `sortByKeys`, `filterBy` and window loads to the source; call `search` from
  your search box yourself. `FitGridAsyncDataSource` covers the common case.
- A data source cannot be combined with `paginated`, `onLoadMore`,
  `detailBuilder`, `reorderableRows` or undo. Use `onLoadMore` for "append the
  next page to an in-memory list" instead.

### Testing

- **`find.text` never finds a cell**: cells are painted. Import
  `package:fitgrid_table/testing.dart` and use `fitGridCellText(row:, column:)`,
  `fitGridRowText`, `fitGridCellSpec`, `fitGridRowCount` and
  `fitGridSection()`. Header labels *are* widgets, so `find.text('Name')` works
  for headers only.
- On a grid with editable columns a single tap waits out the double-tap
  window: `await tester.pump(const Duration(milliseconds: 400))` after `tapAt`
  before asserting on selection or focus.
- Keyboard shortcuts only act while the grid itself has focus. Use
  `autofocus: true` or tap a cell first.

## Examples

A typed grid with a controller:

```dart
final controller = FitGridController<Employee>(
  rows: employees,
  columns: [
    FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name, sortable: true),
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

FitGrid<Employee>(
  controller: controller,
  selectionMode: FitGridSelectionMode.multiple,
  showColumnMenu: true,
)
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

For range selection and paste, detail rows, infinite scroll, row reordering,
charts, pivots, xlsx export, saved layouts and data sources, see
[references/recipes.md](references/recipes.md).
