import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('a reorderable header builds without containing itself', (
    tester,
  ) async {
    // The regression this guards: the drag target was assigned back into the
    // same local the builder closed over, so the header cell contained the
    // header cell, forever. It shows up as a stack overflow rather than as a
    // layout error, which is why it needs a test of its own.
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          columns: columns(),
          reorderableColumns: true,
        ),
      ),
    );
    await tester.pump();

    expect(fitGridColumnIds(), <String>['name', 'role', 'salary']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a header onto another moves the column', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, reorderableColumns: true)),
    );
    await tester.pump();

    final from = tester.getCenter(find.text('Salary'));
    final to = tester.getCenter(find.text('Name'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fitGridColumnIds(), <String>['salary', 'name', 'role']);
    // The painted cells followed, with nothing to keep in sync by hand.
    expect(fitGridCellText(row: 0, column: 0), '50000');
  });

  testWidgets('a column can opt out', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: <FitGridColumn<Employee>>[
        columns().first.copyWith(reorderable: false),
        ...columns().sublist(1),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, reorderableColumns: true)),
    );
    await tester.pump();

    expect(find.byType(Draggable<String>), findsNWidgets(2));
  });

  testWidgets('reordering is off by default', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(5), columns: columns())),
    );
    await tester.pump();

    expect(find.byType(Draggable<String>), findsNothing);
  });
}
