import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/src/widgets/fitgrid_section.dart';
import 'package:fitgrid/testing.dart';

class Employee {
  const Employee(this.name, this.role, this.salary);
  final String name;
  final String role;
  final int salary;
}

List<Employee> makeRows(int count) => <Employee>[
  for (var i = 0; i < count; i++)
    Employee('Person $i', i.isEven ? 'Engineer' : 'Designer', 50000 + i),
];

List<FitGridColumn<Employee>> columns() => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    sortable: true,
  ),
  FitGridColumn<Employee>(id: 'role', label: 'Role', value: (e) => e.role),
  FitGridColumn<Employee>(
    id: 'salary',
    label: 'Salary',
    value: (e) => e.salary.toString(),
    alignment: FitGridAlignment.end,
    sortable: true,
    comparator: (a, b) => a.salary.compareTo(b.salary),
  ),
];

Widget host(
  Widget child, {
  Size size = const Size(800, 600),
  TextDirection textDirection = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('paints cell text that find.text cannot see', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(5), columns: columns())),
    );

    // The whole premise of the package, asserted: the text is on screen but
    // there is no Text widget behind it.
    expect(find.text('Person 0'), findsNothing);
    expectFitGridCell(tester, 'Person 0', row: 0, column: 0);
    expectFitGridRow(tester, 1, ['Person 1', 'Designer', '50001']);
  });

  testWidgets('measures columns from content', (tester) async {
    final rows = <Employee>[
      const Employee('Al', 'Engineer', 1),
      const Employee('Bartholomew Fotheringay-Smythe', 'Designer', 2),
    ];
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: rows,
          columns: columns(),
          stretchColumnsToFill: false,
        ),
      ),
    );

    // 'Name' holds a much longer string than 'Role', and nobody declared a
    // width for either.
    expect(
      fitGridColumnWidth(tester, 'name'),
      greaterThan(fitGridColumnWidth(tester, 'role')),
    );
  });

  testWidgets('lays out only the rows in the viewport', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(rows: makeRows(100000), columns: columns()),
        size: const Size(800, 600),
      ),
    );

    expect(fitGridRowCount(tester), 100000);
    // The entire point of windowing. A 600px viewport at ~44px per row holds
    // well under 30 rows; anything near the dataset size means it regressed.
    expect(fitGridLaidOutRowCount(tester), lessThan(40));
  });

  testWidgets('scrolling moves the window, not the dataset', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(5000), columns: columns())),
    );

    expectFitGridCell(tester, 'Person 0', row: 0, column: 0);
    final before = fitGridLaidOutRowCount(tester);

    await tester.drag(find.byType(FitGrid<Employee>), const Offset(0, -4000));
    await tester.pump();

    expect(fitGridSection(tester).firstVisibleRow, greaterThan(50));
    expect(fitGridLaidOutRowCount(tester), before);
  });

  testWidgets('sorting reorders rows and survives in painted text', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(20),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    expectFitGridCell(tester, '50000', row: 0, column: 2);

    controller.toggleSort('salary');
    await tester.pump();
    expect(controller.data.sortDirection, FitGridSortDirection.ascending);
    expectFitGridCell(tester, '50000', row: 0, column: 2);

    controller.toggleSort('salary');
    await tester.pump();
    expect(controller.data.sortDirection, FitGridSortDirection.descending);
    // Stale painted text would still read 50000 here — this is the assertion
    // that proves the painter cache is invalidated on a sort.
    expectFitGridCell(tester, '50019', row: 0, column: 2);

    controller.toggleSort('salary');
    await tester.pump();
    expect(controller.data.sortDirection, FitGridSortDirection.none);
    expectFitGridCell(tester, '50000', row: 0, column: 2);
  });

  testWidgets('tapping a sortable header sorts', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(10), columns: columns())),
    );

    await tester.tap(find.text('Salary'));
    await tester.pump();
    expectFitGridCell(tester, '50000', row: 0, column: 2);

    await tester.tap(find.text('Salary'));
    await tester.pump();
    expectFitGridCell(tester, '50009', row: 0, column: 2);
  });

  testWidgets('hiding a column removes it from the layout', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    expect(fitGridSection(tester).columnLayout.ids, ['name', 'role', 'salary']);

    controller.columns.setVisible('role', false);
    await tester.pump();
    expect(fitGridSection(tester).columnLayout.ids, ['name', 'salary']);
    expectFitGridRow(tester, 0, ['Person 0', '50000']);
  });

  testWidgets('reports truncation for cells that did not fit', (tester) async {
    final rows = <Employee>[
      const Employee(
        'A name far too long to fit inside a hundred pixels of column',
        'Engineer',
        1,
      ),
    ];
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: rows,
          columns: [
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
              width: const FitGridColumnWidth.fixed(100),
            ),
          ],
        ),
      ),
    );

    expect(fitGridCellIsTruncated(tester, row: 0, column: 0), isTrue);
  });

  testWidgets('renders empty state with no rows', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: const [], columns: columns())),
    );

    expect(find.text('No rows'), findsOneWidget);
  });

  testWidgets('mirrors column order in right-to-left', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(rows: makeRows(30), columns: columns()),
        textDirection: TextDirection.rtl,
      ),
    );

    expect(tester.takeException(), isNull);
    expectFitGridCell(tester, 'Person 0', row: 0, column: 0);

    // The real assertion: in RTL the first column belongs at the trailing
    // (right) edge, not the left. Rendering without throwing would not catch a
    // grid that simply ignored the text direction.
    final section = fitGridSection(tester);
    expect(section.columnAtOffset(section.size.width - 2), 0);
    expect(section.columnAtOffset(2), section.columnLayout.length - 1);
  });

  testWidgets('reports the tapped row without a detector per row', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(50),
          columns: columns(),
          onRowTap: (row, index) => taps.add(index),
        ),
      ),
    );

    final section = fitGridSection(tester);
    final topLeft = tester.getTopLeft(find.byType(FitGridSection));
    // Third row down, comfortably inside it.
    await tester.tapAt(
      topLeft + Offset(20, section.rowOffsetAt(2) + section.rowHeightAt(2) / 2),
    );
    await tester.pump();

    expect(taps, [2]);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(rows: makeRows(30), columns: columns()),
        theme: ThemeData.dark(useMaterial3: true),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a widget column is reserved rather than painted as text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(3),
          columns: [
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
            ),
            FitGridColumn<Employee>(
              id: 'action',
              label: 'Action',
              value: (e) => '',
              cellBuilder: (context, row, index) => const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );

    // Painted columns and reserved widget columns coexist: the builder column
    // takes up its share of the width and is skipped by the text pass, while
    // its neighbour still paints normally. Instantiating the builder itself
    // comes with virtualized overlay children.
    expectFitGridCell(tester, 'Person 0', row: 0, column: 0);
    expect(fitGridColumnWidth(tester, 'action'), greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
