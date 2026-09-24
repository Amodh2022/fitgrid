# fitgrid_table recipes

Short, working patterns for each feature. Everything beyond a plain grid is
opt-in. Theming is in [theming.md](theming.md).

## Column widths and row heights

```dart
FitGridColumnWidth.auto()                   // measure content (default)
FitGridColumnWidth.auto(min: 80, max: 400)
FitGridColumnWidth.auto(sampleSize: 50)     // measure more candidates
FitGridColumnWidth.auto(measureAllRows: true)
FitGridColumnWidth.fixed(120)               // widget and chart columns
FitGridColumnWidth.flex(2, min: 100)        // share leftover space
FitGridColumnWidth.fitHeader(min: 72)

FitGrid(rowHeight: const FitGridRowHeight.fixed(48))
FitGrid(rowHeight: const FitGridRowHeight.contentSized(min: 40, max: 120)) // + maxLines
FitGrid(stretchColumnsToFill: false)       // keep honest widths

controller.columns.setWidth('name', 240);
controller.columns.autoSize('name');
controller.columns.setFreeze('name', FitGridFreeze.start);
```

## Conditional formatting and overflow

```dart
FitGridColumn(
  id: 'amount', label: 'Amount', value: (i) => i.amountText,
  cellStyle: (i, _) => i.amount > 10000 ? highPay : null,
  icon: (i, _) => i.flagged ? Icons.flag_rounded : null,
  iconColor: (i, _) => Colors.orange,
  overflow: FitGridOverflow.tooltipOnTruncate,   // ellipsis, fade, clip
)
FitGrid(rowColor: (i, index) => i.overdue ? Colors.red.shade50 : null)
```

## Widget cells

```dart
FitGridColumn<Employee>(
  id: 'actions', label: 'Actions', value: (e) => e.name,
  width: const FitGridColumnWidth.fixed(120),
  cellBuilder: (context, e, rowIndex) => IconButton(
    icon: const Icon(Icons.edit_outlined), onPressed: () => edit(e)),
)
```

## Charts in cells

```dart
visual: FitGridCellVisual.bar((s) => s.change),                 // from zero; min/max optional
visual: FitGridCellVisual.progress((t) => t.done),              // 0..1
visual: FitGridCellVisual.sparkline((s) => s.closes, filled: true), // text hidden, still the value
```

## Sorting

```dart
controller.toggleSort('salary');                 // a click
controller.toggleSort('name', additive: true);   // a Shift+click
controller.setSort(const [
  FitGridSortKey('dept', FitGridSortDirection.ascending),
  FitGridSortKey('salary', FitGridSortDirection.descending),
]);
controller.clearSort();
FitGrid(multiSort: false)                         // no Shift gesture
```

## Search and filters

```dart
controller.filter.query = 'smith';
FitGridColumn(..., filter: const FitGridFilterSpec.text());
FitGridColumn(..., filter: const FitGridFilterSpec.values());          // checklist
FitGridColumn(..., filter: FitGridFilterSpec.number((e) => e.salary));
FitGridColumn(..., filter: FitGridFilterSpec.date((e) => e.hired));    // by day

controller.filter.setFilter('salary', const FitGridColumnFilter(
  operator: FitGridFilterOperator.between, value: 50000, value2: 90000));
controller.filter.setFilter('dept', const FitGridColumnFilter.oneOf({'Design'}));
controller.filter.filtersJson;                                          // for a server
await showFitGridFilterDialog(context, controller, 'salary');
controller.filter.setColumnFilter('salary', (e) => e.salary > 90000);  // no UI, not saved
controller.filter.clearColumnFilters();
```

Operators: contains, notContains, equals, notEquals, startsWith, endsWith,
greaterThan, greaterOrEqual, lessThan, lessOrEqual, between, inList, isEmpty,
isNotEmpty. A filter on a hidden column stops applying until it is shown.

## Column menu and chooser

```dart
FitGrid(showColumnMenu: true,
  columnMenuBuilder: (context, column, defaults) => [...defaults, myItem])
FitGridColumnChooser<T>(controller: controller)   // a toolbar button
await showFitGridColumnDialog(context, controller);
FitGridColumn(..., hideable: false)
```

## Selection

```dart
FitGrid(
  selectionMode: FitGridSelectionMode.multiple,
  showSelectionColumn: true,
  onSelectionChanged: (rows) => setState(() => selected = rows),
)
controller.selection.select([0, 3]);
controller.selection.selected;
```

## Editing

```dart
FitGridEditor<Employee>(
  initialText: (e) => '${e.salary}',
  keyboardType: TextInputType.number,
  validator: (e, text) => int.tryParse(text) == null ? 'Number' : null,
  onCommit: (e, index, text) => update(e.id, int.parse(text)),
  commitOnFocusLoss: true,
)
FitGridEditor<Employee>(                        // a custom editor
  onCommit: save,
  builder: (context, session) => DropdownButton<String>(
    value: session.initialText,
    items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
    onChanged: (r) => session.commit(r!),
  ),
)
FitGrid(editTrigger: FitGridEditTrigger.singleTap) // doubleTap, programmatic
controller.editing.begin(rowIndex, 'salary');
```

## Ranges, paste, fill, undo

```dart
FitGrid<T>(controller: controller, cellSelection: true)
controller.range.range = const FitGridCellRange(
  anchorRow: 0, anchorColumnId: 'a', extentRow: 4, extentColumnId: 'c');
controller.undo();
controller.redo();
controller.history.canUndo;
fitGridFillSeries(['1', '2'], 3);                // ['3', '4', '5']
```

## Grouping, trees, sticky headers, header bands

```dart
controller.grouping.groups = [
  FitGridGroup(keyOf: (e) => e.department, label: (key, rows) => '$key (${rows.length})'),
];
controller.grouping.tree = FitGridTree(childrenOf: (e) => e.reports);
controller.grouping.expandAll();
FitGrid(stickyGroupHeaders: false)               // on by default
FitGrid(columnGroups: const [
  FitGridColumnGroup(id: 'q1', label: 'Q1', columnIds: ['jan', 'feb', 'mar']),
])
```

## Detail rows

```dart
FitGrid<Order>(
  rows: orders, columns: columns,
  rowKey: (o) => o.id,
  detailBuilder: (context, order, index) => OrderLines(order),
  detailHeight: (order, index) => 80.0 + 32 * order.lines.length,
)
controller.details.toggle(order.id);             // keyed by rowKey
```

## Reordering

```dart
FitGrid(reorderableColumns: true)
controller.moveColumnBefore('salary', 'name');

FitGrid<Task>(
  rows: tasks, columns: columns,
  reorderableRows: true,                         // off while sorted or grouped
  onRowReorder: (from, to) => setState(() => tasks.insert(to, tasks.removeAt(from))),
)
```

## Pagination and a custom pager

```dart
FitGrid(paginated: true, pageSize: 25)
controller.pagination
  ..pageSizeOptions = const [10, 25, 50, 100]    // keep pageSize one of these
  ..pageIndex = 3;
controller.scrollTo(603, columnId: 'salary');    // turns the page, then scrolls

FitGrid(
  paginated: true,
  pagerBuilder: (context, p) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text('Showing ${p.firstRowIndex + 1}–${p.endRowIndex} of ${p.rowCount}'),
    IconButton(onPressed: p.hasPrevious ? p.previous : null, icon: const Icon(Icons.chevron_left)),
    IconButton(onPressed: p.hasNext ? p.next : null, icon: const Icon(Icons.chevron_right)),
  ]),
)
```

## Infinite scroll

```dart
FitGrid<Item>(
  rows: items, columns: columns,
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

Rethrow on failure: the grid then waits for the next scroll before retrying.

## Data sources

```dart
final source = FitGridAsyncDataSource<Order>(
  pageSize: 100,
  fetch: (request) async {
    final page = await api.orders(
      offset: request.offset,
      limit: request.limit,
      sort: request.sortKeys,
      filters: request.filters,
      query: request.query,
    );
    return FitGridPageResult(rows: page.rows, totalCount: page.total);
  },
);
FitGrid<Order>(dataSource: source, columns: columns);
source.search(query);                            // the host forwards search
```

## Footer totals, export, clipboard, context menu

```dart
FitGridColumn(..., footerLabel: 'Total', aggregate: (rows) => sum(rows))
final data = controller.export(selectedOnly: false);
final csv = fitGridToCsv(data);
final tsv = fitGridToTsv(data);
final Uint8List xlsx = fitGridToXlsx(data, sheetName: 'Report');
FitGrid(contextMenuBuilder: (context, target) => [
  PopupMenuItem(child: const Text('Delete'), onTap: () => delete(target.selection)),
])
```

## Pivot

```dart
final pivot = fitGridPivot<Sale>(
  sales,
  rows: [FitGridPivotDimension(id: 'region', label: 'Region', keyOf: (s) => s.region)],
  columns: FitGridPivotDimension(id: 'q', label: 'Quarter', keyOf: (s) => s.quarter),
  values: [
    FitGridPivotValue(id: 'rev', label: 'Revenue', valueOf: (s) => s.amount),
    const FitGridPivotValue.count(),
  ],
);
FitGrid<FitGridPivotRow>(rows: pivot.rows, columns: pivot.columns);
```

## Saved layouts

```dart
final json = jsonEncode(controller.saveState().toJson());
controller.restoreState(
  FitGridSavedState.fromJson(jsonDecode(json) as Map<String, Object?>),
);
```

## Controller API

| Part | Key members |
|---|---|
| `data` | `rows`, `view`, `length`, `sortKeys`, `directionOf`, `sortPriorityOf`, `moveRow` |
| `columns` | `columns`, `visible`, `byId`, `setWidth`, `autoSize`, `autoSizeAll`, `setVisible`, `showAll`, `setFreeze`, `move`, `applyLayout` |
| `selection` | `mode`, `selected`, `sorted`, `contains`, `select`, `selectRange`, `toggle`, `clear` |
| `focus` | `rowIndex`, `columnId`, `moveTo`, `clear` |
| `filter` | `query`, `caseSensitive`, `setFilter`, `filters`, `filtersJson`, `setColumnFilter`, `clearColumnFilters`, `clear` |
| `grouping` | `groups`, `tree`, `toggle`, `setExpanded`, `expandAll`, `collapseAll`, `reset` |
| `pagination` | `enabled`, `pageSize`, `pageSizeOptions`, `pageIndex`, `pageCount`, `next`, `previous`, `revealRow` |
| `range` | `range`, `select`, `extendTo`, `isMultiCell`, `clear` |
| `details` | `expanded`, `toggle`, `setExpanded`, `collapseAll` |
| `editing` | `begin`, `cancel`, `error` |
| `history` | `canUndo`, `canRedo`, `undoDepth`, `clear` |

On the controller: `toggleSort`, `setSort`, `clearSort`, `scrollTo`, `export`,
`moveColumnBefore`, `saveState`, `restoreState`, `undo`, `redo`, `dispose`.
