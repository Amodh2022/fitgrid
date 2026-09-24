# fitgrid

A Flutter data grid that **measures your content** instead of making you guess
column widths, and **paints cells** instead of building a widget for each one.

![fitgrid: a data grid with content-sized columns, sorting, selection and footer totals](https://raw.githubusercontent.com/Amodh2022/fitgrid/main/screenshots/overview.png)

**[Try the live demo →](https://fitgrid-e734.vercel.app/demo/)** — every
feature below, running in your browser. Also:
[website](https://fitgrid-e734.vercel.app/) ·
[choosing a Flutter data table](https://fitgrid-e734.vercel.app/choosing-a-flutter-data-table.html)

```
      rows   first frame   median scroll frame   painted cells   rows laid out
     1,000       21.0 ms              5.1 ms              94              20
    10,000       17.3 ms              3.9 ms              94              20
   100,000       28.7 ms              3.3 ms              94              20
 1,000,000       41.6 ms              2.9 ms              94              20
```

Same viewport, a thousand times the data, the same amount of work. That is the
whole argument, and `benchmark/` is where it is measured rather than asserted.

It is also a complete grid: multi-column sort, typed filters with a UI, a
column menu, cell ranges with copy, paste, fill and undo, grouping with sticky
headers, tree rows, detail rows, header bands, row reordering, infinite scroll,
server-backed rows, charts in cells, pivots, CSV/TSV/xlsx export, saved
layouts, a real accessibility tree, right-to-left, light and dark — with **no
dependency beyond Flutter**.

---

## Contents

**Getting started**
[Install](#install) ·
[Your first grid](#your-first-grid) ·
[Core concepts](#core-concepts)

**Columns and layout**
[Column reference](#column-reference) ·
[Column widths](#column-widths) ·
[Row heights](#row-heights) ·
[Frozen columns](#frozen-columns)

**Look and feel**
[Theming and colours](#theming-and-colours) ·
[Conditional formatting](#conditional-formatting) ·
[Overflow and tooltips](#overflow-and-tooltips) ·
[Widgets in cells](#widgets-in-cells) ·
[Charts in cells](#charts-in-cells)

**Working with data**
[Sorting](#sorting) ·
[Search and filters](#search-and-filters) ·
[The column menu and chooser](#the-column-menu-and-chooser) ·
[Selection and the keyboard](#selection-and-the-keyboard) ·
[Editing](#editing) ·
[Ranges, paste, fill and undo](#ranges-paste-fill-and-undo)

**Structure**
[Grouping, trees and sticky headers](#grouping-trees-and-sticky-headers) ·
[Header bands](#header-bands) ·
[Detail rows](#detail-rows) ·
[Reordering rows and columns](#reordering-rows-and-columns)

**Getting rows in and out**
[Pagination](#pagination) ·
[Infinite scroll](#infinite-scroll) ·
[Rows the grid does not hold](#rows-the-grid-does-not-hold) ·
[Footer totals, export and the clipboard](#footer-totals-export-and-the-clipboard) ·
[Pivots](#pivots) ·
[Saving the layout](#saving-the-layout)

**Reference**
[Accessibility](#accessibility) ·
[The controller](#the-controller) ·
[FitGrid parameters](#fitgrid-parameters) ·
[Testing](#testing) ·
[Performance](#performance) ·
[Gotchas](#gotchas) ·
[For AI agents](#for-ai-agents)

---

## Install

```sh
flutter pub add fitgrid_table
```

```dart
import 'package:fitgrid_table/fitgrid_table.dart';
```

Requires Flutter 3.35 or later (Dart 3.9).

## Your first grid

```dart
class Employee {
  const Employee(this.name, this.role, this.salary);
  final String name;
  final String role;
  final int salary;
}

FitGrid<Employee>(
  rows: employees,
  columns: [
    FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name, sortable: true),
    FitGridColumn(id: 'role', label: 'Role', value: (e) => e.role),
    FitGridColumn(
      id: 'salary',
      label: 'Salary',
      value: (e) => '\$${e.salary}',
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
    ),
  ],
)
```

There is no width arithmetic in that and it still comes out proportioned: each
column measures its content. Give the grid bounded constraints — an `Expanded`,
a `SizedBox`, a page body — as you would a `ListView`.

When you want to drive the grid from outside — sort it, filter it, read the
selection, save its layout — hold a controller:

```dart
class _PeopleState extends State<People> {
  late final controller = FitGridController<Employee>(
    rows: employees,
    columns: columns,
    selectionMode: FitGridSelectionMode.multiple,
  );

  @override
  void dispose() {
    controller.dispose(); // whoever constructs it, disposes it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FitGrid<Employee>(controller: controller);
}
```

## Core concepts

Five ideas explain almost everything else in this file.

**1. Cells are painted.** A block of text cells is one `RenderBox` with a
handful of cached `TextPainter`s, not a widget per cell. That is where the
speed comes from, and it has two consequences: `find.text` cannot see a cell
(use [`testing.dart`](#testing)), and anything that would be a widget elsewhere
— a colour, a glyph, a highlight, a chart — is a *value* the paint pass reads.
When you do need a real widget, [`cellBuilder`](#widgets-in-cells) builds one
per visible cell.

**2. Columns are typed, and identified by `id`.** A `FitGridColumn<T>` reads
your model through `value: (row) => String`. Its `id` keys everything that
must survive a rebuild — widths, sort, filters, focus, saved layouts — so it
must be stable and unique.

**3. The controller is a cluster of small notifiers.** `data`, `columns`,
`selection`, `focus`, `filter`, `grouping`, `pagination`, `range`, `details`,
`editing`, `history`. Each changes on its own, so typing into the search does
not re-measure columns and dragging a column wider does not re-sort rows. It is
plain `ChangeNotifier`s: it composes with bloc, riverpod, signals or `setState`
without any of them being a dependency.

**4. Indices are into the rows as displayed.** Every `rowIndex` the grid hands
you — to `onRowTap`, editors, the selection, the focus — is a position in the
filtered, sorted list, never in the page. A selection survives paging. Under a
sort it is *not* the index into your source list; update rows by identity.

**5. The grid never writes to your rows.** Edits, pastes, fills and undo all
come back through your `onCommit`; you update the data and hand it back. That
is what keeps the grid free of an opinion about your state management.

---

## Column reference

Every property of `FitGridColumn<T>`:

| Property | Type | Default | What it does |
|---|---|---|---|
| `id` | `String` | required | Stable, unique identity. Never the display index. Must not start with `__fitgrid`. |
| `label` | `String` | required | Header text; also measured by `auto` widths. |
| `value` | `String Function(T)` | required | The cell's text. Also what search, the default sort, copy, export and screen readers use. |
| `width` | `FitGridColumnWidth` | `auto()` | How the column decides its width. See [Column widths](#column-widths). |
| `alignment` | `FitGridAlignment` | `start` | Cell content alignment: `start`, `center`, `end` (mirrors under RTL). |
| `headerAlignment` | `FitGridAlignment?` | `alignment` | Header label alignment. |
| `overflow` | `FitGridOverflow` | `ellipsis` | `ellipsis`, `fade`, `clip`, `tooltipOnTruncate`. |
| `maxLines` | `int?` | `1` | Lines a cell may wrap to. `null` = unlimited. Needs `FitGridRowHeight.contentSized()`. |
| `freeze` | `FitGridFreeze` | `none` | Pin to the `start` or `end` edge. |
| `visible` | `bool` | `true` | Whether it is shown. Hidden columns keep their width and sort. |
| `hideable` | `bool` | `true` | Whether the chooser and column menu offer to hide it. |
| `resizable` | `bool` | `true` | Whether its divider can be dragged. |
| `reorderable` | `bool` | `true` | Whether its header can be dragged to move it. |
| `sortable` | `bool` | `false` | Whether tapping the header sorts. |
| `comparator` | `Comparator<T>?` | text compare | Sort order. **Supply one for numbers and dates.** |
| `searchable` | `bool` | `true` | Whether the free-text search looks at it. |
| `filter` | `FitGridFilterSpec<T>?` | `null` | Opts into the filter UI. See [filters](#search-and-filters). |
| `cellStyle` | `TextStyle? Function(T, int)?` | `null` | Per-cell text style, over the theme's. |
| `icon` / `iconColor` | `IconData?` / `Color? Function(T, int)?` | `null` | A painted glyph before the text, and its colour. |
| `visual` | `FitGridCellVisual<T>?` | `null` | A painted chart: bar, progress, sparkline. |
| `cellBuilder` | `Widget Function(BuildContext, T, int)?` | `null` | A real widget per visible cell instead of painted text. |
| `headerBuilder` | `WidgetBuilder?` | `null` | Replaces the header cell entirely. |
| `tooltip` | `String?` | `null` | Tooltip on the header. |
| `semanticValue` | `String Function(T)?` | `value` | What a screen reader says, when the painted text is for the eye. |
| `copyValue` | `String Function(T)?` | `value` | What copy and export carry (`72000`, not `$72,000`). |
| `editor` | `FitGridEditor<T>?` | `null` | Makes the column editable. See [Editing](#editing). |
| `aggregate` | `String Function(List<T>)?` | `null` | The footer value — a total, a mean, a count. |
| `footerLabel` | `String?` | `null` | Text painted before the aggregate, such as `Total`. |

Columns are immutable; `copyWith` makes variants.

## Column widths

Sizing is the headline feature, so it gets real nouns rather than a bool:

```dart
FitGridColumnWidth.auto()                   // measure the content (the default)
FitGridColumnWidth.auto(min: 80, max: 400)  // ...within bounds
FitGridColumnWidth.auto(sampleSize: 50)     // measure more candidates
FitGridColumnWidth.auto(measureAllRows: true)
FitGridColumnWidth.fixed(120)               // exact, never measured
FitGridColumnWidth.flex(2, min: 100)        // share the leftover space
FitGridColumnWidth.fitHeader(min: 72)       // the header only — icon columns
```

Measuring 100,000 rows would cost more than painting them, so `auto` narrows
candidates by character count first — arithmetic — and runs `TextPainter`
layout only on the longest few (`sampleSize`, default 24). `measureAllRows`
measures everything, **rationed** across frames: a million-row table still gets
a first frame, and the width only ever grows towards the truth.

When the grid is wider than its columns, `flex` columns share the leftover; with
none, `auto` columns grow in proportion to what they need. Turn that off with
`FitGrid(stretchColumnsToFill: false)` when a column's honest width carries
meaning — the slack is left empty after the last column.

Widget cells and charts have no text width to measure: give those columns
`fixed` widths.

### Resizing by hand

Every resizable divider carries a grip, always visible so touch users can see
it. Drag it to set a width; double-click it to hand the column back to its
policy — for `auto`, measure again. A dragged width is still clamped by the
column's `min`/`max`. Turn it off per column (`resizable: false`) or per grid
(`resizableColumns: false`).

```dart
controller.columns.setWidth('name', 240); // as a drag does
controller.columns.autoSize('name');      // as a double-click does
controller.columns.autoSizeAll();
controller.columns.isResized('name');
```

## Row heights

```dart
FitGrid(rowHeight: null)                                  // the theme's density (default)
FitGrid(rowHeight: const FitGridRowHeight.fixed(48))      // uniform
FitGrid(rowHeight: const FitGridRowHeight.contentSized()) // measure each row
FitGrid(rowHeight: const FitGridRowHeight.contentSized(min: 40, max: 120))
```

`contentSized` pairs with `FitGridColumn.maxLines`, which is what gives a row
something to measure. Only columns that can wrap are measured, and a grid where
nothing wraps resolves to one uniform height and pays nothing for asking. Give a
wrapping column a `fixed` width or an `auto` one with a `max`: an unbounded
`auto` column sizes itself to its longest line, so nothing ever wraps.

## Frozen columns

```dart
FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name,
              freeze: FitGridFreeze.start),
FitGridColumn(id: 'actions', label: '', value: (e) => '',
              freeze: FitGridFreeze.end),
```

Pinned columns are pulled to their edge whatever order you declared them in.
They are not a second render object: the layout is three contiguous bands —
leading, scrolling, trailing — so pinning costs a clip, and the header, body and
footer share one geometry. The seam shows a shadow only once something has
scrolled underneath it. Users can pin from the [column menu](#the-column-menu-and-chooser);
code can call `controller.columns.setFreeze(id, FitGridFreeze.start)`.

---

## Theming and colours

Everything visual — every colour, text style, size, spacing, divider and icon —
lives in one immutable value, `FitGridThemeData`. There is no styling anywhere
else to hunt for.

### Where a grid gets its theme

The grid resolves its theme in this order, first match wins:

1. `FitGrid(theme: ...)` on the grid itself.
2. The nearest `FitGridTheme` ancestor — theme a whole subtree at once:

   ```dart
   FitGridTheme(data: myGridTheme, child: MyScreen())
   ```

3. `FitGridThemeData.fromTheme(Theme.of(context))` — derived from your Material
   theme. With no configuration at all, a grid looks native to your app and
   follows light and dark with it.

### What comes from your Material theme

`FitGridThemeData.fromTheme(theme, density: ...)` maps your `ColorScheme` and
`TextTheme` like this, so changing your app's seed colour or text theme restyles
every grid:

| Grid colour | Light | Dark |
|---|---|---|
| `headerBackground` | `surfaceContainerLow` | `surface` + 6% `surfaceTint` |
| `headerForeground`, `sortIconColor` | `onSurfaceVariant` | same |
| `headerTextStyle` | `labelLarge`, w600, `onSurfaceVariant` | same |
| `rowBackground` | `surface` | `surface` |
| `alternateRowBackground` (stripes) | `surfaceContainerLowest` | `surface` + 2.5% `onSurface` |
| `cellTextStyle` | `bodyMedium`, `onSurface` | same |
| `rowDivider`, `columnDivider` | `outlineVariant` at 70% | `outlineVariant` at 28% |
| `border` | `outlineVariant` at 80% | at 40% |
| `hoverBackground` | `onSurface` at 4% | same |
| `selectedBackground` | `primary` at 10% | at 18% |
| `focusOutline` (focus ring, drop line, fill handle) | `primary` | same |
| `placeholderForeground` | `onSurfaceVariant` at 60% | same |
| `tooltipBackground` / `tooltipForeground` | `inverseSurface` / `onInverseSurface` | same |
| `searchHighlight` | `tertiary` at 28% | at 38% |
| `frozenShadow` | black at 16% | black at 45% |
| `groupHeaderBackground` | `surfaceContainer` | `surface` + 6% `onSurface` |

Dark-mode dividers lean lighter at lower alpha on purpose: the alpha that reads
as a hairline on white reads as a gap on near-black.

### Adjusting it

The usual way is to start from `fromTheme` and override what you need with
`copyWith`:

```dart
final gridTheme = FitGridThemeData.fromTheme(Theme.of(context)).copyWith(
  headerBackground: const Color(0xFF0F172A),
  headerTextStyle: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    letterSpacing: 0.4,
  ),
  selectedBackground: const Color(0x1A2563EB),
  focusOutline: const Color(0xFF2563EB),
  borderRadius: BorderRadius.circular(8),
);

FitGrid<Employee>(rows: rows, columns: columns, theme: gridTheme);
```

Resolve the theme in `build` (it reads `Theme.of`), and prefer building it once
per theme change rather than per frame — it is a cache key for painted cells.

### Light and dark

`fromTheme` already follows brightness. For hand-picked palettes, build two
themes and choose by brightness:

```dart
final brightness = Theme.of(context).brightness;
final gridTheme = brightness == Brightness.dark ? darkGridTheme : lightGridTheme;
```

Translucent colours are fine anywhere — row backgrounds included — and are
composited over whatever sits behind the grid.

### Density

```dart
FitGridThemeData.fromTheme(theme, density: FitGridDensity.compact)
```

| Density | Row height | Cell padding (h / v) |
|---|---|---|
| `compact` | 34 | 10 / 4 |
| `standard` (default) | 44 | 14 / 8 |
| `comfortable` | 56 | 18 / 14 |

The header is the row height plus 4. `rowHeight`, `headerHeight`, `cellPadding`
and `headerPadding` override any of these outright.

### Every theme property

**Surfaces and text**

| Property | Default (fromTheme) | Used for |
|---|---|---|
| `headerBackground` | see table above | Header row, footer and pager backgrounds. |
| `headerForeground` | see above | Header glyphs, group-header chevrons, detail chevrons. |
| `headerTextStyle` | see above | Header labels. |
| `rowBackground` | `surface` | Rows, and the grid's own fill. |
| `alternateRowBackground` | see above | Odd rows when `FitGrid.striped` is on. |
| `cellTextStyle` | `bodyMedium` | Every painted cell. Font family, size, weight and colour live here. |
| `groupHeaderBackground` | see above | Group header rows. |
| `groupHeaderTextStyle` | `null` → `cellTextStyle` | Group header labels. |
| `placeholderForeground` | see above | Empty-state text, dimmed glyphs, skeleton rows. |

**State colours**

| Property | Used for |
|---|---|
| `hoverBackground` | Washed over the row under the pointer (when `hoverHighlight` is on). |
| `selectedBackground` | Selected rows. Wins over `rowColor`. |
| `focusOutline` | The keyboard focus ring, the range outline, the fill handle, drop lines, active glyphs. |
| `rangeSelectionBackground` | Wash over a selected block of cells. `null` → `focusOutline` at 12%. |
| `searchHighlight` | Behind characters matching the search. |
| `sortIconColor` | Sort arrows and grips. |
| `tooltipBackground`, `tooltipForeground` | Truncation tooltips. |
| `detailBackground` | Behind detail panels. `null` → `groupHeaderBackground`. |
| `chartColor` | Bars, progress fills, sparklines. `null` → `focusOutline`. |
| `chartNegativeColor` | Bars for negative values. `null` → a red that holds up in both modes. |

**Borders, dividers and shadows**

| Property | Default | Used for |
|---|---|---|
| `border` | see above | The grid's outer border and the pinned-band seams. |
| `borderRadius` | 12 | The grid's corners. |
| `dividerThickness` | 1.0 | Every rule and border. |
| `rowDivider` | see above | Horizontal rules between rows. |
| `columnDivider` | see above | Header dividers, band dividers, and body ticks (below). |
| `rowDividerDash` | `null` (solid) | `[3, 2]` dashes the row rules: dash and gap lengths, alternating. |
| `columnDividerExtent` | `null` (full height) | `12` draws body column rules as 12px ticks centred in each row, in `columnDivider`'s colour. |
| `headerDividerExtent` | `null` (full height) | `34` draws header dividers as 34px lines centred vertically. |
| `frozenShadow`, `frozenShadowExtent` | see above, 8 | The shadow at a pinned band's edge once content scrolls under it. |

**Sizes and spacing**

| Property | Default | Used for |
|---|---|---|
| `density` | `standard` | Row height and padding; see above. |
| `rowHeight`, `headerHeight` | from density | Override the heights outright. |
| `cellPadding`, `headerPadding` | from density | Override the padding outright. |
| `minColumnWidth` | 24 | The narrowest a drag can make a column. |
| `resizeHandleWidth`, `resizeTouchTargetWidth` | 8, 32 | The drawn grip and its (wider) hit area. |
| `fadeExtent` | 28 | Length of the `FitGridOverflow.fade` ramp. |
| `tooltipMaxWidth`, `tooltipBorderRadius` | 360, 6 | Tooltip box. |
| `sortIconSize` | 18 | Sort arrows, checkboxes, chevrons, menu glyphs. |
| `cellIconSize`, `cellIconGap` | 16, 6 | Painted cell glyphs (`FitGridColumn.icon`). |
| `focusRingWidth` | 2 | Focus ring and drop line. |
| `nestingIndent` | 20 | Indent per level of grouping or tree depth. |
| `selectionColumnWidth` | 44 | The checkbox and detail-chevron columns. |
| `rowDragHandleWidth` | 32 | The drag-handle column. |
| `fillHandleSize` | 7 | The square on a selected range's corner. |

**Icons** — every glyph is replaceable:
`sortAscendingIcon`, `sortDescendingIcon`, `sortUnsortedIcon`, `resizeGripIcon`,
`checkboxIcon`, `checkboxCheckedIcon`, `checkboxIndeterminateIcon`,
`expandedIcon`, `collapsedIcon`, `columnMenuIcon`, `filterIcon`,
`filterActiveIcon`, `rowDragHandleIcon`.

### Recipes

**Your brand's fonts.** Set the family on both text styles:

```dart
theme.copyWith(
  headerTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
      fontWeight: FontWeight.w600, color: Colors.black),
  cellTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
      color: Colors.black),
)
```

Column widths and row heights are measured in these styles, so the layout
follows the font.

**Matching an existing design system.** Map your tokens onto the theme — the
three divider options cover the common "dashed rows, short separators" look:

```dart
FitGridThemeData.fromTheme(Theme.of(context)).copyWith(
  headerBackground: tokens.tableHeaderBg,
  rowBackground: tokens.tableWash,
  alternateRowBackground: tokens.tableWash,   // or striped: false on the grid
  rowDivider: tokens.rowDivider,
  columnDivider: tokens.cellDivider,
  border: tokens.subtleBorder,
  borderRadius: BorderRadius.circular(6),
  rowDividerDash: const [3, 2],               // dashed row rules
  columnDividerExtent: 12,                    // short ticks between cells
  headerDividerExtent: 34,                    // short header dividers
  sortAscendingIcon: Icons.arrow_drop_up,
  sortDescendingIcon: Icons.arrow_drop_down,
  sortUnsortedIcon: Icons.arrow_drop_up,
  sortIconSize: 20,
  headerHeight: 50,
  rowHeight: 48,
  cellPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
)
```

and on the grid, `striped: false`, `hoverHighlight: false` and
`resizableColumns: false` if the design has none of those. Your own footer goes
in [`pagerBuilder`](#pagination).

**No lines at all.** `rowDivider: Colors.transparent`,
`columnDivider: Colors.transparent`.

**A borderless grid inside a card.** `border: Colors.transparent`,
`borderRadius: BorderRadius.zero`.

**Themed sub-sections.** Wrap part of the app in `FitGridTheme(data: ...)` and
every grid beneath it follows; a grid's own `theme:` still wins.

**Headers of your own.** `FitGridColumn.headerBuilder` replaces one header cell
with any widget; the sort still answers to taps on the cell.

## Conditional formatting

Rules that depend on the data are callbacks the paint pass asks for the rows on
screen — a thousand flagged rows cost a thousand `drawRect`s, not a thousand
widgets.

```dart
const highPay = TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B7F3B));

FitGrid<Invoice>(
  rows: invoices,
  columns: [
    FitGridColumn(
      id: 'amount',
      label: 'Amount',
      value: (i) => i.amountText,
      cellStyle: (i, _) => i.amount > 10000 ? highPay : null,   // one cell
      icon: (i, _) => i.flagged ? Icons.flag_rounded : null,     // a glyph
      iconColor: (i, _) => Colors.orange,
    ),
  ],
  rowColor: (i, index) => i.overdue ? Colors.red.shade50 : null, // whole rows
)
```

Keep the callbacks cheap and pure: return shared `const` styles and colours
resolved outside the callback. A selection wins over `rowColor` — a choice the
user just made is never hidden by a rule.

## Overflow and tooltips

```dart
FitGridOverflow.ellipsis          // clip with a trailing …
FitGridOverflow.fade              // clip with a soft alpha ramp
FitGridOverflow.clip              // hard clip, no affordance
FitGridOverflow.tooltipOnTruncate // … plus a tooltip, only on clipped cells
```

`tooltipOnTruncate` is cheap here: the grid recorded which cells lost characters
while painting them, so the tooltip appears on exactly those. `fade` paints the
ramp into the glyphs, so it reveals whatever is really behind them — a stripe, a
selection, a row colour.

## Widgets in cells

```dart
FitGridColumn<Employee>(
  id: 'actions',
  label: 'Actions',
  value: (e) => e.name,                         // search, copy, screen readers
  width: const FitGridColumnWidth.fixed(120),   // widgets are not measured
  cellBuilder: (context, e, rowIndex) => IconButton(
    icon: const Icon(Icons.edit_outlined),
    onPressed: () => edit(e),
  ),
)
```

Keep most columns painted, and use `cellBuilder` for the few that need a
button, a switch, an avatar or a pill. They are virtualized like a sliver list —
built during layout for the rows on screen and dropped as they scroll away — so
a builder column over a million rows costs a screenful of widgets. Each gets the
cell's box, inset by `cellPadding` and aligned by `alignment`. A widget that
handles taps keeps them; a passive one lets the tap select the row.

## Charts in cells

```dart
FitGridColumn<Stock>(
  id: 'change',
  label: 'Change',
  value: (s) => '${s.change}%',
  width: const FitGridColumnWidth.fixed(130),
  visual: FitGridCellVisual.bar((s) => s.change),            // from zero, negatives red
),
FitGridColumn<Task>(
  id: 'done',
  label: 'Done',
  value: (t) => '${(t.done * 100).round()}%',
  width: const FitGridColumnWidth.fixed(140),
  visual: FitGridCellVisual.progress((t) => t.done),         // a track, 0 to 1
),
FitGridColumn<Stock>(
  id: 'trend',
  label: '30 days',
  value: (s) => s.closes.join(', '),                         // still copied and spoken
  width: const FitGridColumnWidth.fixed(160),
  visual: FitGridCellVisual.sparkline((s) => s.closes, filled: true),
),
```

Charts are reduced to geometry and painted by the text pass: a column of ten
thousand sparklines costs what ten thousand words do.

- **bar** — from the zero line; the range comes from the column's data unless
  you pass `min`/`max`; `color` and `negativeColor` override the theme's
  `chartColor`/`chartNegativeColor`; `showText: false` hides the text.
- **progress** — with text, a slim track along the bottom; without, a thicker
  one in the middle.
- **sparkline** — the text is not painted (no room) but stays the cell's value;
  a flat series draws flat; the last point gets a dot. Sparklines do not mirror
  under RTL: their axis is time.

---

## Sorting

`sortable: true` makes a header tap cycle ascending → descending → unsorted.
**Shift+click** another header to add it as a tie-breaker; each sorted header
then shows its priority. The sort is stable, so rows equal on every key keep
their order.

```dart
controller.toggleSort('salary');                  // as a click
controller.toggleSort('name', additive: true);    // as a Shift+click
controller.setSort(const [
  FitGridSortKey('department', FitGridSortDirection.ascending),
  FitGridSortKey('salary', FitGridSortDirection.descending),
]);
controller.clearSort();
controller.data.sortKeys;                          // the current sort
```

`FitGrid(multiSort: false)` turns the Shift gesture off. Always give numeric
and date columns a `comparator`; the default compares the painted text.

## Search and filters

**Free-text search** runs over every `searchable` column, and matches are
highlighted behind the glyphs:

```dart
controller.filter.query = 'designer';
controller.filter.caseSensitive = true;
```

**Typed filters, with a UI.** Give a column a `filter` spec and its column menu
gains "Filter…", with conditions suited to the kind of value:

```dart
FitGridColumn(id: 'name', ..., filter: const FitGridFilterSpec.text()),     // contains, starts with…
FitGridColumn(id: 'dept', ..., filter: const FitGridFilterSpec.values()),   // a searchable checklist
FitGridColumn(id: 'salary', ..., filter: FitGridFilterSpec.number((e) => e.salary)), // >, between…
FitGridColumn(id: 'hired', ..., filter: FitGridFilterSpec.date((e) => e.hired)),     // by calendar day
```

A filtered header shows a glyph. The filters are data — `FitGridColumnFilter` —
so they reopen as they were set, save with the layout, and reach a server as
JSON:

```dart
controller.filter.setFilter('salary', const FitGridColumnFilter(
  operator: FitGridFilterOperator.between, value: 50000, value2: 90000,
));
controller.filter.setFilter('dept', const FitGridColumnFilter.oneOf({'Design', 'Data'}));
controller.filter.filtersJson;          // {"salary": {"op": "between", ...}}
await showFitGridFilterDialog(context, controller, 'salary'); // the dialog, from anywhere
```

Operators: `contains`, `notContains`, `equals`, `notEquals`, `startsWith`,
`endsWith`, `greaterThan`, `greaterOrEqual`, `lessThan`, `lessOrEqual`,
`between` (inclusive), `inList`, `isEmpty`, `isNotEmpty`. Text compares ignore
case; dates compare by day. A checklist over a data source — which holds only
the rows on screen — takes its values from `FitGridFilterSpec.values(options:
[...])`.

**Free-form predicates**, when no UI is needed:

```dart
controller.filter.setColumnFilter('salary', (e) => e.salary > 90000);
```

These cannot be shown, saved or sent to a server. A filter on a hidden column
stops applying until the column is shown again. `filter.clearColumnFilters()`
clears both kinds; `filter.clear()` clears the search as well.

## The column menu and chooser

```dart
FitGrid<Employee>(controller: controller, showColumnMenu: true)
```

Every header gets a ⋮ button: sort ascending / descending / clear, filter,
pin to start / end / unpin, size to fit, hide, and "Columns…". Edit it with
`columnMenuBuilder`, which receives the built-in entries:

```dart
columnMenuBuilder: (context, column, defaults) => [
  ...defaults,
  PopupMenuItem(onTap: () => explain(column), child: const Text('About this column')),
],
```

The chooser is a separate widget, so it can live in a toolbar:

```dart
FitGridColumnChooser<Employee>(controller: controller)   // a button with a checklist
await showFitGridColumnDialog(context, controller);      // the same list in a dialog
```

It never lets the last visible column go, and skips columns with
`hideable: false`.

## Selection and the keyboard

```dart
FitGrid<Employee>(
  rows: employees,
  columns: columns,
  selectionMode: FitGridSelectionMode.multiple,   // none, single, multiple
  showSelectionColumn: true,                      // a pinned checkbox column
  onSelectionChanged: (rows) => setState(() => selected = rows),
)
```

Click replaces, Ctrl-click toggles, Shift-click extends from the anchor. The
checkbox column's boxes are painted glyphs with a tri-state select-all in the
header. The keyboard has a focused *cell*:

| Keys | Action |
|---|---|
| Arrows | Move one cell |
| Tab / Shift+Tab | Next / previous cell |
| Shift+Arrows | Extend the row selection, or the cell range with `cellSelection` |
| Home / End | First / last column |
| Ctrl+Home / Ctrl+End | First / last row |
| Page Up / Page Down | A viewport, less a line of context |
| Space | Toggle the focused row |
| Enter | Edit the cell, open a detail panel, or activate it |
| Ctrl+A | Select all rows |
| Ctrl+C | Copy the selection, the range, or the cell, as TSV |
| Ctrl+V | Paste (editable columns) |
| Delete / Backspace | Clear the range (with `cellSelection`) |
| Ctrl+Z, Ctrl+Shift+Z / Ctrl+Y | Undo, redo |
| Alt+Up / Alt+Down | Move the focused row (with `reorderableRows`) |
| Escape | Close the editor, collapse the range, or clear the selection |

On macOS, Cmd replaces Ctrl. Shortcuts act only while the grid itself has focus,
so keys typed into an open editor or a widget cell go there. Everything
resolves by intent (`kFitGridShortcuts`), so a `Shortcuts` ancestor can rebind
any of it. `keyboardNavigation: false` turns the keyboard off; `autofocus`
claims focus on first build.

## Editing

```dart
FitGridColumn<Employee>(
  id: 'salary',
  label: 'Salary',
  value: (e) => e.salaryText,                      // painted: "$72,000"
  editor: FitGridEditor<Employee>(
    initialText: (e) => e.salary.toString(),       // edited:  "72000"
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    validator: (e, text) =>
        int.tryParse(text) == null ? 'Enter a whole number' : null,
    onCommit: (e, rowIndex, text) {
      rows = [for (final r in rows) r.id == e.id ? r.copyWith(salary: int.parse(text)) : r];
      controller.data.rows = rows;                 // hand the new rows back
    },
  ),
)
```

Exactly one editor widget exists, and only while it is open, laid into the
cell's own box. **Enter** commits, **Escape** abandons, **Tab** commits and moves
to the next editable cell. Clicking away commits (`commitOnFocusLoss: false` to
discard). `FitGrid(editTrigger:)` chooses `doubleTap` (default), `singleTap` or
`programmatic` (`controller.editing.begin(rowIndex, columnId)`). A rejected
value keeps the editor open with the message in `controller.editing.error`.

For a dropdown, a date picker or a stepper, `builder` replaces the text field:

```dart
FitGridEditor<Employee>(
  onCommit: save,
  builder: (context, session) => DropdownButton<String>(
    value: session.initialText,
    items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
    onChanged: (role) => session.commit(role!),
  ),
)
```

## Ranges, paste, fill and undo

```dart
FitGrid<Employee>(controller: controller, cellSelection: true)
```

- **Select a block** by dragging with the mouse (the view auto-scrolls at the
  edges), Shift+clicking, or Shift+arrow keys. Touch drags still scroll.
- **Ctrl+C** copies the block as tab-separated text — it pastes into a
  spreadsheet as the same rectangle.
- **Ctrl+V** pastes a block from the top-left cell, or fills the whole range
  with a single copied value. The pasted block is left selected.
- **Delete** clears the editable cells of the range.
- **The fill handle** — the square on the range's corner — fills neighbouring
  cells when dragged, down, up, left or right. `1, 2` continues to `3, 4`;
  `Item 1` to `Item 2` (padding kept); anything else repeats. The same rules are
  public as `fitGridFillSeries`.
- **Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y** undo and redo typed edits, pastes, clears
  and fills — a hundred-cell paste is one step.

Every value goes through the column's `validator` and `onCommit`, exactly as a
typed edit does, and columns without an editor are skipped. From code:

```dart
controller.range.range = const FitGridCellRange(
  anchorRow: 0, anchorColumnId: 'name', extentRow: 9, extentColumnId: 'salary');
controller.undo();
controller.redo();
controller.history.canUndo;      // for enabling a toolbar button
```

Undo finds rows by `FitGrid.rowKey` after a sort. `enableUndo: false` and
`enablePaste: false` turn those off.

---

## Grouping, trees and sticky headers

```dart
controller.grouping.groups = [
  FitGridGroup(keyOf: (e) => e.department),
  FitGridGroup(keyOf: (e) => e.role, initiallyExpanded: false),
];

// or a hierarchy
controller.grouping.tree = FitGridTree(childrenOf: (node) => node.children);
```

Both flatten to one list of display lines, so a collapsed group costs its header
and nothing else. A group header is a painted cell spanning the row with a
chevron; tap it to open or close. `FitGridGroup(label: (key, rows) => ...)`
writes the header text, `comparator` orders the groups (default: the order the
current sort produced). `grouping.expandAll()`, `collapseAll()`,
`setExpanded(key, bool)`.

**Sticky headers.** While a group's rows scroll, its header stays pinned at the
top — with the headers of enclosing groups stacked above — until the next group
pushes it away. Tapping a pinned header collapses its group. On by default;
`stickyGroupHeaders: false` to turn off. A grid at rest looks the same either
way.

## Header bands

```dart
FitGrid<Sale>(
  columnGroups: const [
    FitGridColumnGroup(id: 'q1', label: 'Q1', columnIds: ['jan', 'feb', 'mar']),
    FitGridColumnGroup(id: 'q2', label: 'Q2', columnIds: ['apr', 'may', 'jun']),
  ],
  ...
)
```

A second header row with a band over each group's columns. Bands follow their
columns through a drag, and split into one band per run when a drag or a pin
separates them. Ungrouped columns' headers take both rows.

## Detail rows

```dart
FitGrid<Order>(
  rows: orders,
  columns: columns,
  rowKey: (o) => o.id,
  detailBuilder: (context, order, index) => OrderLines(order),
  detailHeight: (order, index) => 80.0 + 32 * order.lines.length,
)
```

A pinned chevron column appears; tapping it (or Enter on it) opens a full-width
panel under the row. A panel can be anything — a form, a chart, another
`FitGrid`. It is built only while its row is on screen, follows its row through
a sort by `rowKey`, and takes no part in selection, copy or export. Panels
compose with grouping, trees and pagination. From code:
`controller.details.toggle(order.id)`, `setExpanded`, `collapseAll()`.
`detailRowHeight` (default 240) sets the height when `detailHeight` is not
given; the height must be known up front, so cap content inside the panel.

## Reordering rows and columns

**Columns.** `reorderableColumns: true` lets a header be dragged onto another.
From code: `controller.moveColumnBefore('salary', 'name')`.

**Rows.** `reorderableRows: true` adds a pinned drag-handle column. Drag a row by
its handle — a drag anywhere else still scrolls — or press Alt+Up / Alt+Down on
the focused row. The selection and focus follow the row.

```dart
FitGrid<Task>(
  rows: tasks,
  columns: columns,
  reorderableRows: true,
  onRowReorder: (from, to) => setState(() => tasks.insert(to, tasks.removeAt(from))),
)
```

Without `onRowReorder` the grid moves the row in `controller.data` itself. Moving
is off (the handles dim) while the grid is sorted or grouped, when the order on
screen is not the rows' own.

---

## Pagination

```dart
FitGrid<Employee>(rows: employees, columns: columns, paginated: true, pageSize: 25)
```

A page is a read-only window onto the same list — no copying. Column widths are
measured against the whole dataset, so they do not jump between pages.

```dart
controller.pagination.next();
controller.pagination.pageIndex = 3;
controller.pagination.pageSize = 50;
controller.pagination.pageSizeOptions = const [10, 25, 50, 100];
controller.scrollTo(603, columnId: 'salary');    // turns the page, then scrolls
```

**Your own pager.** `pagerBuilder` replaces the footer and receives the same
state the built-in one reads — `firstRowIndex`, `endRowIndex`, `rowCount`,
`pageCount`, `pageIndex`, `pageSize`, `hasPrevious`/`hasNext`,
`previous()`/`next()` — and it sits inside the grid's border:

```dart
pagerBuilder: (context, p) => Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    Text('Showing ${p.firstRowIndex + 1}–${p.endRowIndex} of ${p.rowCount}'),
    IconButton(onPressed: p.hasPrevious ? p.previous : null, icon: const Icon(Icons.chevron_left)),
    IconButton(onPressed: p.hasNext ? p.next : null, icon: const Icon(Icons.chevron_right)),
  ],
),
```

The built-in pager offers the page sizes in `pageSizeOptions`, so keep
`pageSize` one of them.

## Infinite scroll

```dart
FitGrid<Item>(
  rows: items,
  columns: columns,
  hasMoreRows: hasMore,
  onLoadMore: () async {
    final page = await api.fetch(after: items.length);
    setState(() {
      items = [...items, ...page.items];
      hasMore = page.hasMore;
    });
  },
)
```

Called when the user scrolls within `loadMoreThreshold` rows (10) of the end —
and after a build, so a first batch too short to fill the screen keeps loading.
One call at a time, with `loadingRowCount` (3) skeleton rows while it runs. If
it throws, no retry happens until the user scrolls again. Not for use with
`paginated` or a data source.

## Rows the grid does not hold

For data that lives on a server, a data source fetches the windows the user
scrolls to:

```dart
final source = FitGridAsyncDataSource<Order>(
  pageSize: 100,
  maxCachedPages: 24,
  fetch: (request) async {
    final page = await api.orders(
      offset: request.offset,
      limit: request.limit,
      sort: request.sortKeys,      // every sort key, highest priority first
      filters: request.filters,    // FitGridColumnFilter JSON by column id
      query: request.query,
    );
    return FitGridPageResult(rows: page.items, totalCount: page.total);
  },
);

FitGrid<Order>(dataSource: source, columns: columns);
```

Pages are cached, the cache is bounded and evicted furthest-from-the-viewport
first, and rows still on their way paint as skeleton bars in geometry that is
already the right size, so nothing jumps. With a source attached the grid does
not sort or filter a window itself — it forwards the sort (`sortByKeys`) and the
column filters (`filterBy`); call `source.search(query)` from your search box.
Without a `totalCount` the scrollbar grows as pages arrive. Implement
`FitGridDataSource` directly for anything more custom.

A data source cannot be combined with `paginated`, `onLoadMore`, detail rows,
row reordering or undo.

## Footer totals, export and the clipboard

```dart
FitGridColumn<Employee>(
  id: 'salary', label: 'Salary', value: (e) => e.salaryText,
  copyValue: (e) => e.salary.toString(),   // 72000, not "$72,000"
  footerLabel: 'Total',
  aggregate: (rows) => money(rows.fold(0, (s, e) => s + e.salary)),
)
```

The footer appears when any column has an `aggregate`, and is computed over the
rows **on screen** — filters included (`showFooter: false` hides it).

```dart
final data = controller.export();                       // what is on screen
final selected = controller.export(selectedOnly: true);
final csv = fitGridToCsv(data);                         // RFC 4180 quoting
final tsv = fitGridToTsv(data);
final Uint8List xlsx = fitGridToXlsx(data, sheetName: 'Staff');
```

The xlsx writer is pure Dart and runs on the web: a bold, frozen header, group
outline levels, column widths from content, and numbers written as numbers —
except where that would drop a leading zero or more than fifteen digits. Saving
the bytes is up to you (a file, a download, a share sheet). For anything else,
write your own exporter over `FitGridExportData`; `fitGridParseDelimited` reads
CSV/TSV back.

A right-click or long-press opens a context menu (just "Copy" by default):

```dart
contextMenuBuilder: (context, target) => [
  PopupMenuItem(child: const Text('Delete'), onTap: () => delete(target.selection)),
],
```

`target` carries the row, its index, the column, the position and the
selection; returning `null` suppresses the menu.

## Pivots

```dart
final pivot = fitGridPivot<Sale>(
  sales,
  rows: [FitGridPivotDimension(id: 'region', label: 'Region', keyOf: (s) => s.region)],
  columns: FitGridPivotDimension(id: 'q', label: 'Quarter', keyOf: (s) => s.quarter,
      format: (q) => 'Q$q'),
  values: [
    FitGridPivotValue(id: 'revenue', label: 'Revenue', valueOf: (s) => s.amount),
    FitGridPivotValue(id: 'avg', label: 'Average', valueOf: (s) => s.amount,
        aggregation: FitGridAggregation.average),
    const FitGridPivotValue.count(),
  ],
);

FitGrid<FitGridPivotRow>(rows: pivot.rows, columns: pivot.columns);
```

The result is ordinary rows and columns — sortable, filterable, exportable —
with per-row totals across headings and grand totals in the footer. Totals are
reduced from the source rows, so an average is never an average of averages.
Aggregations: `sum`, `count`, `average`, `min`, `max`. Build the pivot when its
inputs change, not in `build`.

## Saving the layout

```dart
// When the user leaves:
prefs.setString('grid', jsonEncode(controller.saveState().toJson()));

// When they come back:
controller.restoreState(
  FitGridSavedState.fromJson(jsonDecode(prefs.getString('grid')!)),
);
```

Saved: column order, visibility, pins, dragged widths, sort, structured
filters, search, and page. Not saved: rows, selection and focus, which describe
the data rather than the view. Restoring is forgiving — removed columns are
skipped, columns added since keep their declared place, malformed JSON degrades
to defaults. A "reset" button is `restoreState` of a state saved at first build.

---

## Accessibility

Painted cells reach the accessibility tree: the render object builds a `table`
node with one `row` per visible row and one `cell` per visible cell, labelled
with the column name and the value, recycled across updates and bounded by the
viewport — a 20,000-row grid emits under two hundred nodes.

```dart
FitGridColumn<Event>(
  id: 'when',
  label: 'Updated',
  value: (e) => e.relative,           // painted: "3m"
  semanticValue: (e) => e.spokenTime, // spoken:  "3 minutes ago"
)
```

Headers announce as headers with their sort state and priority; selected rows
and cells in a range announce as selected; activating a cell edits it or opens
its detail panel. Menu buttons, chevrons and handles carry labels.

## The controller

`FitGridController<T>(rows:, columns:, selectionMode:)` — each part is a
`ChangeNotifier` you can listen to on its own.

| Part | Key members |
|---|---|
| `data` | `rows`, `view` (filtered + sorted), `length`, `sortKeys`, `directionOf(id)`, `sortPriorityOf(id)`, `moveRow(from, to)` |
| `columns` | `columns`, `visible`, `byId`, `setWidth`, `autoSize`, `autoSizeAll`, `clearAllWidths`, `setVisible`, `showAll`, `setFreeze`, `move`, `applyLayout` |
| `selection` | `mode`, `selected`, `sorted`, `contains`, `select`, `selectRange`, `toggle`, `clear` |
| `focus` | `rowIndex`, `columnId`, `moveTo`, `clear` |
| `filter` | `query`, `caseSensitive`, `setFilter`, `filters`, `filtersJson`, `setColumnFilter`, `filteredColumnIds`, `clearColumnFilters`, `clear` |
| `grouping` | `groups`, `tree`, `toggle`, `setExpanded`, `expandAll`, `collapseAll`, `reset` |
| `pagination` | `enabled`, `pageSize`, `pageSizeOptions`, `pageIndex`, `pageCount`, `first/previous/next/last`, `revealRow` |
| `range` | `range`, `select`, `extendTo`, `isMultiCell`, `clear` |
| `details` | `expanded`, `toggle`, `setExpanded`, `collapseAll` |
| `editing` | `rowIndex`, `columnId`, `begin`, `cancel`, `error` |
| `history` | `canUndo`, `canRedo`, `undoDepth`, `clear` |

On the controller itself: `toggleSort`, `setSort`, `clearSort`, `scrollTo`,
`export`, `moveColumnBefore`, `saveState`, `restoreState`, `undo`, `redo`,
`dispose`.

Without a controller, the grid owns one and syncs it from `rows` and `columns`.
With one, those two arguments are ignored — update `controller.data.rows` and
`controller.columns.columns` instead.

## FitGrid parameters

| Parameter | Default | |
|---|---|---|
| `rows`, `columns` | `[]` | The data, when there is no controller. |
| `controller` | `null` | External state. |
| `dataSource` | `null` | Server-backed rows. |
| `theme` | `null` | See [Theming](#theming-and-colours). |
| `rowHeight` | `null` | `FitGridRowHeight.fixed` / `.contentSized`. |
| `striped` | `true` | Alternate row backgrounds. |
| `hoverHighlight` | `true` | Wash the row under the pointer. |
| `stretchColumnsToFill` | `true` | Share leftover width among columns. |
| `showHeader`, `showFooter` | `true` | The header row; the aggregate footer. |
| `resizableColumns` | `true` | Drag handles on header dividers. |
| `reorderableColumns` | `false` | Drag headers to move columns. |
| `multiSort` | `true` | Shift+click adds a sort key. |
| `showColumnMenu`, `columnMenuBuilder` | `false`, `null` | The per-header menu. |
| `columnGroups` | `[]` | Header bands. |
| `stickyGroupHeaders` | `true` | Pin group headers while scrolling. |
| `selectionMode`, `showSelectionColumn`, `onSelectionChanged` | `null`, `false`, `null` | Row selection. |
| `cellSelection` | `false` | Ranges, paste, fill, Delete. |
| `enableCopy`, `enablePaste`, `enableUndo` | `true` | Clipboard and history. |
| `editTrigger` | `doubleTap` | What opens an editor. |
| `keyboardNavigation`, `autofocus`, `focusNode` | `true`, `false`, `null` | Keyboard. |
| `reorderableRows`, `onRowReorder` | `false`, `null` | Row drag handles. |
| `detailBuilder`, `detailRowHeight`, `detailHeight`, `rowKey` | — | Detail rows; row identity. |
| `paginated`, `pageSize`, `pagerBuilder` | `false`, `null`, `null` | Paging. |
| `onLoadMore`, `hasMoreRows`, `loadMoreThreshold`, `loadingRowCount` | `null`, `true`, `10`, `3` | Infinite scroll. |
| `rowColor` | `null` | Per-row background. |
| `contextMenuBuilder` | `null` | Right-click / long-press menu. |
| `emptyState`, `loadingState` | `null` | Shown with no rows / while a source loads. |
| `onRowTap`, `onCellTap` | `null` | Tap callbacks, with global indices. |
| `overscanRows` | `2` | Rows laid out beyond the viewport. |

## Testing

Cells are painted, so **`find.text` never matches a cell** (header labels are
widgets, so it does match those). The helpers ship in the package and have **no
dependency on `flutter_test`**:

```dart
import 'package:fitgrid_table/testing.dart';

expect(fitGridCellText(row: 0, column: 1), 'Amit');
expect(fitGridRowText(1), ['Bernadette', 'Designer', '£72,000']);
expect(fitGridCellSpec(row: 0, column: 2).visual?.kind, FitGridVisualKind.bar);
expect(fitGridRowCount(), 1000);
expect(fitGridLaidOutRowCount(), lessThan(40));      // virtualization holds
expect(fitGridSemanticsNodeCount(), lessThan(200));  // ...and so does the a11y tree
expect(fitGridColumnLeft('name'), 0);                // the pinned column stayed put
expect(fitGridColumnIds(), ['name', 'role', 'salary']);
```

Two things catch people out. On a grid with editable columns, a single tap waits
out the double-tap window — `await tester.pump(const Duration(milliseconds:
400))` after `tapAt` before asserting on selection. And keyboard shortcuts act
only while the grid has focus — use `autofocus: true` or tap a cell first.

## Performance

```
flutter test benchmark/frame_benchmark.dart
flutter test benchmark/measurement_benchmark.dart
```

```
Column measurement, sampled auto     1,000 rows   0.9 ms
                                 1,000,000 rows  25.2 ms
Row measurement, nothing wraps   1,000,000 rows   0.0 ms
Row measurement, one wrapping column 10,000 rows 178.7 ms
```

To keep it that way:

- **Keep the rows list's identity stable.** Caches are keyed on it; a new list
  each `build` re-measures every column every frame.
- Build themes, columns and pivots when their inputs change, not per frame.
- Keep `cellStyle`, `icon`, `rowColor` and `value` callbacks cheap and pure.
- Paint rather than build: reach for `cellBuilder` only for interactive cells.
- Wrapping rows (`contentSized` + `maxLines`) are the one real cost: clamp the
  column's width, or prefer `fixed` row heights on very large datasets.

## Gotchas

- **Edits change nothing?** The grid never writes rows: your `onCommit` must
  update your data and hand it back (`controller.data.rows = ...`).
- **An edit lands on the wrong row after sorting?** The index is into the
  displayed rows; find the row by its id.
- **Detail panels or undo lose their row after a refresh?** Set `rowKey` when
  rows are recreated as new objects.
- **Numbers sort as text?** Add a `comparator`.
- **`find.text` finds nothing?** Use `testing.dart`.
- **A widget or chart column is too narrow?** Give it a `fixed` width.
- **Nothing wraps?** `maxLines` needs `FitGridRowHeight.contentSized()` and a
  width that constrains the text.
- **Column arguments ignored?** With a controller, update the controller.
- **A column's value reads from `controller.data.view`?** Make it
  `searchable: false`: the search builds the view, so it cannot read from it.

## For AI agents

The package ships an [agent skill](https://dart.dev/tools/pub/package-skills)
with its rules and a working example for every feature. In a project that
depends on it:

```sh
dart run skills@ get
```

## Example app

Run it in your browser: **[fitgrid-e734.vercel.app/demo](https://fitgrid-e734.vercel.app/demo/)**.

`example/` is a gallery: two designs over the same data, pagination three ways,
widget cells, conditional formatting, sizing with live timings, lazy loading,
controller patterns, spreadsheet editing, columns and filters with saved
layouts, pivot and export, detail rows, infinite scroll, reorderable rows,
charts, grouping and tree rows, and a playground with every switch. Each page
explains what to copy and what to avoid.

## Roadmap

- **v0.2** — a drag-and-drop pivot designer, PDF export and printing
- **v1.0** — responsive fallbacks, a docs site

## License

MIT
