import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  FitGridController<Employee> make({List<FitGridColumn<Employee>>? cols}) {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: cols ?? columns(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> openMenu(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel('$label column menu'));
    await tester.pumpAndSettle();
  }

  test('showAll and setFreeze on the column state', () {
    final controller = make();
    controller.columns
      ..setVisible('role', false)
      ..setVisible('salary', false);
    expect(controller.columns.visible.map((c) => c.id), <String>['name']);

    controller.columns.showAll();
    expect(controller.columns.visible.length, 3);

    controller.columns.setFreeze('salary', FitGridFreeze.start);
    expect(controller.columns.visible.first.id, 'salary');
    controller.columns.setFreeze('salary', FitGridFreeze.none);
    // Unpinning puts it back where it was declared.
    expect(controller.columns.visible.last.id, 'salary');
  });

  testWidgets('no menu buttons unless asked for', (tester) async {
    await tester.pumpWidget(host(FitGrid<Employee>(controller: make())));
    expect(find.bySemanticsLabel('Name column menu'), findsNothing);
  });

  testWidgets('the menu sizes every column back to fit', (tester) async {
    final controller = make();
    final reports = <(String, double?)>[];
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          showColumnMenu: true,
          onColumnResized: (id, width) => reports.add((id, width)),
        ),
      ),
    );

    // Nothing resized yet, so there is nothing to hand back.
    await openMenu(tester, 'Name');
    final entry = find.ancestor(
      of: find.text('Size all columns to fit'),
      matching: find.byType(PopupMenuItem<void>),
    );
    expect(tester.widget<PopupMenuItem<void>>(entry).enabled, isFalse);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    controller.columns
      ..setWidth('name', 300)
      ..setWidth('salary', 200);
    await tester.pump();

    await openMenu(tester, 'Name');
    await tester.tap(find.text('Size all columns to fit'));
    await tester.pumpAndSettle();

    expect(controller.columns.widthOverrides, isEmpty);
    expect(
      reports,
      unorderedEquals(<(String, double?)>[('name', null), ('salary', null)]),
    );
  });

  testWidgets('the menu sorts, pins and hides', (tester) async {
    final controller = make();
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, showColumnMenu: true)),
    );

    await openMenu(tester, 'Salary');
    await tester.tap(find.text('Sort descending'));
    await tester.pumpAndSettle();
    expect(controller.data.sortKeys.single.descending, isTrue);
    expect(fitGridCellText(row: 0, column: 2), '50009');

    await openMenu(tester, 'Salary');
    await tester.tap(find.text('Pin to start'));
    await tester.pumpAndSettle();
    expect(controller.columns.visible.first.id, 'salary');

    await openMenu(tester, 'Role');
    await tester.tap(find.text('Hide column'));
    await tester.pumpAndSettle();
    expect(
      controller.columns.visible.map((c) => c.id),
      isNot(contains('role')),
    );
  });

  testWidgets('a column that cannot be hidden offers no hide item', (
    tester,
  ) async {
    final cols = columns();
    cols[0] = cols[0].copyWith(hideable: false);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(controller: make(cols: cols), showColumnMenu: true),
      ),
    );
    await openMenu(tester, 'Name');
    expect(find.text('Hide column'), findsNothing);
  });

  testWidgets('columnMenuBuilder can add and remove entries', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: make(),
          showColumnMenu: true,
          columnMenuBuilder: (context, column, defaults) =>
              <PopupMenuEntry<void>>[
                PopupMenuItem<void>(
                  onTap: () => tapped = true,
                  child: Text('Custom ${column.id}'),
                ),
              ],
        ),
      ),
    );
    await openMenu(tester, 'Role');
    expect(find.text('Sort ascending'), findsNothing);
    await tester.tap(find.text('Custom role'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('the chooser toggles columns and keeps the last one', (
    tester,
  ) async {
    final controller = make();
    await tester.pumpWidget(
      host(
        Column(
          children: <Widget>[
            FitGridColumnChooser<Employee>(controller: controller),
            Expanded(child: FitGrid<Employee>(controller: controller)),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('Columns'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Role'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Salary'));
    await tester.pumpAndSettle();
    expect(controller.columns.visible.map((c) => c.id), <String>['name']);

    // The menu stayed open, and the last visible column is locked on.
    final last = tester.widget<CheckboxMenuButton>(
      find.widgetWithText(CheckboxMenuButton, 'Name'),
    );
    expect(last.onChanged, isNull);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(controller.columns.visible.length, 3);
  });

  testWidgets('"Columns…" opens the chooser dialog', (tester) async {
    final controller = make();
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, showColumnMenu: true)),
    );
    await openMenu(tester, 'Name');
    await tester.tap(find.text('Columns…'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Salary'));
    await tester.pumpAndSettle();
    expect(controller.columns.byId('salary')!.visible, isFalse);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
