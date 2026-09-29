import 'package:example/screens/live_updates.dart';
import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live updates tick under a filter with two frozen columns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: LiveUpdatesScreen(rowCount: 4000)),
    );
    // Updates arrive on a timer, so the page never settles; step it instead.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Selection column first, then the two frozen columns.
    final ids = fitGridColumnIds();
    expect(ids.sublist(0, 3), <String>[
      FitGrid.selectionColumnId,
      'id',
      'status',
    ]);
    // The status filter is on: only Active and Pending rows are shown.
    expect(fitGridRowCount(), lessThan(4000));
    final status = ids.indexOf('status');
    for (var row = 0; row < 10; row++) {
      expect(<String>[
        'Active',
        'Pending',
      ], contains(fitGridCellText(row: row, column: status)));
    }
    expect(find.textContaining('Ticks'), findsOneWidget);
    expect(fitGridLaidOutRowCount(), lessThan(80));

    await tester.tap(find.text('Pause updates'));
    await tester.pump();
    expect(find.text('Resume updates'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
