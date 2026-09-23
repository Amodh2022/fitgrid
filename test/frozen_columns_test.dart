import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<FitGridColumn<Employee>> wideColumns({
  FitGridFreeze first = FitGridFreeze.none,
  FitGridFreeze last = FitGridFreeze.none,
}) => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    width: const FitGridColumnWidth.fixed(200),
    freeze: first,
  ),
  for (var i = 0; i < 5; i++)
    FitGridColumn<Employee>(
      id: 'filler$i',
      label: 'Filler $i',
      value: (e) => e.role,
      width: const FitGridColumnWidth.fixed(200),
    ),
  FitGridColumn<Employee>(
    id: 'salary',
    label: 'Salary',
    value: (e) => e.salary.toString(),
    width: const FitGridColumnWidth.fixed(200),
    freeze: last,
  ),
];

/// Scrolls the body sideways. A touch drag, not a mouse one: Flutter's
/// scrollables ignore mouse drags by default, so a test that used one would
/// pass while scrolling nothing.
Future<void> scrollRight(WidgetTester tester, double by) async {
  await tester.drag(find.byType(FitGrid<Employee>), Offset(-by, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a pinned column is pulled to the leading edge', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(20),
          // Declared last, pinned first: pinning reorders, or the feature would
          // only work for columns that were already at the edge.
          columns: <FitGridColumn<Employee>>[
            ...wideColumns().sublist(1),
            wideColumns().first.copyWith(freeze: FitGridFreeze.start),
          ],
          stretchColumnsToFill: false,
        ),
        size: const Size(600, 400),
      ),
    );

    expect(fitGridColumnIds().first, 'name');
    expect(fitGridColumnLeft('name'), 0);
  });

  testWidgets('a pinned column does not move when the body scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(20),
          columns: wideColumns(first: FitGridFreeze.start),
          stretchColumnsToFill: false,
        ),
        size: const Size(600, 400),
      ),
    );

    final pinnedBefore = fitGridColumnLeft('name');
    final scrollingBefore = fitGridColumnLeft('filler1');
    await scrollRight(tester, 300);

    expect(fitGridColumnLeft('name'), pinnedBefore);
    expect(fitGridColumnLeft('filler1'), lessThan(scrollingBefore));
  });

  testWidgets('a trailing pin sits against the far edge', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(20),
          columns: wideColumns(last: FitGridFreeze.end),
          stretchColumnsToFill: false,
        ),
        size: const Size(600, 400),
      ),
    );

    expect(fitGridColumnIds().last, 'salary');
    final section = fitGridSection();
    // 600 wide viewport, 200 wide column: flush against the trailing edge.
    expect(fitGridColumnLeft('salary'), closeTo(section.size.width - 200, 0.5));

    await scrollRight(tester, 400);
    expect(fitGridColumnLeft('salary'), closeTo(section.size.width - 200, 0.5));
  });

  testWidgets('the scroll extent excludes the pinned bands', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(20),
          columns: wideColumns(
            first: FitGridFreeze.start,
            last: FitGridFreeze.end,
          ),
          stretchColumnsToFill: false,
        ),
        size: const Size(600, 400),
      ),
    );

    final section = fitGridSection();
    // Seven columns of 200 = 1400 content. Two are pinned, leaving 1000 of
    // scrolling content in a band 600 - 400 = 200 wide.
    expect(section.columnLayout.totalWidth, 1400);
    expect(section.columnLayout.scrollableWidth, 1000);
    expect(section.maxHorizontalOffset, 800);
  });

  testWidgets('a pinned column hit-tests where it is drawn, not where it '
      'would have scrolled to', (tester) async {
    var tapped = '';
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(20),
          columns: wideColumns(first: FitGridFreeze.start),
          stretchColumnsToFill: false,
          onCellTap: (row, index, columnId) => tapped = columnId,
        ),
        size: const Size(600, 400),
      ),
    );

    await scrollRight(tester, 400);
    final section = fitGridSection();
    final origin = section.localToGlobal(Offset.zero);
    await tester.tapAt(origin + const Offset(100, 40));
    await tester.pump();

    expect(tapped, 'name');
  });

  testWidgets('pinning is mirrored under RTL', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(20),
          columns: wideColumns(first: FitGridFreeze.start),
          stretchColumnsToFill: false,
        ),
        size: const Size(600, 400),
        textDirection: TextDirection.rtl,
      ),
    );

    final section = fitGridSection();
    // The leading edge is the right one, so a leading pin ends up flush
    // against the right of the viewport.
    expect(fitGridColumnLeft('name'), closeTo(section.size.width - 200, 0.5));
  });

  testWidgets('nothing pinned means nothing changes', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(rows: makeRows(20), columns: columns()),
        size: const Size(600, 400),
      ),
    );

    final layout = fitGridSection().columnLayout;
    expect(layout.hasFrozenColumns, isFalse);
    expect(layout.leadingFrozenWidth, 0);
    expect(layout.scrollableWidth, layout.totalWidth);
  });
}
