import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<FitGridColumn<Employee>> sortableColumns() => <FitGridColumn<Employee>>[
  for (final column in columns()) column.copyWith(sortable: true),
];

void main() {
  // Roles alternate Engineer/Designer and salaries rise with the index, so
  // "role, then salary descending" has one right answer that neither key
  // produces on its own.
  List<int> salaries(FitGridController<Employee> controller) => <int>[
    for (final row in controller.data.view) row.salary,
  ];

  test('a secondary key breaks the ties of the first', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);

    controller.toggleSort('role');
    controller.toggleSort('salary', additive: true);
    controller.toggleSort('salary', additive: true);

    expect(controller.data.sortKeys, const <FitGridSortKey>[
      FitGridSortKey('role', FitGridSortDirection.ascending),
      FitGridSortKey('salary', FitGridSortDirection.descending),
    ]);
    // Designers (odd indices) first, then engineers, each by salary falling.
    expect(salaries(controller), <int>[
      50005,
      50003,
      50001,
      50004,
      50002,
      50000,
    ]);
  });

  test('a plain toggle replaces a multi-column sort', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);

    controller
      ..toggleSort('role')
      ..toggleSort('salary', additive: true)
      ..toggleSort('name');

    expect(controller.data.sortKeys, const <FitGridSortKey>[
      FitGridSortKey('name', FitGridSortDirection.ascending),
    ]);
  });

  test('cycling an additive key off removes only that key', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);

    controller
      ..toggleSort('role')
      ..toggleSort('salary', additive: true)
      ..toggleSort('role', additive: true) // role: descending, keeps rank 0
      ..toggleSort('role', additive: true); // role: off

    expect(controller.data.sortKeys, const <FitGridSortKey>[
      FitGridSortKey('salary', FitGridSortDirection.ascending),
    ]);
  });

  test('a key flipping direction keeps its priority', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);

    controller
      ..toggleSort('role')
      ..toggleSort('salary', additive: true)
      ..toggleSort('role', additive: true);

    expect(controller.data.sortPriorityOf('role'), 0);
    expect(
      controller.data.directionOf('role'),
      FitGridSortDirection.descending,
    );
  });

  test('setSort drops unknown, unsortable and repeated columns', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: columns(), // role is not sortable here
    );
    addTearDown(controller.dispose);

    controller.setSort(const <FitGridSortKey>[
      FitGridSortKey('gone', FitGridSortDirection.ascending),
      FitGridSortKey('role', FitGridSortDirection.ascending),
      FitGridSortKey('salary', FitGridSortDirection.descending),
      FitGridSortKey('salary', FitGridSortDirection.ascending),
    ]);

    expect(controller.data.sortKeys, const <FitGridSortKey>[
      FitGridSortKey('salary', FitGridSortDirection.descending),
    ]);
    controller.clearSort();
    expect(controller.data.sortKeys, isEmpty);
    expect(salaries(controller).first, 50000);
  });

  test('rows equal on every key keep their supplied order', () {
    final rows = <Employee>[
      for (var i = 0; i < 40; i++) Employee('P$i', 'Same', 1),
    ];
    final controller = FitGridController<Employee>(
      rows: rows,
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);

    controller.toggleSort('salary');
    expect(controller.data.view.map((e) => e.name), rows.map((e) => e.name));
  });

  testWidgets('shift+click on a header adds a sort key and shows priorities', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));

    await tester.tap(find.text('Role'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Salary'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.data.sortKeys.map((k) => k.columnId), <String>[
      'role',
      'salary',
    ]);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(fitGridCellText(row: 0, column: 2), '50001');
  });

  testWidgets('multiSort: false keeps shift+click a plain sort', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: sortableColumns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, multiSort: false)),
    );

    await tester.tap(find.text('Role'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Salary'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.data.sortKeys.single.columnId, 'salary');
  });

  test('a data source receives every key, and old sources the first', () {
    final requests = <FitGridPageRequest>[];
    final source = FitGridAsyncDataSource<Employee>(
      fetch: (request) async {
        requests.add(request);
        return const FitGridPageResult<Employee>(rows: <Employee>[]);
      },
    );
    addTearDown(source.dispose);

    source.sortByKeys(const <FitGridSortKey>[
      FitGridSortKey('role', FitGridSortDirection.ascending),
      FitGridSortKey('salary', FitGridSortDirection.descending),
    ]);
    source.loadWindow(0, 1);
    expect(requests.single.sortKeys.length, 2);
    expect(requests.single.sortColumnId, 'role');

    final legacy = _LegacySource();
    legacy.sortByKeys(const <FitGridSortKey>[
      FitGridSortKey('salary', FitGridSortDirection.descending),
      FitGridSortKey('role', FitGridSortDirection.ascending),
    ]);
    expect(legacy.last, ('salary', FitGridSortDirection.descending));
  });
}

class _LegacySource extends FitGridDataSource<Employee> {
  (String?, FitGridSortDirection)? last;

  @override
  int get rowCount => 0;

  @override
  Employee? rowAt(int index) => null;

  @override
  void sortBy(String? columnId, FitGridSortDirection direction) =>
      last = (columnId, direction);
}
