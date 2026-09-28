// Column widths under live updates, sorts and filters: measured against the
// rows as supplied, and re-measured only where a replaced row could matter.

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late List<Employee> rows;
  late FitGridController<Employee> controller;

  Future<void> pump(WidgetTester tester) async {
    rows = makeRows(500);
    controller = FitGridController<Employee>(rows: rows, columns: columns());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(controller: controller, stretchColumnsToFill: false),
      ),
    );
  }

  Future<void> replace(WidgetTester tester, int index, String name) async {
    rows = List<Employee>.of(rows)
      ..[index] = Employee(name, rows[index].role, rows[index].salary);
    controller.data.rows = rows;
    await tester.pump();
  }

  testWidgets('an update with a longer value widens the column', (
    tester,
  ) async {
    await pump(tester);
    final before = fitGridColumnWidth('name');

    await replace(tester, 250, 'A considerably longer name than any other');

    expect(fitGridColumnWidth('name'), greaterThan(before));
  });

  testWidgets('replacing the widest row narrows the column again', (
    tester,
  ) async {
    await pump(tester);
    final before = fitGridColumnWidth('name');
    await replace(tester, 250, 'A considerably longer name than any other');
    expect(fitGridColumnWidth('name'), greaterThan(before));

    await replace(tester, 250, 'Short');

    expect(fitGridColumnWidth('name'), before);
  });

  testWidgets('an update elsewhere leaves the widths alone', (tester) async {
    await pump(tester);
    final before = fitGridColumnWidth('name');

    await replace(tester, 3, 'P 3');

    expect(fitGridColumnWidth('name'), before);
  });

  testWidgets('sorting and filtering do not change the widths', (tester) async {
    await pump(tester);
    await replace(tester, 499, 'A considerably longer name than any other');
    final wide = fitGridColumnWidth('name');

    controller.toggleSort('salary');
    await tester.pump();
    expect(fitGridColumnWidth('name'), wide);

    // The long name is filtered out, and the column keeps its width rather
    // than twitching narrower.
    controller.filter.query = 'Person 1';
    await tester.pump();
    expect(fitGridRowCount(), lessThan(500));
    expect(fitGridColumnWidth('name'), wide);
  });

  testWidgets('a sorted view still paints the right text after an update', (
    tester,
  ) async {
    await pump(tester);
    controller.toggleSort('name');
    await tester.pump();
    final first = fitGridCellText(row: 0, column: 0);

    await replace(tester, rows.indexWhere((e) => e.name == first), 'Aaron');

    expect(fitGridCellText(row: 0, column: 0), 'Aaron');
  });
}
