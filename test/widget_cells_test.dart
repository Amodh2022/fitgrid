import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// A name column plus one widget column, which is the shape almost every real
/// use takes: mostly painted text, one column of controls.
List<FitGridColumn<Employee>> withButtons(
  void Function(int rowIndex) onPressed, {
  FitGridFreeze freeze = FitGridFreeze.none,
}) => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    freeze: freeze,
    width: const FitGridColumnWidth.fixed(200),
  ),
  FitGridColumn<Employee>(
    id: 'action',
    label: 'Action',
    value: (e) => 'Open ${e.name}',
    width: const FitGridColumnWidth.fixed(160),
    cellBuilder: (context, row, index) => TextButton(
      onPressed: () => onPressed(index),
      child: Text('Open ${row.name}'),
    ),
  ),
];

void main() {
  testWidgets('widget cells are built for the rows on screen only', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(10000),
          columns: withButtons((_) {}),
          rowHeight: const FitGridRowHeight.fixed(40),
        ),
        size: const Size(800, 400),
      ),
    );

    // Real widgets, so ordinary finders see them.
    expect(find.text('Open Person 0'), findsOneWidget);
    // A screenful plus overscan, not ten thousand.
    final built = find.byType(TextButton).evaluate().length;
    expect(built, greaterThan(5));
    expect(built, lessThan(20));
    expect(find.text('Open Person 500'), findsNothing);
  });

  testWidgets('scrolling builds the new rows and drops the old ones', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10000),
      columns: withButtons((_) {}),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          rowHeight: const FitGridRowHeight.fixed(40),
        ),
        size: const Size(800, 400),
      ),
    );
    controller.scrollTo(5000);
    await tester.pumpAndSettle();

    expect(find.text('Open Person 5000'), findsOneWidget);
    expect(find.text('Open Person 0'), findsNothing);
    expect(find.byType(TextButton).evaluate().length, lessThan(20));
  });

  testWidgets('a widget cell sits in its own cell box', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          columns: withButtons((_) {}),
          rowHeight: const FitGridRowHeight.fixed(40),
        ),
      ),
    );

    final grid = fitGridSection().localToGlobal(Offset.zero);
    final button = tester.getRect(find.text('Open Person 2'));
    // Row 2 starts two rows down, and the action column starts after the
    // 200-pixel name column.
    expect(button.top, greaterThanOrEqualTo(grid.dy + 80));
    expect(button.bottom, lessThanOrEqualTo(grid.dy + 120));
    expect(button.left, greaterThanOrEqualTo(grid.dx + 200));
  });

  testWidgets('the builder gets the index into the full list when paged', (
    tester,
  ) async {
    final indices = <int>{};
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(100),
          paginated: true,
          pageSize: 10,
          columns: [
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
            ),
            FitGridColumn<Employee>(
              id: 'index',
              label: 'Index',
              value: (e) => '',
              cellBuilder: (context, row, index) {
                indices.add(index);
                return Text('#$index');
              },
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();

    expect(find.text('#10'), findsOneWidget);
    expect(find.text('#0'), findsNothing);
    expect(indices, contains(19));
  });

  testWidgets('new rows rebuild the cells in place', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: withButtons((_) {}),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    expect(find.text('Open Person 0'), findsOneWidget);

    controller.data.rows = const [Employee('Zed', 'Engineer', 1)];
    await tester.pump();

    expect(find.text('Open Zed'), findsOneWidget);
    expect(find.text('Open Person 0'), findsNothing);
  });

  testWidgets('removing the builder column removes its widgets', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: withButtons((_) {}),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    expect(find.byType(TextButton), findsNWidgets(5));

    controller.columns.setVisible('action', false);
    await tester.pump();

    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('a button in a cell owns its tap; the row is not selected', (
    tester,
  ) async {
    final pressed = <int>[];
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: withButtons(pressed.add),
      selectionMode: FitGridSelectionMode.single,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));

    // A slow press: longer than the tap timeout, which is exactly when the
    // grid's own tap-down would otherwise fire as well.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Open Person 3')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(pressed, [3]);
    expect(controller.selection.selected, isEmpty);
  });

  testWidgets('a passive widget in a cell still selects the row', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      selectionMode: FitGridSelectionMode.single,
      columns: [
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
        FitGridColumn<Employee>(
          id: 'pill',
          label: 'Role',
          value: (e) => e.role,
          cellBuilder: (context, row, index) => DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('pill ${row.name}'),
          ),
        ),
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));

    await tester.tap(find.text('pill Person 2'));
    await tester.pumpAndSettle();

    expect(controller.selection.selected, {2});
  });

  testWidgets('a widget scrolled under a pinned column cannot be pressed', (
    tester,
  ) async {
    final pressed = <int>[];
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          stretchColumnsToFill: false,
          columns: [
            ...withButtons(pressed.add, freeze: FitGridFreeze.start),
            for (var i = 0; i < 6; i++)
              FitGridColumn<Employee>(
                id: 'filler$i',
                label: 'Filler $i',
                value: (e) => 'x',
                width: const FitGridColumnWidth.fixed(200),
              ),
          ],
        ),
        size: const Size(600, 400),
      ),
    );
    final before = tester.getRect(find.text('Open Person 1'));

    // Scroll the action column (x 200..360) under the pinned name column
    // (x 0..200).
    await tester.drag(find.byType(FitGrid<Employee>), const Offset(-120, 0));
    await tester.pumpAndSettle();

    final after = tester.getRect(find.text('Open Person 1'));
    expect(after.left, lessThan(before.left));
    // Tap where the button now sits, inside the pinned band.
    final grid = tester.getTopLeft(find.byType(FitGrid<Employee>));
    await tester.tapAt(Offset(grid.dx + 150, after.center.dy));
    await tester.pumpAndSettle();
    expect(pressed, isEmpty);
  });
}
