import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('the search narrows the rows', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(100),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    expect(fitGridRowCount(), 100);

    controller.filter.query = 'Designer';
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 50);
    expect(fitGridCellText(row: 0, column: 1), 'Designer');
  });

  testWidgets('matches are highlighted, and only in searchable columns', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: <FitGridColumn<Employee>>[
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
        FitGridColumn<Employee>(
          id: 'role',
          label: 'Role',
          value: (e) => e.role,
          searchable: false,
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    controller.filter.query = 'son';
    await tester.pumpAndSettle();

    // "Person 0" — the match runs from index 3 to 6.
    expect(fitGridCellSpec(row: 0, column: 0).highlights, <int>[3, 6]);
    expect(fitGridCellSpec(row: 0, column: 1).highlights, isEmpty);
  });

  testWidgets('an empty query costs nothing and highlights nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(10), columns: columns())),
    );

    expect(fitGridCellSpec(row: 0, column: 0).highlights, isEmpty);
    expect(fitGridCellSpec(row: 0, column: 0).hasHighlights, isFalse);
  });

  testWidgets('a column filter and the search both have to pass', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(100),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));

    controller.filter.setColumnFilter('salary', (e) => e.salary > 50090);
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 9);

    controller.filter.query = 'Engineer';
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 4);

    controller.filter.clear();
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 100);
  });

  testWidgets('filtering and sorting compose', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(100),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));

    controller.filter.query = 'Designer';
    controller
      ..toggleSort('salary')
      ..toggleSort('salary'); // ascending, then descending
    await tester.pumpAndSettle();

    expect(fitGridCellText(row: 0, column: 2), '50099');
    expect(fitGridRowCount(), 50);
  });

  test('the search is case-insensitive unless asked otherwise', () {
    final filter = FitGridFilterState<Employee>()..query = 'PERSON';
    addTearDown(filter.dispose);

    expect(filter.matchesIn('Person 1'), <int>[0, 6]);
    filter.caseSensitive = true;
    expect(filter.matchesIn('Person 1'), isEmpty);
  });

  test('every occurrence is reported, not just the first', () {
    final filter = FitGridFilterState<Employee>()..query = 'ab';
    addTearDown(filter.dispose);

    expect(filter.matchesIn('abcab'), <int>[0, 2, 3, 5]);
  });

  testWidgets('a filter on a removed column stops applying', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(20),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    controller.filter.setColumnFilter('salary', (e) => e.salary > 50010);
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 9);

    controller.columns.setVisible('salary', false);
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 20);
  });
}
