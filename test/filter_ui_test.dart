import 'dart:convert';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<FitGridColumn<Employee>> filterColumns() => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    filter: const FitGridFilterSpec.text(),
  ),
  FitGridColumn<Employee>(
    id: 'role',
    label: 'Role',
    value: (e) => e.role,
    filter: const FitGridFilterSpec.values(),
  ),
  FitGridColumn<Employee>(
    id: 'salary',
    label: 'Salary',
    value: (e) => e.salary.toString(),
    filter: FitGridFilterSpec.number((e) => e.salary),
  ),
];

void main() {
  group('FitGridColumnFilter', () {
    test('text operators ignore case', () {
      const f = FitGridColumnFilter(
        operator: FitGridFilterOperator.startsWith,
        value: 'per',
      );
      expect(f.matches('Person 1', null), isTrue);
      expect(f.matches('A person', null), isFalse);
    });

    test('numbers compare as numbers, between is inclusive', () {
      const between = FitGridColumnFilter(
        operator: FitGridFilterOperator.between,
        value: 9,
        value2: 10,
      );
      expect(between.matches('9', 9), isTrue);
      expect(between.matches('10', 10), isTrue);
      expect(between.matches('11', 11), isFalse);
      const gt = FitGridColumnFilter(
        operator: FitGridFilterOperator.greaterThan,
        value: 9,
      );
      // Text comparison would put "10" before "9".
      expect(gt.matches('10', 10), isTrue);
    });

    test('dates compare by calendar day', () {
      final f = FitGridColumnFilter(
        operator: FitGridFilterOperator.equals,
        value: DateTime(2026, 3, 4),
      );
      expect(f.matches('', DateTime(2026, 3, 4, 17, 30)), isTrue);
      expect(f.matches('', DateTime(2026, 3, 5)), isFalse);
    });

    test('empty checks, and the checklist', () {
      const empty = FitGridColumnFilter(
        operator: FitGridFilterOperator.isEmpty,
      );
      expect(empty.matches('  ', null), isTrue);
      expect(empty.matches('x', null), isFalse);
      const oneOf = FitGridColumnFilter.oneOf(<String>{'A', 'B'});
      expect(oneOf.matches('A', null), isTrue);
      expect(oneOf.matches('C', null), isFalse);
    });

    test('round-trips through JSON, dates included', () {
      final filters = <FitGridColumnFilter>[
        FitGridColumnFilter(
          operator: FitGridFilterOperator.between,
          value: DateTime(2026, 1, 2),
          value2: DateTime(2026, 2, 3),
        ),
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.lessThan,
          value: 4.5,
        ),
        const FitGridColumnFilter.oneOf(<String>{'b', 'a'}),
      ];
      for (final filter in filters) {
        final json = jsonDecode(jsonEncode(filter.toJson()));
        expect(
          FitGridColumnFilter.fromJson((json as Map).cast<String, Object?>()),
          filter,
        );
      }
    });
  });

  test('structured filters narrow the view and combine', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(100),
      columns: filterColumns(),
    );
    addTearDown(controller.dispose);

    controller.filter.setFilter(
      'salary',
      const FitGridColumnFilter(
        operator: FitGridFilterOperator.greaterOrEqual,
        value: 50090,
      ),
    );
    expect(controller.data.length, 10);
    controller.filter.setFilter(
      'role',
      const FitGridColumnFilter.oneOf(<String>{'Designer'}),
    );
    expect(controller.data.length, 5);
    expect(controller.filter.filteredColumnIds, <String>{'salary', 'role'});

    // A hidden column's filter stops applying, and comes back with it.
    controller.columns.setVisible('role', false);
    expect(controller.data.length, 10);
    controller.columns.setVisible('role', true);
    expect(controller.data.length, 5);

    controller.filter.clearColumnFilters();
    expect(controller.data.length, 100);
  });

  test('a filter on a column without a spec is ignored', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    controller.filter.setFilter(
      'name',
      const FitGridColumnFilter(
        operator: FitGridFilterOperator.equals,
        value: 'nobody',
      ),
    );
    expect(controller.data.length, 10);
  });

  Future<FitGridController<Employee>> pump(WidgetTester tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(40),
      columns: filterColumns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, showColumnMenu: true)),
    );
    return controller;
  }

  Future<void> openFilter(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel('$label column menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter…'));
    await tester.pumpAndSettle();
  }

  testWidgets('a number filter from the column menu', (tester) async {
    final controller = await pump(tester);
    await openFilter(tester, 'Salary');

    await tester.tap(
      find.byType(DropdownButtonFormField<FitGridFilterOperator>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Greater than').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '50035');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(controller.filter.filters['salary']!.value, 50035);
    expect(fitGridRowCount(), 4);
    expect(fitGridCellText(row: 0, column: 2), '50036');
    // The header shows the column is filtered.
    expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);

    // Reopening shows what was set, and Clear removes it.
    await openFilter(tester, 'Salary');
    expect(find.text('50035'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 40);
  });

  testWidgets('a value that does not parse is refused in place', (
    tester,
  ) async {
    final controller = await pump(tester);
    await openFilter(tester, 'Salary');
    await tester.enterText(find.byType(TextField).first, 'lots');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number'), findsOneWidget);
    expect(controller.filter.filters, isEmpty);
  });

  testWidgets('a checklist filter starts with everything ticked', (
    tester,
  ) async {
    final controller = await pump(tester);
    await openFilter(tester, 'Role');

    expect(find.widgetWithText(CheckboxListTile, 'Designer'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Designer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      controller.filter.filters['role'],
      const FitGridColumnFilter.oneOf(<String>{'Engineer'}),
    );
    expect(fitGridRowCount(), 20);

    // Ticking everything again removes the filter rather than keeping one
    // that removes nothing.
    await openFilter(tester, 'Role');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Designer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.filter.filters, isEmpty);
  });

  testWidgets('the checklist search narrows the list, select-all follows', (
    tester,
  ) async {
    final controller = await pump(tester);
    await openFilter(tester, 'Role');
    await tester.enterText(find.byType(TextField), 'eng');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Designer'), findsNothing);
    await tester.tap(find.text('(Select all shown)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      controller.filter.filters['role'],
      const FitGridColumnFilter.oneOf(<String>{'Designer'}),
    );
  });

  test('a data source receives the filters as JSON', () async {
    final requests = <FitGridPageRequest>[];
    final source = FitGridAsyncDataSource<Employee>(
      fetch: (request) async {
        requests.add(request);
        return const FitGridPageResult<Employee>(rows: <Employee>[]);
      },
      initialRowCount: 10,
    );
    addTearDown(source.dispose);

    source.filterBy(<String, Object?>{
      'salary': const FitGridColumnFilter(
        operator: FitGridFilterOperator.lessThan,
        value: 5,
      ).toJson(),
    });
    expect(source.rowCount, 0);
    source.loadWindow(0, 1);
    expect(requests.single.filters['salary'], <String, Object?>{
      'op': 'lessThan',
      'value': 5,
    });

    // The same filters again, as fresh maps, do not throw the cache away.
    await Future<void>.delayed(Duration.zero);
    final cached = source.cachedPageCount;
    source.filterBy(<String, Object?>{
      'salary': const FitGridColumnFilter(
        operator: FitGridFilterOperator.lessThan,
        value: 5,
      ).toJson(),
    });
    expect(source.cachedPageCount, cached);
  });

  testWidgets('the grid forwards filter changes to its data source', (
    tester,
  ) async {
    final seen = <Map<String, Object?>>[];
    final source = _RecordingSource(seen);
    addTearDown(source.dispose);
    final controller = FitGridController<Employee>(columns: filterColumns());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, dataSource: source)),
    );

    controller.filter.setFilter(
      'name',
      const FitGridColumnFilter(
        operator: FitGridFilterOperator.contains,
        value: 'x',
      ),
    );
    expect(seen.last.keys, <String>['name']);
  });
}

class _RecordingSource extends FitGridDataSource<Employee> {
  _RecordingSource(this.seen);

  final List<Map<String, Object?>> seen;

  @override
  int get rowCount => 0;

  @override
  Employee? rowAt(int index) => null;

  @override
  void filterBy(Map<String, Object?> filters) => seen.add(filters);
}
