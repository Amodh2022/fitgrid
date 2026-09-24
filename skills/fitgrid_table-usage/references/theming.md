# Theming fitgrid_table

Every colour, text style, size, divider and icon lives in one immutable value:
`FitGridThemeData`.

## Resolution order

1. `FitGrid(theme: ...)`.
2. The nearest `FitGridTheme(data: ..., child: ...)` ancestor.
3. `FitGridThemeData.fromTheme(Theme.of(context))`.

With nothing set, a grid follows the app's colour scheme, text theme and
brightness.

## What `fromTheme` derives

`FitGridThemeData.fromTheme(theme, density: FitGridDensity.standard)`:

| Grid colour | Light | Dark |
|---|---|---|
| `headerBackground` | `surfaceContainerLow` | `surface` + 6% `surfaceTint` |
| `headerForeground`, `sortIconColor` | `onSurfaceVariant` | same |
| `headerTextStyle` | `labelLarge`, w600, `onSurfaceVariant` | same |
| `rowBackground` | `surface` | `surface` |
| `alternateRowBackground` | `surfaceContainerLowest` | `surface` + 2.5% `onSurface` |
| `cellTextStyle` | `bodyMedium`, `onSurface` | same |
| `rowDivider`, `columnDivider` | `outlineVariant` 70% | `outlineVariant` 28% |
| `border` | `outlineVariant` 80% | 40% |
| `hoverBackground` | `onSurface` 4% | same |
| `selectedBackground` | `primary` 10% | 18% |
| `focusOutline` | `primary` | same |
| `placeholderForeground` | `onSurfaceVariant` 60% | same |
| `tooltipBackground` / `tooltipForeground` | `inverseSurface` / `onInverseSurface` | same |
| `searchHighlight` | `tertiary` 28% | 38% |
| `frozenShadow` | black 16% | black 45% |
| `groupHeaderBackground` | `surfaceContainer` | `surface` + 6% `onSurface` |

## Density

| Density | Row height | Cell padding h/v |
|---|---|---|
| `compact` | 34 | 10/4 |
| `standard` | 44 | 14/8 |
| `comfortable` | 56 | 18/14 |

Header height is row height + 4. `rowHeight`, `headerHeight`, `cellPadding`,
`headerPadding` override outright.

## Every property

**Surfaces and text:** `headerBackground` (also footer and pager),
`headerForeground` (header glyphs, chevrons), `headerTextStyle`,
`rowBackground` (rows and the grid fill), `alternateRowBackground` (odd rows
when `striped`), `cellTextStyle` (every painted cell), `groupHeaderBackground`,
`groupHeaderTextStyle` (null → cell style), `placeholderForeground` (empty
state, dimmed glyphs, skeleton rows).

**State colours:** `hoverBackground`, `selectedBackground` (wins over
`rowColor`), `focusOutline` (focus ring, range outline, fill handle, drop
line), `rangeSelectionBackground` (null → `focusOutline` 12%),
`searchHighlight`, `sortIconColor`, `tooltipBackground`, `tooltipForeground`,
`detailBackground` (null → `groupHeaderBackground`), `chartColor` (null →
`focusOutline`), `chartNegativeColor` (null → a red for both modes).

**Borders and dividers:** `border`, `borderRadius` (12), `dividerThickness`
(1), `rowDivider`, `columnDivider`, `rowDividerDash` (null solid; `[3, 2]`
dashed), `columnDividerExtent` (null full height; `12` ticks centred per row),
`headerDividerExtent` (null full height; `34` short), `frozenShadow`,
`frozenShadowExtent` (8).

**Sizes:** `density`, `rowHeight`, `headerHeight`, `cellPadding`,
`headerPadding`, `minColumnWidth` (24), `resizeHandleWidth` (8),
`resizeTouchTargetWidth` (32), `fadeExtent` (28), `tooltipMaxWidth` (360),
`tooltipBorderRadius` (6), `sortIconSize` (18), `cellIconSize` (16),
`cellIconGap` (6), `focusRingWidth` (2), `nestingIndent` (20),
`selectionColumnWidth` (44), `rowDragHandleWidth` (32), `fillHandleSize` (7).

**Icons:** `sortAscendingIcon`, `sortDescendingIcon`, `sortUnsortedIcon`,
`resizeGripIcon`, `checkboxIcon`, `checkboxCheckedIcon`,
`checkboxIndeterminateIcon`, `expandedIcon`, `collapsedIcon`, `columnMenuIcon`,
`filterIcon`, `filterActiveIcon`, `rowDragHandleIcon`.

## Recipes

Adjust the derived theme:

```dart
final gridTheme = FitGridThemeData.fromTheme(Theme.of(context)).copyWith(
  headerBackground: const Color(0xFF0F172A),
  headerTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
  selectedBackground: const Color(0x1A2563EB),
  focusOutline: const Color(0xFF2563EB),
  borderRadius: BorderRadius.circular(8),
);
```

Hand-picked light and dark palettes:

```dart
final gridTheme = Theme.of(context).brightness == Brightness.dark
    ? darkGridTheme
    : lightGridTheme;
```

Brand fonts (layout is measured in these):

```dart
theme.copyWith(
  headerTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
      fontWeight: FontWeight.w600),
  cellTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
)
```

Matching an existing design system:

```dart
FitGridThemeData.fromTheme(Theme.of(context)).copyWith(
  headerBackground: tokens.tableHeaderBg,
  rowBackground: tokens.tableWash,
  rowDivider: tokens.rowDivider,
  columnDivider: tokens.cellDivider,
  border: tokens.subtleBorder,
  borderRadius: BorderRadius.circular(6),
  rowDividerDash: const [3, 2],
  columnDividerExtent: 12,
  headerDividerExtent: 34,
  sortAscendingIcon: Icons.arrow_drop_up,
  sortDescendingIcon: Icons.arrow_drop_down,
  sortUnsortedIcon: Icons.arrow_drop_up,
  headerHeight: 50,
  rowHeight: 48,
  cellPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
)
// and on the grid: striped: false, hoverHighlight: false,
// resizableColumns: false, pagerBuilder: (context, p) => MyFooter(p)
```

- No lines: `rowDivider` and `columnDivider` transparent.
- Borderless in a card: `border: Colors.transparent`,
  `borderRadius: BorderRadius.zero`.
- A themed section of the app: `FitGridTheme(data: ..., child: ...)`.
- One custom header cell: `FitGridColumn.headerBuilder`.
- Data-driven colour: `rowColor: (row, i) => ...`, `cellStyle: (row, i) =>
  ...`, `icon`/`iconColor` — return shared `const` values; they run per
  visible cell per paint.
