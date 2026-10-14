import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The centre of a painted cell, in global coordinates.
Offset _cellCentre(int row, String columnId) {
  final section = fitGridSection();
  final x = fitGridColumnLeft(columnId) + fitGridColumnWidth(columnId) / 2;
  final y = fitGridRowOffset(row) + fitGridRowHeight(row) / 2;
  return section.localToGlobal(Offset(x, y));
}

Future<void> _rightClick(WidgetTester tester, int row, String columnId) async {
  await tester.tapAt(
    _cellCentre(row, columnId),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

/// What the grid puts on the clipboard.
List<String> _useClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
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
  return copied;
}

List<FitGridColumn<Employee>> _filterable() => <FitGridColumn<Employee>>[
  for (final column in columns())
    switch (column.id) {
      'role' => column.copyWith(filter: const FitGridFilterSpec.values()),
      'salary' => column.copyWith(
        filter: FitGridFilterSpec<Employee>.number((e) => e.salary),
      ),
      _ => column.copyWith(filter: const FitGridFilterSpec.text()),
    },
];

Future<FitGridController<Employee>> _pump(
  WidgetTester tester, {
  List<FitGridColumn<Employee>>? cols,
}) async {
  final controller = FitGridController<Employee>(
    rows: makeRows(10),
    columns: cols ?? _filterable(),
    selectionMode: FitGridSelectionMode.multiple,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
  return controller;
}

void main() {
  testWidgets('the default menu offers copy, filter and sort', (tester) async {
    await _pump(tester);
    await _rightClick(tester, 2, 'name');

    for (final label in <String>[
      'Copy',
      'Copy with headers',
      'Copy cell',
      'Show only “Person 2”',
      'Hide “Person 2”',
      'Sort ascending',
      'Sort descending',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Clear all filters'), findsNothing);
    expect(find.text('Expand all groups'), findsNothing);
  });

  testWidgets('show only filters to the value under the pointer', (
    tester,
  ) async {
    final controller = await _pump(tester);
    await _rightClick(tester, 1, 'role');
    await tester.tap(find.text('Show only “Designer”'));
    await tester.pumpAndSettle();

    expect(controller.data.view.every((e) => e.role == 'Designer'), isTrue);
    expect(controller.data.view, hasLength(5));
    // A checklist column has no "hide" item: excluding one value of a
    // checklist is ticking all the others, which the dialog does.
    await _rightClick(tester, 0, 'role');
    expect(find.text('Hide “Designer”'), findsNothing);

    await tester.tap(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    expect(controller.data.view, hasLength(10));
  });

  testWidgets('hide filters a number out by value', (tester) async {
    final controller = await _pump(tester);
    await _rightClick(tester, 3, 'salary');
    await tester.tap(find.text('Hide “50003”'));
    await tester.pumpAndSettle();

    expect(controller.data.view, hasLength(9));
    expect(controller.data.view.any((e) => e.salary == 50003), isFalse);
  });

  testWidgets('sort from the menu sorts by that column', (tester) async {
    final controller = await _pump(tester);
    await _rightClick(tester, 0, 'salary');
    await tester.tap(find.text('Sort descending'));
    await tester.pumpAndSettle();

    expect(controller.data.view.first.salary, 50009);
    await _rightClick(tester, 0, 'salary');
    expect(find.text('Sort descending'), findsNothing, reason: 'already');
  });

  testWidgets('copy with headers puts the labels first', (tester) async {
    final copied = _useClipboard(tester);
    await _pump(tester);
    await _rightClick(tester, 2, 'name');
    await tester.tap(find.text('Copy with headers'));
    await tester.pumpAndSettle();

    expect(copied.single, 'Name\tRole\tSalary\nPerson 2\tEngineer\t50002');
  });

  testWidgets('copy cell copies just the cell under the pointer', (
    tester,
  ) async {
    final copied = _useClipboard(tester);
    await _pump(tester);
    await _rightClick(tester, 4, 'role');
    await tester.tap(find.text('Copy cell'));
    await tester.pumpAndSettle();

    expect(copied.single, 'Engineer');
  });

  testWidgets('a grouped grid offers expand and collapse all', (tester) async {
    final controller = await _pump(tester);
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    await tester.pumpAndSettle();
    await _rightClick(tester, 1, 'name');

    expect(find.text('Expand all groups'), findsOneWidget);
    expect(find.text('Collapse all groups'), findsOneWidget);
  });

  testWidgets('a builder can extend the defaults', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: _filterable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          contextMenuBuilder: (context, target) => <PopupMenuEntry<void>>[
            ...target.defaultItems,
            const PopupMenuDivider(),
            const PopupMenuItem<void>(child: Text('Open record')),
          ],
        ),
      ),
    );
    await _rightClick(tester, 2, 'name');

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Open record'), findsOneWidget);
  });

  testWidgets('long values are shortened in the menu', (tester) async {
    final controller = FitGridController<Employee>(
      rows: const <Employee>[
        Employee('A name long enough not to fit in a menu item', 'x', 1),
      ],
      columns: _filterable(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await _rightClick(tester, 0, 'name');

    expect(find.text('Show only “A name long enough not …”'), findsOneWidget);
  });
}
