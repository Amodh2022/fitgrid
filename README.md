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

- **v0.1** — column resize (double-click a divider to re-fit), frozen columns
  left and right, overflow policies, per-cell semantics, published benchmarks
- **v0.2** — selection, full keyboard navigation, clipboard, context menus,
  search-match highlighting
- **v0.3** — filtering, grouping, tree rows, aggregate footers, merged cells
- **v0.4** — inline editing, validation, undo/redo, drag-fill
- **v1.0** — xlsx/PDF export, print, responsive fallbacks, docs site

## License

MIT
