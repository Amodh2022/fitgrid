import 'package:example/screens/sort_million.dart';
import 'package:example/shared/demo_page.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loaded(WidgetTester tester) async {
  // Rows are generated with `compute`, which needs real time; the heartbeat
  // animates forever, so the page never settles and is stepped instead.
  for (
    var i = 0;
    i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('sorting measures the frame gap and shows the comparison', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: SortMillionScreen(sizes: <int>[2000, 3000])),
    );
    await _loaded(tester);
    expect(fitGridRowCount(), 3000);

    await tester.tap(find.text('Sort by Amount'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final amount = fitGridColumnIds().indexOf('amount');
    final first = double.parse(fitGridCellText(row: 0, column: amount));
    final second = double.parse(fitGridCellText(row: 1, column: amount));
    expect(first, lessThanOrEqualTo(second));
    Finder chip(String label) => find.descendant(
      of: find.byType(StatChip),
      matching: find.textContaining(label),
    );
    expect(chip('UI blocked'), findsOneWidget);
    expect(chip('Dropped frames'), findsOneWidget);
    expect(chip('Sorted in'), findsOneWidget);

    // The measured comparison is there, fitgrid first.
    await tester.tap(find.text('How other Flutter grids compare'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Syncfusion 34.2.9'), findsOneWidget);

    // Switching size reloads the rows.
    await tester.tap(find.text('2,000 rows'));
    await tester.pump();
    await _loaded(tester);
    expect(fitGridRowCount(), 2000);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
