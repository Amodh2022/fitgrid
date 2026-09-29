import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _Pirate extends FitGridStrings {
  const _Pirate();

  @override
  String get sortAscending => 'Hoist';

  @override
  String get hideColumn => 'Make walk the plank';

  @override
  String get noRows => 'Nary a row';

  @override
  String get selected => 'Plundered';

  @override
  String pageRange(int first, int last, int total) => '$first-$last o $total';

  @override
  String get filterRowHint => 'Seek';

  @override
  String filterRowLabel(String column) => 'Seek $column';
}

List<FitGridColumn<Employee>> _filterable() => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    sortable: true,
    filter: const FitGridFilterSpec.text(),
  ),
  FitGridColumn<Employee>(id: 'role', label: 'Role', value: (e) => e.role),
];

void main() {
  testWidgets('English by default', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(3),
          columns: _filterable(),
          showColumnMenu: true,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Name column menu'));
    await tester.pumpAndSettle();
    expect(find.text('Sort ascending'), findsOneWidget);
    expect(find.text('Hide column'), findsOneWidget);
  });

  testWidgets('FitGrid.strings reaches the menu, the empty state and '
      'the filter row', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(3),
          columns: _filterable(),
          showColumnMenu: true,
          showFilterRow: true,
          strings: const _Pirate(),
        ),
      ),
    );
    expect(find.text('Seek'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Name column menu'));
    await tester.pumpAndSettle();
    expect(find.text('Hoist'), findsOneWidget);
    expect(find.text('Make walk the plank'), findsOneWidget);
    // Anything not overridden stays English.
    expect(find.text('Sort descending'), findsOneWidget);
    await tester.tap(find.text('Hoist'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: const <Employee>[],
          columns: _filterable(),
          strings: const _Pirate(),
        ),
      ),
    );
    expect(find.text('Nary a row'), findsOneWidget);
  });

  testWidgets('FitGridLocalizations covers a subtree, pager included', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGridLocalizations(
          strings: const _Pirate(),
          child: FitGrid<Employee>(
            rows: makeRows(30),
            columns: columns(),
            paginated: true,
            pageSize: 10,
            showSelectionColumn: true,
          ),
        ),
      ),
    );
    expect(find.text('1-10 o 30'), findsOneWidget);
    expect(find.byTooltip('Next page'), findsOneWidget);

    await tester.tap(find.byTooltip('Select all'));
    await tester.pump();
    expect(fitGridCellSpec(row: 0, column: 0).semanticLabel, 'Plundered');
  });

  testWidgets('a delegate picks strings by locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'PIRATE'),
        localizationsDelegates: <LocalizationsDelegate<Object>>[
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          FitGridStringsDelegate(
            (locale) => locale.countryCode == 'PIRATE'
                ? const _Pirate()
                : const FitGridStrings(),
          ),
        ],
        supportedLocales: const <Locale>[Locale('en', 'PIRATE')],
        home: Scaffold(
          body: FitGrid<Employee>(rows: const <Employee>[], columns: columns()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nary a row'), findsOneWidget);
  });

  testWidgets('the filter dialog opened from the grid is translated', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(3),
          columns: _filterable(),
          showColumnMenu: true,
          strings: const _Apply(),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Name column menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter…'));
    await tester.pumpAndSettle();
    expect(find.text('Anwenden'), findsOneWidget);
    expect(find.text('Filtern: Name'), findsOneWidget);
  });
}

class _Apply extends FitGridStrings {
  const _Apply();

  @override
  String get apply => 'Anwenden';

  @override
  String filterDialogTitle(String column) => 'Filtern: $column';
}
