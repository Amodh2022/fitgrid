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

Finder _cell(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Filter $label',
);

Finder _field(String label) =>
    find.descendant(of: _cell(label), matching: find.byType(TextField));

void main() {
  group('FitGridColumnFilter.parse', () {
    const text = FitGridFilterKind.text;
    const number = FitGridFilterKind.number;
    const date = FitGridFilterKind.date;

    test('text: contains, =, !=', () {
      expect(
        FitGridColumnFilter.parse(' ab ', text),
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.contains,
          value: 'ab',
        ),
      );
      expect(
        FitGridColumnFilter.parse('=ab', text)!.operator,
        FitGridFilterOperator.equals,
      );
      expect(
        FitGridColumnFilter.parse('!= ab', text),
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.notEquals,
          value: 'ab',
        ),
      );
      expect(FitGridColumnFilter.parse('=', text), isNull);
      expect(FitGridColumnFilter.parse('   ', text), isNull);
    });

    test('numbers: comparisons, ranges, commas, junk', () {
      FitGridColumnFilter? p(String s) => FitGridColumnFilter.parse(s, number);
      expect(
        p('5'),
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.equals,
          value: 5,
        ),
      );
      expect(p('>=5')!.operator, FitGridFilterOperator.greaterOrEqual);
      expect(p('> 5')!.operator, FitGridFilterOperator.greaterThan);
      expect(p('<=5')!.operator, FitGridFilterOperator.lessOrEqual);
      expect(p('<5')!.operator, FitGridFilterOperator.lessThan);
      expect(p('!=5')!.operator, FitGridFilterOperator.notEquals);
      expect(p('1,000')!.value, 1000);
      expect(
        p('-5..1.5'),
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.between,
          value: -5,
          value2: 1.5,
        ),
      );
      expect(p('>'), isNull);
      expect(p('abc'), isNull);
      expect(p('5..'), isNull);
    });

    test('dates: calendar days only', () {
      expect(
        FitGridColumnFilter.parse('>2024-02-29', date),
        FitGridColumnFilter(
          operator: FitGridFilterOperator.greaterThan,
          value: DateTime(2024, 2, 29),
        ),
      );
      expect(FitGridColumnFilter.parse('2023-02-29', date), isNull);
      expect(FitGridColumnFilter.parse('2024-01-01T10:00', date), isNull);
      expect(
        FitGridColumnFilter.parse('2024-01-01..2024-12-31', date)!.value2,
        DateTime(2024, 12, 31),
      );
    });

    test('toText reads back through parse', () {
      for (final (s, kind) in <(String, FitGridFilterKind)>[
        ('ab', text),
        ('=ab', text),
        ('!=ab', text),
        ('5', number),
        ('>=5', number),
        ('<2.5', number),
        ('1..9', number),
        ('2024-03-04', date),
        ('!=2024-03-04', date),
        ('2024-01-01..2024-12-31', date),
      ]) {
        final filter = FitGridColumnFilter.parse(s, kind)!;
        expect(filter.toText(kind), s, reason: s);
      }
    });

    test('toText is null where the short form cannot say it', () {
      expect(
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.startsWith,
          value: 'a',
        ).toText(text),
        isNull,
      );
      expect(
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.isEmpty,
        ).toText(number),
        isNull,
      );
      expect(
        const FitGridColumnFilter.oneOf(<String>{
          'a',
        }).toText(FitGridFilterKind.checklist),
        isNull,
      );
    });
  });

  group('filter row', () {
    testWidgets('is off by default', (tester) async {
      await tester.pumpWidget(
        host(FitGrid<Employee>(rows: makeRows(5), columns: filterColumns())),
      );
      expect(find.byType(FitGridFilterRow<Employee>), findsNothing);
    });

    testWidgets('does not appear when no column is filterable', (tester) async {
      await tester.pumpWidget(
        host(
          FitGrid<Employee>(
            rows: makeRows(5),
            columns: columns(),
            showFilterRow: true,
          ),
        ),
      );
      expect(find.byType(FitGridFilterRow<Employee>), findsNothing);
    });

    testWidgets('typing filters the rows as you go', (tester) async {
      final controller = FitGridController<Employee>(
        rows: makeRows(20),
        columns: filterColumns(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(FitGrid<Employee>(controller: controller, showFilterRow: true)),
      );
      expect(fitGridRowCount(), 20);

      await tester.enterText(_field('Salary'), '>=50015');
      await tester.pump();
      expect(fitGridRowCount(), 5);
      expect(
        controller.filter.filters['salary'],
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.greaterOrEqual,
          value: 50015,
        ),
      );

      await tester.enterText(_field('Name'), 'person 1');
      await tester.pump();
      // 15..19 are the salaries left; of those, Person 15..19 all match.
      expect(fitGridRowCount(), 5);
      await tester.enterText(_field('Name'), '=person 17');
      await tester.pump();
      expect(fitGridRowCount(), 1);

      // Half-typed input sets no filter rather than a wrong one.
      await tester.enterText(_field('Salary'), '>');
      await tester.pump();
      expect(controller.filter.filters.containsKey('salary'), isFalse);
      expect(fitGridRowCount(), 1);
    });

    testWidgets('shows a filter set elsewhere, and clears it', (tester) async {
      final controller = FitGridController<Employee>(
        rows: makeRows(20),
        columns: filterColumns(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(FitGrid<Employee>(controller: controller, showFilterRow: true)),
      );

      controller.filter.setFilter(
        'salary',
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.between,
          value: 50002,
          value2: 50004,
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(_field('Salary')).controller!.text,
        '50002..50004',
      );
      expect(fitGridRowCount(), 3);

      // One the short form cannot express shows as a hint instead.
      controller.filter.setFilter(
        'name',
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.startsWith,
          value: 'Person 1',
        ),
      );
      await tester.pump();
      final name = tester.widget<TextField>(_field('Name'));
      expect(name.controller!.text, isEmpty);
      expect(name.decoration!.hintText, 'Starts with Person 1');

      await tester.tap(
        find.descendant(
          of: _cell('Salary'),
          matching: find.byTooltip('Clear filter'),
        ),
      );
      await tester.pump();
      expect(controller.filter.filters.containsKey('salary'), isFalse);
      expect(
        tester.widget<TextField>(_field('Salary')).controller!.text,
        isEmpty,
      );
    });

    testWidgets('a checklist column opens the filter dialog', (tester) async {
      final controller = FitGridController<Employee>(
        rows: makeRows(6),
        columns: filterColumns(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(FitGrid<Employee>(controller: controller, showFilterRow: true)),
      );
      expect(find.text('All'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Filter Role'), findsOneWidget);
      await tester.tap(find.text('Designer'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(controller.filter.filters['role']!.values, <String>{'Engineer'});
      expect(find.text('1 selected'), findsOneWidget);
      expect(fitGridRowCount(), 3);
    });

    testWidgets('fields keep their text when a column is pinned', (
      tester,
    ) async {
      final controller = FitGridController<Employee>(
        rows: makeRows(20),
        columns: filterColumns(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(FitGrid<Employee>(controller: controller, showFilterRow: true)),
      );
      await tester.enterText(_field('Name'), 'son 1');
      await tester.pump();
      controller.columns.setFreeze('name', FitGridFreeze.end);
      await tester.pump();
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        'son 1',
      );
    });

    testWidgets('sits between the header and the body', (tester) async {
      await tester.pumpWidget(
        host(
          FitGrid<Employee>(
            rows: makeRows(5),
            columns: filterColumns(),
            showFilterRow: true,
          ),
        ),
      );
      final header = tester.getRect(find.byType(FitGridHeader<Employee>));
      final row = tester.getRect(find.byType(FitGridFilterRow<Employee>));
      expect(row.top, header.bottom);
      expect(fitGridSection().localToGlobal(Offset.zero).dy, row.bottom);
    });
  });
}
