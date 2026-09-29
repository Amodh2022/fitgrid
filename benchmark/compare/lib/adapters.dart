// One adapter per grid, each set up the way its own documentation shows —
// typed cell values, the grid's own column types — so no grid is handicapped
// by a slow comparison it would not have in a real app.

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:trina_grid/trina_grid.dart';

import 'data.dart';

abstract class GridAdapter {
  /// Display name, with the package version.
  String get name;

  /// Builds the grid's own row model from [rows]. Timed on its own: it is the
  /// app's cost of using the grid, and where per-cell objects cost memory.
  void prepare(List<Order> rows);

  Widget build();

  /// Sorts by [field]; completes when the grid's model is in the new order.
  Future<void> sort(String field, bool ascending);

  /// The order id at [index] in the grid's current (sorted) model.
  int idAt(int index);

  void dispose() {}
}

// ---------------------------------------------------------------- fitgrid

class FitGridAdapter extends GridAdapter {
  FitGridAdapter(this.version);

  final String version;
  late FitGridController<Order> _controller;

  @override
  String get name => 'fitgrid $version';

  @override
  void prepare(List<Order> rows) {
    _controller = FitGridController<Order>(
      rows: rows,
      columns: <FitGridColumn<Order>>[
        FitGridColumn<Order>(
          id: 'id',
          label: 'Order',
          value: (o) => '#${o.id}',
          sortable: true,
          sortValue: (o) => o.id,
        ),
        FitGridColumn<Order>(
          id: 'customer',
          label: 'Customer',
          value: (o) => o.customer,
          sortable: true,
        ),
        FitGridColumn<Order>(
          id: 'region',
          label: 'Region',
          value: (o) => o.region,
          sortable: true,
        ),
        FitGridColumn<Order>(
          id: 'status',
          label: 'Status',
          value: (o) => o.status,
          sortable: true,
        ),
        FitGridColumn<Order>(
          id: 'amount',
          label: 'Amount',
          value: (o) => formatAmount(o.amount),
          alignment: FitGridAlignment.end,
          sortable: true,
          sortValue: (o) => o.amount,
        ),
        FitGridColumn<Order>(
          id: 'placed',
          label: 'Placed',
          value: (o) => formatDate(o.placed),
          sortable: true,
          sortValue: (o) => o.placed,
        ),
        FitGridColumn<Order>(
          id: 'note',
          label: 'Note',
          value: (o) => o.note,
          width: const FitGridColumnWidth.fixed(260),
        ),
      ],
    );
  }

  @override
  Widget build() => FitGrid<Order>(controller: _controller);

  @override
  Future<void> sort(String field, bool ascending) {
    _controller.setSort(<FitGridSortKey>[
      FitGridSortKey(
        field,
        ascending
            ? FitGridSortDirection.ascending
            : FitGridSortDirection.descending,
      ),
    ]);
    return _controller.data.whenSorted();
  }

  @override
  int idAt(int index) => _controller.data.view[index].id;

  @override
  void dispose() => _controller.dispose();
}

// ------------------------------------------------------------- Syncfusion

class _OrderSource extends DataGridSource {
  _OrderSource(List<Order> orders)
    : _rows = List<DataGridRow>.generate(orders.length, (i) {
        final o = orders[i];
        // Typed values, as Syncfusion's docs show: the default compare then
        // uses int / DateTime / String compareTo directly.
        return DataGridRow(
          cells: <DataGridCell>[
            DataGridCell<int>(columnName: 'id', value: o.id),
            DataGridCell<String>(columnName: 'customer', value: o.customer),
            DataGridCell<String>(columnName: 'region', value: o.region),
            DataGridCell<String>(columnName: 'status', value: o.status),
            DataGridCell<int>(columnName: 'amount', value: o.amount),
            DataGridCell<DateTime>(columnName: 'placed', value: o.placed),
            DataGridCell<String>(columnName: 'note', value: o.note),
          ],
        );
      }, growable: false);

  final List<DataGridRow> _rows;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: <Widget>[
        for (final cell in row.getCells())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: cell.columnName == 'amount'
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(switch (cell.value) {
                final DateTime d => formatDate(d),
                final int n when cell.columnName == 'amount' => formatAmount(n),
                final Object? v => '$v',
              }, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
    );
  }
}

class SyncfusionAdapter extends GridAdapter {
  SyncfusionAdapter(this.version);

  final String version;
  late _OrderSource _source;

  @override
  String get name => 'Syncfusion DataGrid $version';

  @override
  void prepare(List<Order> rows) => _source = _OrderSource(rows);

  static GridColumn _column(String name, String label, {double? width}) =>
      GridColumn(
        columnName: name,
        width: width ?? double.nan,
        label: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label),
        ),
      );

  @override
  Widget build() => SfDataGrid(
    source: _source,
    allowSorting: true,
    columnWidthMode: ColumnWidthMode.fill,
    columns: <GridColumn>[
      _column('id', 'Order'),
      _column('customer', 'Customer'),
      _column('region', 'Region'),
      _column('status', 'Status'),
      _column('amount', 'Amount'),
      _column('placed', 'Placed'),
      _column('note', 'Note', width: 260),
    ],
  );

  @override
  Future<void> sort(String field, bool ascending) {
    _source.sortedColumns
      ..clear()
      ..add(
        SortColumnDetails(
          name: field,
          sortDirection: ascending
              ? DataGridSortDirection.ascending
              : DataGridSortDirection.descending,
        ),
      );
    return _source.sort();
  }

  @override
  int idAt(int index) =>
      _source.effectiveRows[index].getCells().first.value as int;

  @override
  void dispose() => _source.dispose();
}

// -------------------------------------------------- TrinaGrid / PlutoGrid

class TrinaAdapter extends GridAdapter {
  TrinaAdapter(this.version);

  final String version;
  late List<TrinaColumn> _columns;
  late List<TrinaRow> _rows;
  TrinaGridStateManager? _state;

  @override
  String get name => 'TrinaGrid $version';

  @override
  void prepare(List<Order> rows) {
    _columns = <TrinaColumn>[
      TrinaColumn(title: 'Order', field: 'id', type: TrinaColumnType.number()),
      TrinaColumn(
        title: 'Customer',
        field: 'customer',
        type: TrinaColumnType.text(),
      ),
      TrinaColumn(
        title: 'Region',
        field: 'region',
        type: TrinaColumnType.text(),
      ),
      TrinaColumn(
        title: 'Status',
        field: 'status',
        type: TrinaColumnType.text(),
      ),
      TrinaColumn(
        title: 'Amount',
        field: 'amount',
        type: TrinaColumnType.number(),
        formatter: (v) => formatAmount(v as int),
      ),
      // Trina's date type holds its value as a formatted string.
      TrinaColumn(
        title: 'Placed',
        field: 'placed',
        type: TrinaColumnType.date(),
      ),
      TrinaColumn(
        title: 'Note',
        field: 'note',
        type: TrinaColumnType.text(),
        width: 260,
      ),
    ];
    _rows = List<TrinaRow>.generate(rows.length, (i) {
      final o = rows[i];
      return TrinaRow(
        cells: <String, TrinaCell>{
          'id': TrinaCell(value: o.id),
          'customer': TrinaCell(value: o.customer),
          'region': TrinaCell(value: o.region),
          'status': TrinaCell(value: o.status),
          'amount': TrinaCell(value: o.amount),
          'placed': TrinaCell(value: formatDate(o.placed)),
          'note': TrinaCell(value: o.note),
        },
      );
    }, growable: false);
  }

  @override
  Widget build() => TrinaGrid(
    columns: _columns,
    rows: _rows,
    onLoaded: (event) => _state = event.stateManager,
  );

  @override
  Future<void> sort(String field, bool ascending) async {
    final state = _state!;
    final column = state.refColumns.firstWhere((c) => c.field == field);
    ascending ? state.sortAscending(column) : state.sortDescending(column);
  }

  @override
  int idAt(int index) => _state!.refRows[index].cells['id']!.value as int;
}

class PlutoAdapter extends GridAdapter {
  PlutoAdapter(this.version);

  final String version;
  late List<PlutoColumn> _columns;
  late List<PlutoRow> _rows;
  PlutoGridStateManager? _state;

  @override
  String get name => 'PlutoGrid $version';

  @override
  void prepare(List<Order> rows) {
    _columns = <PlutoColumn>[
      PlutoColumn(title: 'Order', field: 'id', type: PlutoColumnType.number()),
      PlutoColumn(
        title: 'Customer',
        field: 'customer',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Region',
        field: 'region',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'amount',
        type: PlutoColumnType.number(),
        formatter: (v) => formatAmount(v as int),
      ),
      PlutoColumn(
        title: 'Placed',
        field: 'placed',
        type: PlutoColumnType.date(),
      ),
      PlutoColumn(
        title: 'Note',
        field: 'note',
        type: PlutoColumnType.text(),
        width: 260,
      ),
    ];
    _rows = List<PlutoRow>.generate(rows.length, (i) {
      final o = rows[i];
      return PlutoRow(
        cells: <String, PlutoCell>{
          'id': PlutoCell(value: o.id),
          'customer': PlutoCell(value: o.customer),
          'region': PlutoCell(value: o.region),
          'status': PlutoCell(value: o.status),
          'amount': PlutoCell(value: o.amount),
          'placed': PlutoCell(value: formatDate(o.placed)),
          'note': PlutoCell(value: o.note),
        },
      );
    }, growable: false);
  }

  @override
  Widget build() => PlutoGrid(
    columns: _columns,
    rows: _rows,
    onLoaded: (event) => _state = event.stateManager,
  );

  @override
  Future<void> sort(String field, bool ascending) async {
    final state = _state!;
    final column = state.refColumns.firstWhere((c) => c.field == field);
    ascending ? state.sortAscending(column) : state.sortDescending(column);
  }

  @override
  int idAt(int index) => _state!.refRows[index].cells['id']!.value as int;
}
