import 'dart:convert';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<FitGridColumn<Employee>> savedColumns() => <FitGridColumn<Employee>>[
  for (final column in columns())
    column.copyWith(
      sortable: true,
      filter: column.id == 'salary'
          ? FitGridFilterSpec<Employee>.number((e) => e.salary)
          : const FitGridFilterSpec.text(),
    ),
];

void main() {
  FitGridController<Employee> make() {
    final controller = FitGridController<Employee>(
      rows: makeRows(100),
      columns: savedColumns(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  FitGridController<Employee> customised() {
    final controller = make();
    controller
      ..moveColumnBefore('salary', 'name')
      ..columns.setVisible('role', false)
      ..columns.setFreeze('name', FitGridFreeze.start)
      ..columns.setWidth('salary', 140)
      ..setSort(const <FitGridSortKey>[
        FitGridSortKey('salary', FitGridSortDirection.descending),
        FitGridSortKey('name', FitGridSortDirection.ascending),
      ])
      ..filter.setFilter(
        'salary',
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.lessThan,
          value: 50050,
        ),
      )
      ..filter.query = 'Person'
      ..pagination.enabled = true
      ..pagination.pageSize = 10
      ..pagination.pageIndex = 2;
    return controller;
  }

  test('a saved state survives JSON unchanged', () {
    final saved = customised().saveState();
    final json = jsonDecode(jsonEncode(saved.toJson())) as Map;
    expect(FitGridSavedState.fromJson(json.cast<String, Object?>()), saved);
  });

  test('restoring puts the view back on a fresh controller', () {
    final saved = customised().saveState();
    final fresh = make()..pagination.enabled = true;
    fresh.restoreState(saved);

    expect(fresh.columns.columns.map((c) => c.id), <String>[
      'salary',
      'name',
      'role',
    ]);
    // Pinned columns are pulled to the edge; role is hidden.
    expect(fresh.columns.visible.map((c) => c.id), <String>['name', 'salary']);
    expect(fresh.columns.widthOverrides, <String, double>{'salary': 140});
    expect(fresh.data.sortKeys.first.columnId, 'salary');
    expect(fresh.filter.filters.keys, <String>['salary']);
    expect(fresh.filter.query, 'Person');
    expect(fresh.data.length, 50);
    expect(fresh.data.view.first.salary, 50049);
    expect(fresh.pagination.pageSize, 10);
    expect(fresh.pagination.pageIndex, 2);
  });

  test('columns the saved order does not know keep their place', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(3),
      columns: <FitGridColumn<Employee>>[
        ...savedColumns(),
        FitGridColumn<Employee>(id: 'added', label: 'New', value: (_) => ''),
      ],
    );
    addTearDown(controller.dispose);
    // Saved before 'added' existed, with 'salary' moved first — and with a
    // column that has since been removed.
    controller.restoreState(
      const FitGridSavedState(
        columnOrder: <String>['salary', 'gone', 'name', 'role'],
      ),
    );
    expect(controller.columns.columns.map((c) => c.id), <String>[
      'salary',
      'name',
      'role',
      'added',
    ]);
  });

  test('stale sort keys and filters are dropped, not thrown on', () {
    final controller = make();
    controller.restoreState(
      const FitGridSavedState(
        sort: <FitGridSortKey>[
          FitGridSortKey('gone', FitGridSortDirection.ascending),
          FitGridSortKey('name', FitGridSortDirection.descending),
        ],
        filters: <String, FitGridColumnFilter>{
          'gone': FitGridColumnFilter(
            operator: FitGridFilterOperator.equals,
            value: 'x',
          ),
        },
      ),
    );
    expect(controller.data.sortKeys, const <FitGridSortKey>[
      FitGridSortKey('name', FitGridSortDirection.descending),
    ]);
    expect(controller.filter.filters, isEmpty);
  });

  test('malformed JSON degrades to defaults', () {
    final state = FitGridSavedState.fromJson(<String, Object?>{
      'columnOrder': 'not a list',
      'frozen': <String, Object?>{'name': 'sideways'},
      'widths': <String, Object?>{'name': 'wide', 'role': 80},
      'sort': <Object?>[
        <String, Object?>{'column': 'name', 'dir': 'up'},
        42,
      ],
      'pageSize': 'ten',
    });
    expect(state.columnOrder, isEmpty);
    expect(state.frozenColumns, isEmpty);
    expect(state.columnWidths, <String, double>{'role': 80});
    expect(state.sort, isEmpty);
    expect(state.pageSize, isNull);
  });

  test('restoring an empty state leaves the grid alone', () {
    final controller = make()..columns.setVisible('role', false);
    controller.restoreState(const FitGridSavedState());
    expect(controller.columns.byId('role')!.visible, isFalse);
  });
}
