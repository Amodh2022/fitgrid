@Tags(<String>['golden'])
library;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

FitGridThemeData themed({List<double>? dash, double? ticks, double? header}) =>
    FitGridThemeData.fromTheme(ThemeData.light(useMaterial3: true)).copyWith(
      rowDividerDash: dash,
      columnDividerExtent: ticks,
      headerDividerExtent: header,
      rowDivider: const Color(0x33000000),
      columnDivider: const Color(0xB3000000),
    );

void main() {
  testWidgets('dashed rows, short ticks and short header dividers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 260,
              child: RepaintBoundary(
                child: FitGrid<Employee>(
                  rows: makeRows(6),
                  columns: columns(),
                  striped: false,
                  theme: themed(dash: const [3, 2], ticks: 12, header: 34),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/dividers.png'),
    );
  });

  testWidgets('a header divider is as long as asked, and centred', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(3),
          columns: columns(),
          theme: themed(header: 20),
        ),
      ),
    );
    final lines = find.descendant(
      of: find.byType(FitGridHeader<Employee>),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 20 && w.width == 1,
      ),
    );
    // One between each pair of the three columns.
    expect(lines, findsNWidgets(2));
    final header = tester.getRect(find.byType(FitGridHeader<Employee>));
    expect(tester.getCenter(lines.first).dy, closeTo(header.center.dy, 1));
  });

  testWidgets('odd patterns, pinned bands and scrolling paint without error', (
    tester,
  ) async {
    final cols = columns();
    cols[0] = cols[0].copyWith(freeze: FitGridFreeze.start);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(500),
          columns: <FitGridColumn<Employee>>[
            ...cols,
            for (var i = 0; i < 12; i++)
              FitGridColumn<Employee>(
                id: 'extra$i',
                label: 'Extra $i',
                value: (e) => e.role,
                width: const FitGridColumnWidth.fixed(140),
              ),
          ],
          theme: themed(dash: const [1, 1, 5], ticks: 100, header: 10),
        ),
        size: const Size(500, 300),
      ),
    );
    await tester.drag(find.byType(FitGrid<Employee>), const Offset(-900, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('the options take part in equality', () {
    expect(themed(dash: const [3, 2]), themed(dash: const [3, 2]));
    expect(themed(dash: const [3, 2]) == themed(dash: const [2, 3]), isFalse);
    expect(themed(ticks: 12) == themed(), isFalse);
    expect(themed(header: 34).hashCode, themed(header: 34).hashCode);
  });
}
