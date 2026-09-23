import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<FitGridController<Employee>> pumpGrid(
  WidgetTester tester, {
  int rows = 100,
  FitGridSelectionMode mode = FitGridSelectionMode.multiple,
  Size size = const Size(800, 400),
}) async {
  final controller = FitGridController<Employee>(
    rows: makeRows(rows),
    columns: columns(),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    host(
      FitGrid<Employee>(
        controller: controller,
        selectionMode: mode,
        autofocus: true,
      ),
      size: size,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  List<LogicalKeyboardKey> with_ = const <LogicalKeyboardKey>[],
}) async {
  for (final modifier in with_) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(key);
  for (final modifier in with_.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arrows move a cell at a time', (tester) async {
    final controller = await pumpGrid(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.focus.rowIndex, 0);
    expect(controller.focus.columnId, 'name');

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.focus.rowIndex, 1);
    expect(controller.focus.columnId, 'role');

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.focus.columnId, 'name');
  });

  testWidgets('the focus clamps at the edges rather than wrapping', (
    tester,
  ) async {
    final controller = await pumpGrid(tester, rows: 3);

    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.focus.rowIndex, 0);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.focus.columnId, 'name');
  });

  testWidgets('Ctrl+End jumps to the last row and scrolls to it', (
    tester,
  ) async {
    final controller = await pumpGrid(tester, rows: 500);

    await press(
      tester,
      LogicalKeyboardKey.end,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    expect(controller.focus.rowIndex, 499);

    // The scroll has to have followed, or the focus ring is somewhere the user
    // cannot see.
    final section = fitGridSection();
    expect(section.firstVisibleRow + section.visibleRowCount, greaterThan(490));
  });

  testWidgets('Home and End move along the row', (tester) async {
    final controller = await pumpGrid(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.end);
    expect(controller.focus.columnId, 'salary');
    await press(tester, LogicalKeyboardKey.home);
    expect(controller.focus.columnId, 'name');
  });

  testWidgets('Page Down travels about a viewport', (tester) async {
    final controller = await pumpGrid(tester, rows: 500);

    await press(tester, LogicalKeyboardKey.arrowDown);
    final before = controller.focus.rowIndex!;
    await press(tester, LogicalKeyboardKey.pageDown);
    final moved = controller.focus.rowIndex! - before;

    expect(moved, greaterThan(3));
    expect(moved, lessThan(fitGridSection().visibleRowCount));
  });

  testWidgets('Space toggles the focused row, Shift+Arrow extends', (
    tester,
  ) async {
    final controller = await pumpGrid(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.space);
    expect(controller.selection.selected, <int>{0});

    await press(
      tester,
      LogicalKeyboardKey.arrowDown,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft],
    );
    await press(
      tester,
      LogicalKeyboardKey.arrowDown,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft],
    );
    expect(controller.selection.selected, <int>{0, 1, 2});
  });

  testWidgets('Ctrl+A selects everything and Escape clears it', (tester) async {
    final controller = await pumpGrid(tester, rows: 25);

    await press(
      tester,
      LogicalKeyboardKey.keyA,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    expect(controller.selection.length, 25);

    await press(tester, LogicalKeyboardKey.escape);
    expect(controller.selection.isEmpty, isTrue);
  });

  testWidgets('Ctrl+A does nothing in single-selection mode', (tester) async {
    final controller = await pumpGrid(
      tester,
      rows: 25,
      mode: FitGridSelectionMode.single,
    );

    await press(
      tester,
      LogicalKeyboardKey.keyA,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    expect(controller.selection.isEmpty, isTrue);
  });

  testWidgets('Ctrl+C copies the selection as tab-separated rows', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final controller = await pumpGrid(tester);
    controller.selection.select(<int>[0, 1]);
    await tester.pumpAndSettle();

    await press(
      tester,
      LogicalKeyboardKey.keyC,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );

    expect(copied, 'Person 0\tEngineer\t50000\nPerson 1\tDesigner\t50001');
  });

  testWidgets('Enter opens an editor on an editable cell', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: <FitGridColumn<Employee>>[
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
          editor: FitGridEditor<Employee>(onCommit: (_, _, _) {}),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, autofocus: true)),
    );
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);

    expect(controller.editing.isEditing, isTrue);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('keyboardNavigation: false leaves the keys alone', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          keyboardNavigation: false,
          autofocus: true,
        ),
      ),
    );
    await press(tester, LogicalKeyboardKey.arrowDown);

    expect(controller.focus.hasFocus, isFalse);
  });
}
