import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Immutable rows, replaced on every commit — the case undo has to be careful
/// with, because the row object it recorded no longer exists.
class _Sheet {
  _Sheet() : rows = makeRows(10);

  List<Employee> rows;
  int commits = 0;
  late final FitGridController<Employee> controller = FitGridController(
    rows: rows,
    columns: <FitGridColumn<Employee>>[
      FitGridColumn<Employee>(
        id: 'name',
        label: 'Name',
        value: (e) => e.name,
        sortable: true,
        editor: FitGridEditor<Employee>(
          onCommit: (row, index, value) =>
              _write(row, Employee(value, row.role, row.salary)),
        ),
      ),
      FitGridColumn<Employee>(id: 'role', label: 'Role', value: (e) => e.role),
      FitGridColumn<Employee>(
        id: 'salary',
        label: 'Salary',
        value: (e) => '\$${e.salary}',
        sortable: true,
        comparator: (a, b) => a.salary.compareTo(b.salary),
        editor: FitGridEditor<Employee>(
          // The editor works in plain numbers; the cell paints a currency.
          initialText: (e) => '${e.salary}',
          validator: (_, v) => int.tryParse(v) == null ? 'Number' : null,
          onCommit: (row, index, value) =>
              _write(row, Employee(row.name, row.role, int.parse(value))),
        ),
      ),
    ],
  );

  /// Writes by finding the row by name — the model's identity — so the
  /// write lands on the right row whatever the sort.
  void _write(Employee old, Employee next) {
    commits++;
    final at = rows.indexWhere((e) => e.name == old.name);
    rows = List<Employee>.of(rows)..[at] = next;
    controller.data.rows = rows;
  }
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

Offset cellCentre(WidgetTester tester, int row, int column) {
  final section = fitGridSection();
  final origin = tester.getTopLeft(find.byType(FitGridSection));
  return origin +
      Offset(
        section.debugColumnLeft(column) +
            section.columnLayout.widths[column] / 2,
        section.rowOffsetAt(row) +
            section.rowHeightAt(row) / 2 -
            section.verticalOffset,
      );
}

void main() {
  test('the history records steps, forks on a new edit, and is bounded', () {
    final history = FitGridEditHistory(limit: 2);
    FitGridCellChange change(String before, String after) => FitGridCellChange(
      rowKey: 'r',
      rowIndex: 0,
      columnId: 'c',
      before: before,
      after: after,
    );

    history.record(<FitGridCellChange>[change('a', 'a')]);
    expect(history.canUndo, isFalse, reason: 'a no-op edit is not a step');

    history
      ..record(<FitGridCellChange>[change('a', 'b')])
      ..record(<FitGridCellChange>[change('b', 'c')])
      ..record(<FitGridCellChange>[change('c', 'd')]);
    expect(history.undoDepth, 2);

    final undo = history.takeUndo()!;
    expect(undo.single.after, 'c');
    expect(history.canRedo, isTrue);
    history.record(<FitGridCellChange>[change('c', 'x')]);
    expect(history.canRedo, isFalse);
  });

  testWidgets('Ctrl+Z undoes a typed edit, Ctrl+Shift+Z redoes it', (
    tester,
  ) async {
    final sheet = _Sheet();
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: sheet.controller, autofocus: true)),
    );
    await tester.pumpAndSettle();

    sheet.controller.editing.begin(2, 'salary');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(sheet.rows[2].salary, 999);

    // Focus is back on the grid once the editor closes.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tapAt(cellCentre(tester, 0, 1));
    await tester.pump(const Duration(milliseconds: 400));
    await press(
      tester,
      LogicalKeyboardKey.keyZ,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    // The editor's own text came back, not the painted "$50002".
    expect(sheet.rows[2].salary, 50002);

    await press(
      tester,
      LogicalKeyboardKey.keyZ,
      with_: <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ],
    );
    expect(sheet.rows[2].salary, 999);
    await press(
      tester,
      LogicalKeyboardKey.keyZ,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    await press(
      tester,
      LogicalKeyboardKey.keyY,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    expect(sheet.rows[2].salary, 999);
  });

  testWidgets('a paste is one step, however many cells', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': 'A\tx\t1\nB\tx\t2\nC\tx\t3'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final sheet = _Sheet();
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: sheet.controller,
          cellSelection: true,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(cellCentre(tester, 0, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await press(
      tester,
      LogicalKeyboardKey.keyV,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    expect(sheet.rows.take(3).map((e) => '${e.name}:${e.salary}'), <String>[
      'A:1',
      'B:2',
      'C:3',
    ]);
    expect(sheet.controller.history.undoDepth, 1);

    expect(sheet.controller.undo(), isTrue);
    await tester.pumpAndSettle();
    expect(sheet.rows.take(3).map((e) => '${e.name}:${e.salary}'), <String>[
      'Person 0:50000',
      'Person 1:50001',
      'Person 2:50002',
    ]);
    expect(sheet.controller.undo(), isFalse);
  });

  testWidgets('undo finds its row after a sort, by rowKey', (tester) async {
    final sheet = _Sheet();
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(controller: sheet.controller, rowKey: (e) => e.name),
      ),
    );
    sheet.controller.editing.begin(0, 'salary');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    sheet.controller.toggleSort('salary');
    sheet.controller.toggleSort('salary'); // Person 0 is now last
    await tester.pumpAndSettle();
    sheet.controller.undo();
    await tester.pumpAndSettle();
    expect(sheet.rows.firstWhere((e) => e.name == 'Person 0').salary, 50000);
    expect(sheet.commits, 2);
  });

  testWidgets('enableUndo: false records nothing', (tester) async {
    final sheet = _Sheet();
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: sheet.controller, enableUndo: false)),
    );
    sheet.controller.editing.begin(0, 'name');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(sheet.rows[0].name, 'Zed');
    expect(sheet.controller.history.canUndo, isFalse);
  });
}
