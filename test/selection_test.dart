import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Taps the cell at (row, column) by asking the render object where it is,
/// which is the only way to hit a painted cell.
Future<void> tapCell(WidgetTester tester, int row, int column) async {
  final section = fitGridSection();
  final origin = section.localToGlobal(Offset.zero);
  final left = section.debugColumnLeft(column);
  final top = section.rowOffsetAt(row) - section.verticalOffset;
  await tester.tapAt(
    origin +
        Offset(
          left + section.columnLayout.widths[column] / 2,
          top + section.rowHeightAt(row) / 2,
        ),
  );
  await tester.pump();
}

Future<void> withKey(
  WidgetTester tester,
  LogicalKeyboardKey key,
  Future<void> Function() body,
) async {
  await tester.sendKeyDownEvent(key);
  await body();
  await tester.sendKeyUpEvent(key);
}

void main() {
  testWidgets('selection is off by default', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tapCell(tester, 1, 0);

    expect(controller.selection.selected, isEmpty);
  });

  testWidgets('single selection replaces', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          selectionMode: FitGridSelectionMode.single,
        ),
      ),
    );

    await tapCell(tester, 1, 0);
    expect(controller.selection.selected, <int>{1});
    await tapCell(tester, 3, 0);
    expect(controller.selection.selected, <int>{3});
  });

  testWidgets('ctrl-click toggles and shift-click extends', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          selectionMode: FitGridSelectionMode.multiple,
        ),
      ),
    );

    await tapCell(tester, 1, 0);
    await withKey(
      tester,
      LogicalKeyboardKey.controlLeft,
      () => tapCell(tester, 4, 0),
    );
    expect(controller.selection.selected, <int>{1, 4});

    await tapCell(tester, 2, 0);
    await withKey(
      tester,
      LogicalKeyboardKey.shiftLeft,
      () => tapCell(tester, 5, 0),
    );
    expect(controller.selection.selected, <int>{2, 3, 4, 5});
  });

  testWidgets('onSelectionChanged reports global indices once per change', (
    tester,
  ) async {
    final seen = <Set<int>>[];
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(10),
          columns: columns(),
          selectionMode: FitGridSelectionMode.single,
          onSelectionChanged: seen.add,
        ),
      ),
    );

    await tapCell(tester, 2, 0);
    expect(seen, <Set<int>>[
      <int>{2},
    ]);
  });

  testWidgets('the selection column is painted, not built', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          selectionMode: FitGridSelectionMode.multiple,
          showSelectionColumn: true,
        ),
      ),
    );

    expect(fitGridColumnIds().first, FitGrid.selectionColumnId);
    // One Checkbox would be one widget per row. There are none: the box is a
    // glyph in the cell spec.
    expect(find.byType(Checkbox), findsNothing);

    expect(fitGridCellSpec(row: 0, column: 0).icon, isNotNull);
    await tapCell(tester, 0, 0);
    expect(controller.selection.selected, <int>{0});
    expect(fitGridCellSpec(row: 0, column: 0).semanticLabel, 'Selected');
  });

  testWidgets('the header box selects and clears everything', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(10),
      columns: columns(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          selectionMode: FitGridSelectionMode.multiple,
          showSelectionColumn: true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(controller.selection.length, 10);

    await tester.tap(find.byTooltip('Clear selection'));
    await tester.pumpAndSettle();
    expect(controller.selection, isA<FitGridSelectionState>());
    expect(controller.selection.isEmpty, isTrue);
  });

  testWidgets('switching to single mode drops all but one row', (tester) async {
    final selection = FitGridSelectionState()
      ..mode = FitGridSelectionMode.multiple
      ..select(<int>[1, 2, 3]);
    addTearDown(selection.dispose);

    selection.mode = FitGridSelectionMode.single;
    expect(selection.length, 1);

    selection.mode = FitGridSelectionMode.none;
    expect(selection.isEmpty, isTrue);
  });
}
