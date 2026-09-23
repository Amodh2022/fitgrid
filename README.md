# fitgrid

A Flutter data grid that **measures your content** instead of making you guess
column widths, and **paints cells** instead of building a widget for each one.

```
      rows   first frame   median scroll frame   painted cells   rows laid out
     1,000       21.0 ms              5.1 ms              94              20
    10,000       17.3 ms              3.9 ms              94              20
   100,000       28.7 ms              3.3 ms              94              20
 1,000,000       41.6 ms              2.9 ms              94              20
```

Same viewport, a thousand times the data, the same amount of work. That is the
whole argument, and `benchmark/` is where it is measured rather than asserted.

## Install

```sh
flutter pub add fitgrid_table
```

```dart
import 'package:fitgrid_table/fitgrid_table.dart';
```

## Why another data grid

Two things every Flutter table gets wrong, and this one doesn't.

**Column widths are a guess.** The usual API gives you three T-shirt sizes and a
pair of ratio knobs, and you tune them by eye until the table stops looking
broken. `fitgrid` measures the actual text with a `TextPainter` and sizes each
column to what is in it:

```dart
FitGrid<Employee>(
  rows: employees,
  columns: [
    FitGridColumn(id: 'name',   label: 'Name',   value: (e) => e.name),
    FitGridColumn(id: 'role',   label: 'Role',   value: (e) => e.role),
    FitGridColumn(id: 'salary', label: 'Salary', value: (e) => e.salaryText,
                  alignment: FitGridAlignment.end),
  ],
)
```

No widths, no ratios, no flex arithmetic — and the result is proportioned.

**Every cell is a widget.** A 40 x 8 block of text is 320 widgets, elements and
render objects in a conventional table, each with its own layout and paint pass.
Here it is one `RenderBox`, a pool of cached `TextPainter`s, and a single batched
line draw for the rules. Widgets get spent only where they buy something — the
header, the footer, and the one open editor.

That approach has exactly one real objection, and it is answered below: painted
cells are invisible to screen readers unless somebody puts them in the
accessibility tree. This package does.

## Column sizing

Sizing is the headline feature, so it gets real nouns rather than a bool:

```dart
FitGridColumnWidth.auto()                  // measure the content
FitGridColumnWidth.auto(min: 80, max: 400) // ...within bounds
FitGridColumnWidth.auto(sampleSize: 50)    // measure more candidates
FitGridColumnWidth.auto(measureAllRows: true)
FitGridColumnWidth.fixed(120)              // exact, never measured
FitGridColumnWidth.flex(2, min: 100)       // share the leftover
FitGridColumnWidth.fitHeader(min: 72)      // header only — for icon columns
```

Measuring 100,000 rows would cost more than painting them, so `auto` narrows
candidates by character count first — which is arithmetic — and runs the
expensive `TextPainter` layout only on the longest few. Character count is a
proxy for width, not a guarantee, which is why it samples several rather than
trusting the single longest string.

`measureAllRows` opts out of the approximation, and is **rationed**: a pass
measures a budget of rows, reports itself unfinished, and resumes on the next
build. A million-row table still gets a first frame, and the width only ever
grows towards the truth rather than jumping about on the way there.

### Resizing by hand

Every resizable divider carries a grip, drawn quietly so it reads as available
without competing with the header. Drag it to set the column's width;
double-click it to hand the column back to its policy, which for an `auto`
column means measuring the content again. The grip is always visible rather
than appearing on hover, because a touch user has no hover state and no cursor
to change.

A dragged width is still clamped by the `min`/`max` the column declared. Columns
opt out with `resizable: false`, a whole grid with `FitGrid(resizableColumns:
false)`, and a column pinned to one width gets no handle at all.

```dart
controller.columns.setWidth('name', 240); // as a drag does
controller.columns.autoSize('name');      // as a double-click does
controller.columns.autoSizeAll();
```

`autoSize` drops the override rather than measuring and pinning the result, so
a re-fitted column keeps re-fitting as the data changes instead of freezing at
whatever it measured the day it was double-clicked.

### Row heights

```dart
FitGridRowHeight.fixed(48)                       // uniform, offsets are arithmetic
FitGridRowHeight.contentSized()                  // measure each row
FitGridRowHeight.contentSized(min: 40, max: 120) // ...within bounds
```

`contentSized` pairs with `FitGridColumn.maxLines`, which is what gives a row
anything to measure. Only columns that can wrap are measured — a `maxLines: 1`
column occupies one line whatever is in it — and a grid where nothing wraps
resolves to a single uniform height and pays nothing at all for asking.

## Accessibility

Painting cells means no `Text` widget, which means nothing in the semantics tree
— unless the render object builds one. It does: a `table` node holding one `row`
per visible row and one `cell` per visible cell, labelled with the column name
and the value, recycled across updates and **bounded by the window**. A
20,000-row grid emits under two hundred nodes.

```dart
FitGridColumn<Event>(
  id: 'when',
  label: 'Updated',
  value: (e) => e.relative,           // painted: "3m"
  semanticValue: (e) => e.spokenTime, // spoken:  "3 minutes ago"
)
```

Headers announce as headers with their sort state; selected rows announce as
selected; a screen reader activating a cell opens its editor if it has one.

## Frozen columns

```dart
FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name,
              freeze: FitGridFreeze.start),
FitGridColumn(id: 'actions', label: '', value: (e) => '',
              freeze: FitGridFreeze.end),
```

Pinned columns are pulled to the edges whatever order you declared them in,
because the alternative — pinning only the columns that already happen to be at
an edge — is a rule nobody can remember.

They are not a second render object. The layout is partitioned into three
contiguous bands — leading-pinned, scrolling, trailing-pinned — so freezing a
column costs a clip rather than a parallel widget tree, and the header, the body
and the footer share one geometry instead of three that drift apart after a
resize. The seam gets a shadow only once there is something underneath it.

## Selection and the keyboard

```dart
FitGrid<Employee>(
  rows: employees,
  columns: columns,
  selectionMode: FitGridSelectionMode.multiple,
  showSelectionColumn: true,
  onSelectionChanged: (rows) => setState(() => _selected = rows),
)
```

Click replaces, Ctrl-click toggles, Shift-click extends from the anchor — the
three behaviours every desktop table has. `showSelectionColumn` adds a pinned
checkbox column with a tri-state select-all box in the header; the checkbox is a
**glyph in the cell spec**, not a `Checkbox` widget, so turning it on does not
put a widget back into every row.

The keyboard gets a focused *cell*, not a focused row:

| | |
|---|---|
| Arrows | move one cell |
| Shift+Up/Down | extend the selection |
| Home / End | first / last column |
| Ctrl+Home / End | first / last row |
| Page Up / Down | a viewport, minus a line of context |
| Space | toggle the focused row |
| Enter | edit the cell, or activate it |
| Ctrl+A | select all |
| Ctrl+C | copy as TSV |
| Escape | close the editor, or clear the selection |

Tab is deliberately **not** bound. Binding it would move focus between cells and
trap it in the grid, and a widget a keyboard user cannot leave is worse than one
they cannot enter. Tab inside an open editor still moves to the next editable
cell — that is the editor's binding, and it ends when the editor closes.

Everything resolves by intent, so a `Shortcuts` ancestor can rebind any of it.

## Searching, filtering and highlighting

```dart
controller.filter.query = 'designer';
controller.filter.setColumnFilter('salary', (e) => e.salary > 90000);
```

The search runs over every `searchable` column, and matches are highlighted
behind the glyphs. That highlight is nearly free here: the render layer draws a
rectangle from the painter it has **already laid out**. A widget table has to
rebuild the cell as a span tree to carry the same thing, which is why most of
them don't offer it.

Filtering lives in its own notifier so a keystroke re-derives the row view
without re-measuring a single column.

## Grouping and tree rows

```dart
controller.grouping.groups = [
  FitGridGroup(keyOf: (e) => e.department),
  FitGridGroup(keyOf: (e) => e.role),
];

// or a hierarchy
controller.grouping.tree = FitGridTree(childrenOf: (node) => node.children);
```

Both flatten to the same list of display lines, so neither gets its own path
through the renderer, the hit tests or the semantics. A collapsed group costs
its header and nothing else.

A group header is an **ordinary painted cell** that spans every column, with a
chevron glyph — grouping adds no widgets. That spanning is exposed as merged
cells generally, and a span crosses a pinned boundary when it has to, so a
header beginning inside the checkbox column is still a sentence.

Row indices stay global throughout. Collapsing a group does not renumber the
rows below it, which is the part that is easy to get wrong.

## Conditional formatting

```dart
FitGrid<Invoice>(
  rows: invoices,
  columns: columns,
  rowColor: (invoice, index) => invoice.overdue ? Colors.red.shade50 : null,
  // and per cell:
  // FitGridColumn(..., cellStyle: (row, i) => row.overdue ? bold : null),
)
```

The colour is handed to the paint pass, so flagging a thousand overdue rows
costs a thousand `drawRect` calls rather than a thousand `Container`s. A
selection wins where the two meet: a selection the user just made should not be
hidden by a rule they wrote months ago.

## Widgets in cells

```dart
FitGridColumn<Employee>(
  id: 'actions',
  label: 'Actions',
  value: (e) => e.name,                          // search, copy, screen readers
  width: const FitGridColumnWidth.fixed(120),    // widgets are not measured
  cellBuilder: (context, e, rowIndex) => IconButton(
    icon: const Icon(Icons.edit_outlined),
    onPressed: () => edit(e),
  ),
)
```

Most columns should stay painted text. For the few that need a real widget, such
as a button, a switch, an avatar or a status pill, `cellBuilder` builds one per
cell. They are virtualized the way a sliver list is: built **during layout** for
the rows on screen plus overscan, and dropped as they scroll away. A builder
column over a million rows costs a screenful of widgets.

Each widget gets its cell's box, inset by the theme's cell padding and aligned
by the column's `alignment`. In a scrolled column it is clipped beneath a pinned
column, as painted text is, and cannot be pressed through it. A widget that
handles taps itself, like a button, keeps them, so the row is not selected as
well. A passive widget, like a pill, lets the tap select the row. The column's
`value` still drives search, sort, copy, export and what a screen reader reads
for the cell.

## Overflow

```dart
FitGridOverflow.ellipsis          // clip with a trailing …
FitGridOverflow.fade              // clip with a soft alpha ramp
FitGridOverflow.clip              // hard clip, no affordance
FitGridOverflow.tooltipOnTruncate // … plus a tooltip, on the clipped cells only
```

`tooltipOnTruncate` is the one worth pointing at. The grid paints its own text,
so it already recorded, while painting, which cells lost characters — the
tooltip appears on exactly those and nowhere else. A widget-per-cell table has
to lay the text out a second time to learn the same thing, which is why those
tables offer a tooltip on every cell or on none.

`fade` paints the ramp **into the glyphs**, through a gradient foreground, so it
reveals whatever is actually behind — the stripe, the selection colour, a custom
row colour — instead of smearing one assumed background over another. It used to
do that with a `saveLayer` per truncated cell per frame; an offscreen render
target sixty times a second is the most expensive thing a grid can do.

## Editing

```dart
FitGridColumn<Employee>(
  id: 'salary',
  label: 'Salary',
  value: (e) => e.salaryText,                     // painted: "$72,000"
  editor: FitGridEditor<Employee>(
    initialText: (e) => e.salary.toString(),      // edited: "72000"
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    validator: (e, value) =>
        int.tryParse(value) == null ? 'Enter a whole number' : null,
    onCommit: (e, rowIndex, value) => save(rowIndex, int.parse(value)),
  ),
)
```

Editing is where painting cells turns from a constraint into the point. A
widget-per-cell table carries the cost of every cell all the time so that any of
them *could* become editable. Here exactly one editor widget exists, and only
while it is open: it is an overlay child of the painted section, laid into the
cell's own box by the render object — so it inherits the resized width and the
mirrored RTL position without duplicating any geometry.

**Enter** commits, **Escape** abandons, **Tab** commits and moves to the next
editable cell. Clicking away commits by default (`commitOnFocusLoss: false` to
discard instead).

The grid never mutates your rows — it does not know how. `onCommit` hands back
the row, its index **in the full row list**, and the text.

## Rows the grid does not hold

```dart
final source = FitGridAsyncDataSource<Order>(
  pageSize: 100,
  fetch: (request) async {
    final page = await api.orders(
      offset: request.offset,
      limit: request.limit,
      sort: request.sortColumnId,
      query: request.query,
    );
    return FitGridPageResult(rows: page.items, totalCount: page.total);
  },
);

FitGrid<Order>(dataSource: source, columns: columns);
```

Pages are cached, the cache is bounded and evicted furthest-from-the-viewport
first, and a row that has not arrived paints blank in geometry that is already
the right size — so nothing jumps when it lands. Sorting and filtering are
forwarded to the source rather than applied to the window, because sorting fifty
rows out of a million produces an order that changes as the user scrolls.

## Aggregates, export and the clipboard

```dart
FitGridColumn<Employee>(
  id: 'salary', label: 'Salary', value: (e) => e.salaryText,
  copyValue: (e) => e.salary.toString(),   // 72000, not "$72,000"
  footerLabel: 'Total',
  aggregate: (rows) => money(rows.fold(0, (s, e) => s + e.salary)),
)
```

The footer is computed over the rows **on screen**, filter included: a total the
user cannot add up themselves is a total they are right not to trust.

```dart
final csv = fitGridToCsv(controller.export());
final selection = fitGridToTsv(controller.export(selectedOnly: true));
```

```dart
final Uint8List workbook = fitGridToXlsx(controller.export(), sheetName: 'Staff');
```

Export produces rows, and three writers turn them into files without adding a
dependency: CSV and TSV with RFC 4180 quoting (skipping it is how an address
column silently becomes three), and an Excel workbook written in pure Dart —
stored zip entries, a bold frozen header, group outline levels, numbers as
numbers except where that would drop a leading zero or precision. It runs on
the web. A PDF, or a styled workbook, is a writer of your own over
`FitGridExportData`.

## Pagination

```dart
FitGrid<Employee>(rows: employees, columns: columns, paginated: true, pageSize: 25)
```

No dependency, and no copying: a page is a read-only window onto the same list,
O(1) to create. Column widths are measured against the whole dataset, not the
page, or every column would visibly jump each time the user turned one. Row
indices stay global, so a selection survives paging.

```dart
controller.pagination.next();
controller.pagination.revealRow(603);
controller.scrollTo(603, columnId: 'salary'); // pages, then scrolls
```

## Sorting by several columns

Shift+click a second header and it becomes the tie-breaker; each sorted header
shows its priority. The sort is stable, so rows equal on every key keep their
order.

```dart
controller.setSort(const [
  FitGridSortKey('department', FitGridSortDirection.ascending),
  FitGridSortKey('salary', FitGridSortDirection.descending),
]);
```

A data source receives every key in `FitGridPageRequest.sortKeys`; one written
before multi-column sorting existed keeps working and sorts by the first.

## The column menu, the chooser and filters

```dart
FitGrid<Employee>(
  controller: controller,
  showColumnMenu: true,           // sort, filter, pin, size to fit, hide, columns…
  columns: [
    FitGridColumn(id: 'role', label: 'Role', value: (e) => e.role,
        filter: const FitGridFilterSpec.values()),          // a checklist
    FitGridColumn(id: 'salary', label: 'Salary', value: (e) => e.salaryText,
        filter: FitGridFilterSpec.number((e) => e.salary)), // greater than, between…
    FitGridColumn(id: 'hired', label: 'Hired', value: (e) => e.hiredText,
        filter: FitGridFilterSpec.date((e) => e.hired)),    // by calendar day
  ],
)

FitGridColumnChooser<Employee>(controller: controller) // anywhere, e.g. a toolbar
```

Filters are data, not closures — `FitGridColumnFilter` — so they are shown back
to the user when the dialog reopens, saved with the layout, and sent to a data
source as JSON through `filterBy`. A filtered header shows a glyph.

## Ranges, paste, fill and undo

```dart
FitGrid<Employee>(controller: controller, cellSelection: true)
```

Drag with the mouse, Shift+click or Shift+arrow to select a block of cells; it
copies as a block. Ctrl+V pastes a block from its top-left cell, or fills the
range with a single value. Delete clears it. The handle on the range's corner
fills neighbouring cells — `1, 2` continues to `3, 4`, `Item 1` to `Item 2`,
anything else repeats. Every value goes through the column's own validator and
`onCommit`, exactly as a typed edit does; the grid never writes to a row.

Ctrl+Z and Ctrl+Shift+Z undo and redo typed edits, pastes, clears and fills, a
whole paste being one step. `controller.undo()` does the same from a button.

## Header bands

```dart
FitGrid<Sale>(
  columnGroups: const [
    FitGridColumnGroup(id: 'q1', label: 'Q1', columnIds: ['jan', 'feb', 'mar']),
  ],
  ...
)
```

A band follows its columns through a drag, and splits into one band per run
when they are separated.

## Detail rows

```dart
FitGrid<Order>(
  rows: orders,
  columns: columns,
  rowKey: (o) => o.id,
  detailBuilder: (context, order, index) => OrderLines(order),
  detailRowHeight: 220,
)
```

A chevron column opens a full-width panel under the row — any widget, built only
while on screen. Open panels follow their row through a sort. They take no part
in selection, copy or export.

## Loading as the user scrolls

```dart
FitGrid<Item>(
  rows: items,
  columns: columns,
  onLoadMore: () async {
    final next = await api.next();
    setState(() => items = [...items, ...next]);
  },
  hasMoreRows: api.hasMore,
)
```

Called near the end, once at a time, with skeleton rows while it runs; a failure
waits for the next scroll rather than retrying in a loop. Rows a data source is
still fetching paint as the same skeletons.

## Reordering rows

`reorderableRows: true` adds drag handles, and Alt+Up / Alt+Down moves the
focused row. The grid moves the row in the controller, or hands the move to
`onRowReorder`. Selection and focus follow. It is off while sorted or grouped,
when the order is not the rows' own.

## Charts in cells

```dart
FitGridColumn<Stock>(
  id: 'trend', label: 'Trend', value: (s) => s.closes.join(', '),
  width: const FitGridColumnWidth.fixed(120),
  visual: FitGridCellVisual.sparkline((s) => s.closes, filled: true),
)
```

`.bar` draws data bars from the zero line (negatives the other way, in their own
colour), `.progress` a filled track, `.sparkline` a line. They are painted by the
text pass, so a column of ten thousand costs what ten thousand words do.

## Pivots

```dart
final pivot = fitGridPivot<Sale>(
  sales,
  rows: [FitGridPivotDimension(id: 'region', label: 'Region', keyOf: (s) => s.region)],
  columns: FitGridPivotDimension(id: 'q', label: 'Quarter', keyOf: (s) => s.quarter),
  values: [FitGridPivotValue(id: 'revenue', label: 'Revenue', valueOf: (s) => s.amount)],
);
FitGrid<FitGridPivotRow>(rows: pivot.rows, columns: pivot.columns);
```

The result is an ordinary grid, so sorting, filtering and export work on it.
Grand totals come from the source rows — an average is never an average of
averages.

## Remembering the layout

```dart
prefs.setString('grid', jsonEncode(controller.saveState().toJson()));
controller.restoreState(FitGridSavedState.fromJson(jsonDecode(saved)));
```

Column order, visibility, pins, dragged widths, sort, filters, search and page.
Restoring is forgiving: a removed column is skipped, and one added since keeps
the place it was declared in.

## Testing

Cells are painted, so **`find.text` will never match a row**. That is inherent
to the approach, so the helpers ship in the box — and they have **no dependency
on `flutter_test`**, so they cost applications nothing:

```dart
import 'package:fitgrid_table/testing.dart';

expect(fitGridCellText(row: 0, column: 1), 'Amit');
expect(fitGridRowText(1), ['Bernadette', 'Designer', '£72,000']);
expect(fitGridLaidOutRowCount(), lessThan(40));   // virtualization holds
expect(fitGridSemanticsNodeCount(), lessThan(200)); // ...and so does the a11y tree
expect(fitGridColumnLeft('name'), 0);              // the pinned column stayed put
```

They find the grid themselves rather than taking a `WidgetTester`, and you use
your own `expect` on what they return.

## Benchmarks

```
flutter test benchmark/frame_benchmark.dart
flutter test benchmark/measurement_benchmark.dart
```

See `benchmark/README.md` for what to look for. The headline is at the top of
this file; the sizing numbers on the same machine:

```
Column measurement, sampled auto     1,000 rows   0.9 ms
                                 1,000,000 rows  25.2 ms
Row measurement, nothing wraps   1,000,000 rows   0.0 ms
Row measurement, one wrapping column 10,000 rows 178.7 ms
```

The last line is the one honest cost in the package and there is no way around
it: a scrollbar cannot be right until every row's height is known. Clamp a
wrapping column's width so the wrap point is stable, and prefer
`FitGridRowHeight.fixed` for datasets where it would show.

## What's here today

- Content-measured column widths and row heights, with clamps, flex, header-fit
- A real accessibility tree over painted cells, bounded by the viewport
- Frozen columns at either edge, with banded geometry shared by header and footer
- Selection with modes, modifiers, a painted checkbox column and select-all
- Full keyboard navigation, a focus ring, and TSV copy
- Search with match highlighting; typed column filters and value checklists
- A column menu, a column chooser, and saved/restored layouts
- Multi-column sort, with priorities in the headers
- Cell ranges with block copy, paste, a fill handle, and undo/redo
- Grouping (with sticky headers), tree rows, detail rows and merged cells
- Header bands spanning column groups
- Aggregate footer, CSV/TSV/xlsx export, context menus, column reordering
- Row drag-to-reorder, infinite scroll with skeleton rows
- Data bars, progress tracks and sparklines, painted
- A pivot engine that produces an ordinary grid
- Conditional row and cell formatting, painted rather than built
- Real widgets in cells where you need them, virtualized like a sliver
- Async data sources with a bounded page cache
- Inline editing: one editor widget, validation, Enter/Escape/Tab
- All four overflow policies, truncation-only tooltips
- Pagination with no dependency and no per-page copying
- Zebra striping, three densities, light/dark, right-to-left
- `FitGridController` — a plain `ChangeNotifier` cluster, so it composes with
  bloc, riverpod, signals or `setState` without any of them being a dependency
- Zero non-Flutter dependencies, in the package and in your app

## Roadmap

- **v0.2** — a drag-and-drop pivot designer, PDF export and printing
- **v1.0** — responsive fallbacks, a docs site

## License

MIT
