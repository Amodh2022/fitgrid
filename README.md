# fitgrid

A Flutter data grid that **measures your content** instead of making you guess
column widths, and **paints cells** instead of building a widget for each one.

> Status: early. The foundation — content measurement, painted cells,
> windowing, theming, RTL — is in place and tested. Selection, keyboard
> navigation, filtering, grouping and inline editing are on the roadmap below.

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
header, and the columns you explicitly ask to build.

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
trusting the single longest string; `measureAllRows` opts out of the
approximation when a table is small enough to afford the truth.

### Resizing by hand

Every resizable divider carries a grip, drawn quietly so it reads as available
without competing with the header. Drag it to set the column's width;
double-click it to hand the column back to its policy, which for an `auto`
column means measuring the content again. The grip is always visible rather
than appearing on hover, because a touch user has no hover state and no cursor
to change.

A dragged width is still clamped by the `min`/`max` the column declared, so the
bounds in your code hold whatever the user does with the mouse. Columns opt out
with `resizable: false`, a whole grid with `FitGrid(resizableColumns: false)`,
and a column whose policy pins it to one width — `fixed(120)`, or
`auto(min: 120, max: 120)` — gets no handle, because there would be nothing for
the drag to do.

The same two operations are on the controller:

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
anything to measure:

```dart
FitGridColumn<Note>(
  id: 'body',
  label: 'Body',
  value: (n) => n.body,
  width: const FitGridColumnWidth.fixed(280), // an `auto` column never wraps
  maxLines: 4,
)
```

Only columns that can wrap are measured — a `maxLines: 1` column occupies one
line whatever is in it, and its height is computed once for the whole grid
rather than once per cell. A grid where nothing wraps resolves to a single
uniform height and pays nothing at all for asking. When something does wrap, row
offsets move from multiplication into a prefix-sum table and scrolling, painting
and hit-testing all binary search it; that costs one `TextPainter` layout per
row per wrapping column, which is the one price virtualization cannot dodge,
because a scrollbar cannot be honest until every row's height is known.

### Overflow

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

`fade` cuts its ramp out of the glyphs with `dstOut` rather than painting a
gradient over them, so it reveals whatever is actually behind — the stripe, the
selection colour, a custom row colour — instead of smearing one assumed
background over another.

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
mirrored RTL position without duplicating any geometry. The painted value
underneath is skipped while it is open, so the two never show through each
other.

The keyboard contract is the one people already know: **Enter** commits,
**Escape** abandons, **Tab** commits and moves to the next editable cell.
Clicking away commits by default (`commitOnFocusLoss: false` to discard
instead).

The grid never mutates your rows — it does not know how. `onCommit` hands back
the row, its index **in the full row list**, and the text; updating the model is
yours. That index stays correct while the grid is sorted and paginated, which is
the part that is easy to get wrong.

`builder` replaces the text field entirely for a dropdown, a date picker or a
stepper; `FitGrid(editTrigger:)` switches between double-tap, single-tap and
`programmatic`, and `controller.editing.begin(rowIndex, columnId)` opens one
from code.

## Pagination

```dart
FitGrid<Employee>(
  rows: employees,
  columns: columns,
  paginated: true,
  pageSize: 25,
)
```

No dependency, and no copying: a page is a read-only window onto the same list
(`FitGridPageView`), O(1) to create, so turning a page allocates nothing. The
window object is memoized, because every cache downstream — column layout, row
metrics, painted cell specs — is keyed on its identity.

Two details that are easy to get wrong and are handled here:

- **Column widths are measured against the whole dataset, not the page**, or
  every column would visibly jump each time the user turned a page.
- **Row indices stay global.** `onRowTap` and the selection speak in indices
  into the full list, so a selection survives paging instead of silently
  reattaching to whatever now sits in that position.

Drive it from the controller, or replace the pager outright:

```dart
controller.pagination.next();
controller.pagination.revealRow(603); // jump to the page holding a row
controller.pagination.pageSize = 50;  // keeps the current rows on screen

FitGrid(paginated: true, pagerBuilder: (context, pagination) => MyPager(pagination));
```

## Testing

Cells are painted, so **`find.text` will never match a row**. That is inherent to
the approach, so the helpers ship in the box:

```dart
import 'package:fitgrid/testing.dart';

expectFitGridCell(tester, 'Amit', row: 0, column: 1);
expectFitGridRow(tester, 1, ['Bernadette', 'Designer', '£72,000']);
expect(fitGridLaidOutRowCount(tester), lessThan(40)); // virtualization holds
```

## What's here today

- Content-measured column widths, with min/max clamps, flex, fixed, header-fit
- Content-measured row heights, with wrapping cells and min/max clamps
- All four overflow policies, including fade and truncation-only tooltips
- Pagination with no dependency and no per-page copying
- Inline editing: one editor widget, validation, Enter/Escape/Tab, custom
  editors
- Drag-to-resize columns with a visible grip, double-click a divider to re-fit
  — clamped by the policy, and mirrored correctly in RTL
- Painted text cells with cached, pruned painters and batched rules
- Row windowing — a 100,000-row grid lays out tens of rows, not tens of thousands
- Pinned header with tri-state sorting
- Zebra striping, three densities, light/dark from your `ThemeData`
- Right-to-left
- `FitGridController` for sorting, selection and column visibility — a plain
  `ChangeNotifier` cluster, so it composes with bloc, riverpod, signals or
  `setState` without any of them being a dependency
- Zero non-Flutter dependencies

## Roadmap

- **v0.1** — frozen columns left and right, overflow policies, per-cell
  semantics, published benchmarks
- **v0.2** — accessibility semantics for painted cells, frozen columns, a shared
  paragraph cache, search-match highlighting, published benchmarks
- **v0.3** — selection, full keyboard navigation, clipboard, context menus
- **v0.4** — filtering, grouping, tree rows, aggregate footers, merged cells
- **v0.5** — undo/redo, drag-fill, multi-cell paste
- **v1.0** — xlsx/PDF export, print, responsive fallbacks, docs site

## License

MIT
