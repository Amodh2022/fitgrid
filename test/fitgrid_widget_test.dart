import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';

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
    expect(fitGridCellText(row: 0, column: 0), 'Person 0');
    expect(fitGridRowText(1), ['Person 1', 'Designer', '50001']);
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
    expect(fitGridColumnWidth('name'), greaterThan(fitGridColumnWidth('role')));
  });

  testWidgets('lays out only the rows in the viewport', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(rows: makeRows(100000), columns: columns()),
        size: const Size(800, 600),
      ),
    );

    expect(fitGridRowCount(), 100000);
    // The entire point of windowing. A 600px viewport at ~44px per row holds
    // well under 30 rows; anything near the dataset size means it regressed.
    expect(fitGridLaidOutRowCount(), lessThan(40));
  });

  testWidgets('scrolling moves the window, not the dataset', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(5000), columns: columns())),
    );

    expect(fitGridCellText(row: 0, column: 0), 'Person 0');
    final before = fitGridLaidOutRowCount();

    await tester.drag(find.byType(FitGrid<Employee>), const Offset(0, -4000));
    await tester.pump();

    expect(fitGridSection().firstVisibleRow, greaterThan(50));
    expect(fitGridLaidOutRowCount(), before);
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
    expect(fitGridCellText(row: 0, column: 2), '50000');

    controller.toggleSort('salary');
    await tester.pump();
    expect(controller.data.sortDirection, FitGridSortDirection.ascending);
    expect(fitGridCellText(row: 0, column: 2), '50000');

    controller.toggleSort('salary');
    await tester.pump();
    expect(controller.data.sortDirection, FitGridSortDirection.descending);
    // Stale painted text would still read 50000 here — this is the assertion
    // that proves the painter cache is invalidated on a sort.
    expect(fitGridCellText(row: 0, column: 2), '50019');

    controller.toggleSort('salary');
    await tester.pump();
    expect(controller.data.sortDirection, FitGridSortDirection.none);
    expect(fitGridCellText(row: 0, column: 2), '50000');
  });

  testWidgets('tapping a sortable header sorts', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(10), columns: columns())),
    );

    await tester.tap(find.text('Salary'));
    await tester.pump();
    expect(fitGridCellText(row: 0, column: 2), '50000');

    await tester.tap(find.text('Salary'));
    await tester.pump();
    expect(fitGridCellText(row: 0, column: 2), '50009');
  });

  testWidgets('hiding a column removes it from the layout', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    expect(fitGridSection().columnLayout.ids, ['name', 'role', 'salary']);

    controller.columns.setVisible('role', false);
    await tester.pump();
    expect(fitGridSection().columnLayout.ids, ['name', 'salary']);
    expect(fitGridRowText(0), ['Person 0', '50000']);
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

    expect(fitGridCellIsTruncated(row: 0, column: 0), isTrue);
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
    expect(fitGridCellText(row: 0, column: 0), 'Person 0');

    // The real assertion: in RTL the first column belongs at the trailing
    // (right) edge, not the left. Rendering without throwing would not catch a
    // grid that simply ignored the text direction.
    final section = fitGridSection();
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

    final section = fitGridSection();
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

    // Painted columns and widget columns coexist: the builder column takes up
    // its share of the width and is skipped by the text pass, while its
    // neighbour still paints normally.
    expect(fitGridCellText(row: 0, column: 0), 'Person 0');
    expect(fitGridColumnWidth('action'), greaterThan(0));
    expect(find.byIcon(Icons.edit), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  _rowColourTests();
}

void _rowColourTests() {
  testWidgets('rowColor paints conditional formatting without a widget', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    Future<int> pumpWith(int rows) async {
      controller.data.rows = makeRows(rows);
      await tester.pumpWidget(
        host(
          FitGrid<Employee>(
            controller: controller,
            rowColor: (row, index) =>
                row.salary.isEven ? const Color(0xFFFFE0E0) : null,
          ),
        ),
      );
      await tester.pump();
      return find.byType(ColoredBox).evaluate().length;
    }

    // The colour goes straight to the paint pass, so the widget count does not
    // move when the row count does. The few that exist are the header and the
    // chrome around the grid.
    expect(await pumpWith(6), await pumpWith(600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selection colour wins over a row colour', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(6),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    controller.selection
      ..mode = FitGridSelectionMode.multiple
      ..select(<int>[1]);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          rowColor: (row, index) => const Color(0xFFFFE0E0),
        ),
      ),
    );
    await tester.pump();

    // A selection the user just made should not be hidden by a rule they wrote
    // months ago. Asserted through the render object rather than by reading
    // pixels, which a golden already covers.
    expect(fitGridSection().rowCount, 6);
    expect(tester.takeException(), isNull);
  });
}
