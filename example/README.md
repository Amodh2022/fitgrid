# fitgrid examples

A gallery of small, focused examples. Each page has a **How this works** panel
at the top that says what the example shows, what to copy, and what to avoid.

```sh
cd example
flutter run            # any device; -d chrome or -d linux work well
```

| Page | What it shows | Source |
| --- | --- | --- |
| Two designs, same data | An admin console and a dark trading terminal over the same rows: `FitGridThemeData.fromTheme(...).copyWith(...)`, a subtree `FitGridTheme`, a custom `pagerBuilder`, painted `cellStyle` / `icon` / `rowColor` | [two_designs.dart](lib/screens/two_designs.dart) |
| Widget cells | Avatars, pills, a switch and action buttons as real widgets via `cellBuilder`, built only for the rows on screen (with a live count) | [widget_cells.dart](lib/screens/widget_cells.dart) |
| Pagination | The built-in pager, the built-in pager reworded, a numbered pager from scratch, and paging from outside through the controller | [pagination.dart](lib/screens/pagination.dart) |
| Conditional formatting | `rowColor`, `cellStyle` and painted glyphs over 50k rows, with shared const styles | [formatting.dart](lib/screens/formatting.dart) |
| Column widths & row heights | Every width policy (`fixed`, `fitHeader`, `auto`, `auto(max:)`, `measureAllRows`, `flex`) and every row mode, with the cost of each change measured live | [sizing.dart](lib/screens/sizing.dart) |
| Lazy loading | `FitGridAsyncDataSource` over 250k rows behind a fake server with latency: server-side sort and search, a bounded cache, known and unknown totals | [lazy_loading.dart](lib/screens/lazy_loading.dart), [order.dart](lib/data/order.dart) |
| Controller patterns | Search, filter, hide, sort, select and scroll through `FitGridController`, with a counter showing the page does not rebuild | [controller_patterns.dart](lib/screens/controller_patterns.dart) |
| Grouping & tree rows | One and two-level grouping, group labels with aggregates, and an org chart as `FitGridTree` | [grouping.dart](lib/screens/grouping.dart) |
| Playground | Every switch at once: 100k rows, editing, freezing, RTL, export, density | [playground.dart](lib/screens/playground.dart) |

## The short version

- Keep `rows`, `columns` and the controller in `State`, not in `build()`. The
  grid compares them by identity, and a new list is re-laid-out.
- Change the grid through the controller (`filter`, `columns`, `grouping`,
  `selection`, `pagination`), and listen to only the part you display.
- Choose the cheapest width that is still right: `fixed` and `flex` are never
  measured, and `auto` samples a few rows whatever the row count.
- Use `FitGridRowHeight.fixed` for large data. Save `contentSized` with wrapping
  for when you need it.
- Use painted callbacks (`rowColor`, `cellStyle`, `icon`) for formatting. Save
  `cellBuilder` for columns that need real widgets, and give those a fixed width.
- For remote data, use `FitGridAsyncDataSource`, sort and search on the server,
  and debounce the search box.
