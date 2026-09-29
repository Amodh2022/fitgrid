// Selection, focus and an open editor belong to a record, not to a position.
//
// A sort, a filter or a live update reorders the view. Anything that was
// pointing at "row 3" has to still point at the same person afterwards, or a
// selection silently changes hands and — worse — an edit typed into an open
// editor is committed to whichever record slid into that slot.

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _Person {
  const _Person(this.id, this.name, this.salary);

  final int id;
  final String name;
  final int salary;

  _Person withSalary(int value) => _Person(id, name, value);
}

/// Salaries deliberately run against the ids, so sorting by salary reverses
/// the list and every row changes position.
List<_Person> _people(int count) => <_Person>[
  for (var i = 0; i < count; i++) _Person(i, 'Person $i', 90000 - i * 100),
];

class _Harness {
  _Harness(int count) : rows = _people(count);

  List<_Person> rows;
  late final FitGridController<_Person> controller;
  final List<String> commits = <String>[];

  /// Replaces one record with a new object, the way an immutable model or a
  /// server push does.
  void replace(int id, _Person Function(_Person) change) {
    rows = <_Person>[for (final row in rows) row.id == id ? change(row) : row];
    controller.data.rows = rows;
  }

  List<FitGridColumn<_Person>> columns() => <FitGridColumn<_Person>>[
    FitGridColumn<_Person>(
      id: 'name',
      label: 'Name',
      value: (p) => p.name,
      width: const FitGridColumnWidth.fixed(200),
      editor: FitGridEditor<_Person>(
        onCommit: (row, index, value) => commits.add('${row.id}=$value'),
      ),
    ),
    FitGridColumn<_Person>(
      id: 'salary',
      label: 'Salary',
      value: (p) => p.salary.toString(),
      width: const FitGridColumnWidth.fixed(140),
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
    ),
  ];

  Widget grid({FitGridSelectionMode mode = FitGridSelectionMode.multiple}) {
    controller = FitGridController<_Person>(
      rows: rows,
      columns: columns(),
      selectionMode: mode,
    );
    return host(
      FitGrid<_Person>(
        controller: controller,
        rowKey: (p) => p.id,
        stretchColumnsToFill: false,
      ),
    );
  }

  int idAt(int viewIndex) => controller.data.view[viewIndex].id;

  Set<int> selectedIds() => <int>{
    for (final i in controller.selection.selected) idAt(i),
  };

  int viewIndexOf(int id) =>
      controller.data.view.indexWhere((row) => row.id == id);
}

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness(40));
  tearDown(() => harness.controller.dispose());

  group('after a sort', () {
    testWidgets('a single selection stays on the same record', (tester) async {
      await tester.pumpWidget(harness.grid(mode: FitGridSelectionMode.single));
      harness.controller.selection.select(<int>[3]);
      await tester.pump();

      harness.controller.toggleSort('salary');
      await tester.pump();

      expect(harness.selectedIds(), <int>{3});
    });

    testWidgets('a multiple selection stays on the same records', (
      tester,
    ) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.selection.select(<int>[1, 4, 9]);
      await tester.pump();

      harness.controller.toggleSort('salary');
      await tester.pump();
      expect(harness.selectedIds(), <int>{1, 4, 9});

      // And back again, through descending and unsorted.
      harness.controller.toggleSort('salary');
      await tester.pump();
      expect(harness.selectedIds(), <int>{1, 4, 9});
      harness.controller.toggleSort('salary');
      await tester.pump();
      expect(harness.selectedIds(), <int>{1, 4, 9});
    });

    testWidgets('the keyboard focus stays on the same record', (tester) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.focus.moveTo(6, 'name');
      await tester.pump();

      harness.controller.toggleSort('salary');
      await tester.pump();

      expect(harness.idAt(harness.controller.focus.rowIndex!), 6);
    });

    testWidgets('an open editor stays on the same record', (tester) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.editing.begin(5, 'name');
      await tester.pumpAndSettle();

      harness.controller.toggleSort('salary');
      await tester.pumpAndSettle();

      final editing = harness.controller.editing.rowIndex;
      expect(editing, isNotNull);
      expect(harness.idAt(editing!), 5);
    });

    testWidgets('a value typed before the sort commits to the record it was '
        'typed into', (tester) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.editing.begin(5, 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Renamed');

      harness.controller.toggleSort('salary');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.commits, <String>['5=Renamed']);
    });

    testWidgets('the painted selection follows the record on screen', (
      tester,
    ) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.selection.select(<int>[0]);
      await tester.pump();

      harness.controller.toggleSort('salary');
      await tester.pump();

      // Person 0 has the highest salary, so ascending puts them last.
      final at = harness.viewIndexOf(0);
      expect(at, 39);
      expect(harness.controller.selection.contains(at), isTrue);
      expect(harness.controller.selection.contains(0), isFalse);
    });
  });

  group('after a filter', () {
    testWidgets('a selected record that stays visible stays selected', (
      tester,
    ) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.selection.select(<int>[20]);
      await tester.pump();

      // "Person 2" matches Person 2 and Person 20–29, so Person 20 moves from
      // index 20 to index 1.
      harness.controller.filter.query = 'Person 2';
      await tester.pump();

      expect(harness.selectedIds(), <int>{20});
    });

    testWidgets('clearing the filter puts the selection back on the record', (
      tester,
    ) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.filter.query = 'Person 2';
      await tester.pump();
      harness.controller.selection.select(<int>[1]); // Person 20
      await tester.pump();
      expect(harness.selectedIds(), <int>{20});

      harness.controller.filter.query = '';
      await tester.pump();

      expect(harness.selectedIds(), <int>{20});
    });
  });

  group('while rows update', () {
    testWidgets('replacing records keeps the selection on them by rowKey', (
      tester,
    ) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.toggleSort('salary');
      await tester.pump();
      harness.controller.selection.select(<int>[harness.viewIndexOf(7)]);
      await tester.pump();

      // Person 7 gets a raise that moves them to the other end of the sort.
      harness.replace(7, (p) => p.withSalary(1));
      await tester.pump();

      expect(harness.viewIndexOf(7), 0);
      expect(harness.selectedIds(), <int>{7});
    });

    testWidgets('an update to another record under an active filter does not '
        'move the selection', (tester) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.filter.query = 'Person 1';
      harness.controller.toggleSort('salary');
      await tester.pump();
      harness.controller.selection.select(<int>[harness.viewIndexOf(15)]);
      await tester.pump();

      for (var tick = 0; tick < 5; tick++) {
        harness.replace(12 + tick, (p) => p.withSalary(tick));
        await tester.pump();
        expect(harness.selectedIds(), <int>{15}, reason: 'tick $tick');
      }
      expect(fitGridRowCount(), harness.controller.data.length);
    });

    testWidgets('an open editor survives an update that reorders the view', (
      tester,
    ) async {
      await tester.pumpWidget(harness.grid());
      harness.controller.toggleSort('salary');
      await tester.pump();
      harness.controller.editing.begin(harness.viewIndexOf(10), 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Still ten');

      harness.replace(10, (p) => p.withSalary(1));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.commits, <String>['10=Still ten']);
    });
  });
}
