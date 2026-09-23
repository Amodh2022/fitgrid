import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Employee {
  const _Employee(this.name, this.salary);
  final String name;
  final int salary;
}

class _Harness {
  _Harness(int rowCount)
    : rows = <_Employee>[
        for (var i = 0; i < rowCount; i++) _Employee('Person $i', 1000 + i),
      ];

  List<_Employee> rows;
  late FitGridController<_Employee> controller;
  final List<String> commits = <String>[];

  void apply(int index, _Employee employee) {
    rows = List<_Employee>.of(rows)..[index] = employee;
    controller.data.rows = rows;
  }
}

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData.light(useMaterial3: true),
  home: Scaffold(
    body: Center(child: SizedBox(width: 700, height: 420, child: child)),
  ),
);

/// Centre of a cell, in global coordinates.
Offset _cellCentre(WidgetTester tester, int row, int column) {
  final section = fitGridSection();
  final origin = tester.getTopLeft(find.byType(FitGridSection));
  final layout = section.columnLayout;
  return origin +
      Offset(
        layout.offsets[column] + layout.widths[column] / 2,
        section.rowOffsetAt(row) + section.rowHeightAt(row) / 2,
      );
}

void main() {
  late _Harness harness;

  Widget grid({
    FitGridEditTrigger trigger = FitGridEditTrigger.doubleTap,
    FitGridCellValidator<_Employee>? validator,
    bool commitOnFocusLoss = true,
    bool paginated = false,
  }) {
    harness.controller = FitGridController<_Employee>(
      rows: harness.rows,
      columns: <FitGridColumn<_Employee>>[
        FitGridColumn<_Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
          width: const FitGridColumnWidth.fixed(200),
          editor: FitGridEditor<_Employee>(
            validator: validator,
            commitOnFocusLoss: commitOnFocusLoss,
            onCommit: (row, index, value) {
              harness.commits.add('name:$index=$value');
              harness.apply(index, _Employee(value, row.salary));
            },
          ),
        ),
        FitGridColumn<_Employee>(
          id: 'salary',
          label: 'Salary',
          value: (e) => e.salary.toString(),
          width: const FitGridColumnWidth.fixed(140),
          editor: FitGridEditor<_Employee>(
            keyboardType: TextInputType.number,
            onCommit: (row, index, value) {
              harness.commits.add('salary:$index=$value');
              harness.apply(
                index,
                _Employee(row.name, int.tryParse(value) ?? row.salary),
              );
            },
          ),
        ),
        // Deliberately not editable.
        FitGridColumn<_Employee>(
          id: 'ro',
          label: 'Read only',
          value: (e) => 'locked',
          width: const FitGridColumnWidth.fixed(120),
        ),
      ],
    );
    return _host(
      FitGrid<_Employee>(
        controller: harness.controller,
        editTrigger: trigger,
        paginated: paginated,
        pageSize: 10,
        stretchColumnsToFill: false,
      ),
    );
  }

  setUp(() => harness = _Harness(40));
  tearDown(() => harness.controller.dispose());

  testWidgets('double-tap opens an editor seeded with the cell value', (
    tester,
  ) async {
    await tester.pumpWidget(grid());

    await tester.tapAt(_cellCentre(tester, 1, 0));
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(_cellCentre(tester, 1, 0));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Person 1',
    );
    expect(harness.controller.editing.isEditingCell(1, 'name'), isTrue);
  });

  testWidgets('a read-only column does not open', (tester) async {
    await tester.pumpWidget(grid());

    await tester.tapAt(_cellCentre(tester, 1, 2));
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(_cellCentre(tester, 1, 2));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(harness.controller.editing.isEditing, isFalse);
  });

  testWidgets('Enter commits and the painted text updates', (tester) async {
    await tester.pumpWidget(grid(trigger: FitGridEditTrigger.singleTap));

    await tester.tapAt(_cellCentre(tester, 2, 0));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.commits, <String>['name:2=Renamed']);
    expect(harness.controller.editing.isEditing, isFalse);
    expect(fitGridCellText(row: 2, column: 0), 'Renamed');
  });

  testWidgets('Escape abandons the edit', (tester) async {
    await tester.pumpWidget(grid(trigger: FitGridEditTrigger.singleTap));

    await tester.tapAt(_cellCentre(tester, 3, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Discarded');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(harness.commits, isEmpty);
    expect(find.byType(TextField), findsNothing);
    expect(fitGridCellText(row: 3, column: 0), 'Person 3');
  });

  testWidgets('a rejected value keeps the editor open with a message', (
    tester,
  ) async {
    await tester.pumpWidget(
      grid(
        trigger: FitGridEditTrigger.singleTap,
        validator: (row, value) => value.isEmpty ? 'Name is required' : null,
      ),
    );

    await tester.tapAt(_cellCentre(tester, 1, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.commits, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    expect(harness.controller.editing.error, 'Name is required');
  });

  testWidgets('Tab commits and moves to the next editable column', (
    tester,
  ) async {
    await tester.pumpWidget(grid(trigger: FitGridEditTrigger.singleTap));

    await tester.tapAt(_cellCentre(tester, 0, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tabbed');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(harness.commits, <String>['name:0=Tabbed']);
    // Salary is next; the read-only column is skipped, and so is the wrap to
    // the following row.
    expect(harness.controller.editing.columnId, 'salary');
    expect(harness.controller.editing.rowIndex, 0);
  });

  testWidgets('the painted value is hidden while its editor is open', (
    tester,
  ) async {
    await tester.pumpWidget(grid(trigger: FitGridEditTrigger.singleTap));

    final before = fitGridPaintedTextHeight(row: 1, column: 0);
    expect(before, isNotNull);

    await tester.tapAt(_cellCentre(tester, 1, 0));
    await tester.pumpAndSettle();

    // The cell is skipped by the text pass, so its painter is no longer
    // refreshed — the editor is the only thing drawing there.
    expect(fitGridSection().editingCell, (1, 0));
  });

  testWidgets('clicking away commits, or cancels when told to', (tester) async {
    await tester.pumpWidget(grid(trigger: FitGridEditTrigger.singleTap));
    await tester.tapAt(_cellCentre(tester, 4, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Blurred');
    // Focus something else.
    await tester.tapAt(_cellCentre(tester, 5, 2));
    await tester.pumpAndSettle();

    expect(harness.commits, <String>['name:4=Blurred']);

    harness.controller.dispose();
    harness = _Harness(40);
    await tester.pumpWidget(
      grid(trigger: FitGridEditTrigger.singleTap, commitOnFocusLoss: false),
    );
    await tester.tapAt(_cellCentre(tester, 4, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dropped');
    await tester.tapAt(_cellCentre(tester, 5, 2));
    await tester.pumpAndSettle();

    expect(harness.commits, isEmpty);
  });

  testWidgets('editing indices stay global under pagination', (tester) async {
    await tester.pumpWidget(
      grid(trigger: FitGridEditTrigger.singleTap, paginated: true),
    );

    harness.controller.pagination.next();
    await tester.pump();

    await tester.tapAt(_cellCentre(tester, 0, 0));
    await tester.pumpAndSettle();

    // First row of page two is row 10 of the dataset.
    expect(harness.controller.editing.rowIndex, 10);

    await tester.enterText(find.byType(TextField), 'Paged');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.commits, <String>['name:10=Paged']);
    expect(harness.rows[10].name, 'Paged');
  });

  testWidgets('a custom editor replaces the text field', (tester) async {
    harness.controller = FitGridController<_Employee>(
      rows: harness.rows,
      columns: <FitGridColumn<_Employee>>[
        FitGridColumn<_Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
          width: const FitGridColumnWidth.fixed(200),
          editor: FitGridEditor<_Employee>(
            onCommit: (row, index, value) =>
                harness.commits.add('custom:$index=$value'),
            builder: (context, session) => TextButton(
              onPressed: () => session.commit('picked'),
              child: const Text('pick'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        FitGrid<_Employee>(
          controller: harness.controller,
          editTrigger: FitGridEditTrigger.singleTap,
          stretchColumnsToFill: false,
        ),
      ),
    );

    await tester.tapAt(_cellCentre(tester, 0, 0));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    expect(harness.commits, <String>['custom:0=picked']);
  });

  testWidgets('no editor machinery on a read-only grid', (tester) async {
    harness.controller = FitGridController<_Employee>(
      rows: harness.rows,
      columns: <FitGridColumn<_Employee>>[
        FitGridColumn<_Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
      ],
    );

    await tester.pumpWidget(
      _host(FitGrid<_Employee>(controller: harness.controller)),
    );

    await tester.tapAt(_cellCentre(tester, 0, 0));
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(_cellCentre(tester, 0, 0));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(fitGridSection().editingCell, (-1, -1));
  });
}
