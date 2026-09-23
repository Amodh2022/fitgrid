# fitgrid_table recipes

Short, working patterns for the opt-in features. Every one of them is off
until you ask for it.

## Multi-column sort

```dart
FitGrid<T>(controller: controller) // Shift+click a second header
controller.setSort(const [
  FitGridSortKey('dept', FitGridSortDirection.ascending),
  FitGridSortKey('salary', FitGridSortDirection.descending),
]);
controller.clearSort();
```

## Filters

```dart
FitGridColumn(id: 'role', label: 'Role', value: (e) => e.role,
    filter: const FitGridFilterSpec.values());          // checklist
FitGridColumn(id: 'hired', label: 'Hired', value: (e) => e.hiredText,
    filter: FitGridFilterSpec.date((e) => e.hired));    // by day

controller.filter.setFilter('salary', const FitGridColumnFilter(
  operator: FitGridFilterOperator.between, value: 50000, value2: 90000));
controller.filter.query = 'smith';                      // free-text search
await showFitGridFilterDialog(context, controller, 'salary');
```

For a free-form predicate that does not need a UI, use
`controller.filter.setColumnFilter(id, (row) => ...)`. It cannot be saved or
sent to a server.

## Ranges, paste, fill, undo

```dart
FitGrid<T>(controller: controller, cellSelection: true)
controller.range.range = const FitGridCellRange(
  anchorRow: 0, anchorColumnId: 'a', extentRow: 4, extentColumnId: 'c');
controller.undo();
controller.redo();
```

Paste, Delete and the fill handle only write to columns with an `editor`.

## Detail rows

```dart
FitGrid<Order>(
  rows: orders,
  columns: columns,
  rowKey: (o) => o.id,
  detailBuilder: (context, order, index) => OrderLines(order),
  detailHeight: (order, index) => 80.0 + 32 * order.lines.length,
)
controller.details.toggle(order.id); // keyed by rowKey
```

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

## Row reordering

```dart
FitGrid<Task>(
  rows: tasks,
  columns: columns,
  reorderableRows: true,
  onRowReorder: (from, to) => setState(() {
    final task = tasks.removeAt(from);
    tasks.insert(to, task);
  }),
)
```

Without `onRowReorder` the grid reorders `controller.data` itself. Reordering
is off while sorted or grouped.

## Grouping and header bands

```dart
controller.grouping.groups = [FitGridGroup(keyOf: (e) => e.department)];
controller.grouping.tree = FitGridTree(childrenOf: (e) => e.reports);
FitGrid<T>(columnGroups: const [
  FitGridColumnGroup(id: 'q1', label: 'Q1', columnIds: ['jan', 'feb', 'mar']),
])
```

## Charts in cells

```dart
visual: FitGridCellVisual.bar((s) => s.change),                // from zero
visual: FitGridCellVisual.progress((t) => t.done / t.total),
visual: FitGridCellVisual.sparkline((s) => s.closes, filled: true),
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

## Export

```dart
final data = controller.export(selectedOnly: false); // what is on screen
final csv = fitGridToCsv(data);
final Uint8List xlsx = fitGridToXlsx(data, sheetName: 'Report');
```

## Saved layouts

```dart
final json = jsonEncode(controller.saveState().toJson());
controller.restoreState(
  FitGridSavedState.fromJson(jsonDecode(json) as Map<String, Object?>),
);
```

## Data sources

```dart
final source = FitGridAsyncDataSource<Order>(
  pageSize: 100,
  fetch: (request) async {
    final page = await api.orders(
      offset: request.offset,
      limit: request.limit,
      sort: request.sortKeys,     // every sort key, highest priority first
      filters: request.filters,   // FitGridColumnFilter.toJson() by column id
      query: request.query,
    );
    return FitGridPageResult(rows: page.rows, totalCount: page.total);
  },
);
FitGrid<Order>(dataSource: source, columns: columns);
```
