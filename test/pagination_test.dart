import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/src/widgets/fitgrid_section.dart';
import 'package:fitgrid/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  const _Row(this.name);
  final String name;
}

List<_Row> _rows(int count) => <_Row>[
  for (var i = 0; i < count; i++) _Row('Person $i'),
];

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData.light(useMaterial3: true),
  home: Scaffold(
    body: Center(child: SizedBox(width: 700, height: 500, child: child)),
  ),
);

FitGridController<_Row> _controller(int rowCount) => FitGridController<_Row>(
  rows: _rows(rowCount),
  columns: <FitGridColumn<_Row>>[
    FitGridColumn<_Row>(
      id: 'name',
      label: 'Name',
      value: (r) => r.name,
      sortable: true,
    ),
  ],
);

void main() {
  group('FitGridPaginationState', () {
    test('page arithmetic, including the short last page', () {
      final pagination = FitGridPaginationState(enabled: true, pageSize: 25)
        ..rowCount = 60;
      addTearDown(pagination.dispose);

      expect(pagination.pageCount, 3);
      expect(pagination.rowsOnPage, 25);

      pagination.last();
      expect(pagination.pageIndex, 2);
      expect(pagination.firstRowIndex, 50);
      expect(pagination.endRowIndex, 60);
      expect(pagination.rowsOnPage, 10);
      expect(pagination.hasNext, isFalse);
    });

    test('an empty grid is still page 1 of 1', () {
      final pagination = FitGridPaginationState(enabled: true)..rowCount = 0;
      addTearDown(pagination.dispose);

      expect(pagination.pageCount, 1);
      expect(pagination.rowsOnPage, 0);
      expect(pagination.hasNext, isFalse);
      expect(pagination.hasPrevious, isFalse);
    });

    test('shrinking the data pulls the page back into range', () {
      final pagination = FitGridPaginationState(enabled: true, pageSize: 10)
        ..rowCount = 100
        ..last();
      addTearDown(pagination.dispose);
      expect(pagination.pageIndex, 9);

      pagination.rowCount = 12;
      expect(pagination.pageIndex, 1);
      expect(pagination.rowsOnPage, 2);
    });

    test('changing the page size keeps the current rows in view', () {
      final pagination = FitGridPaginationState(enabled: true, pageSize: 10)
        ..rowCount = 200
        ..pageIndex = 5; // rows 50-59
      addTearDown(pagination.dispose);

      pagination.pageSize = 25;
      // Row 50 is still on screen rather than the user being thrown to the top.
      expect(pagination.firstRowIndex, lessThanOrEqualTo(50));
      expect(pagination.endRowIndex, greaterThan(50));
    });

    test('revealRow moves to the page holding it', () {
      final pagination = FitGridPaginationState(enabled: true, pageSize: 25)
        ..rowCount = 1000
        ..revealRow(603);
      addTearDown(pagination.dispose);

      expect(pagination.pageIndex, 24);
      expect(pagination.firstRowIndex, 600);
    });
  });

  group('FitGridPageView', () {
    test('reads through to the source without copying', () {
      final source = _rows(100);
      final page = FitGridPageView<_Row>(source, 25, 25);

      expect(page.length, 25);
      expect(page.first.name, 'Person 25');
      expect(page.last.name, 'Person 49');
      expect(identical(page[0], source[25]), isTrue);
    });

    test('is read-only', () {
      final page = FitGridPageView<_Row>(_rows(10), 0, 5);
      expect(() => page[0] = const _Row('x'), throwsUnsupportedError);
      expect(() => page.length = 2, throwsUnsupportedError);
    });
  });

  group('paginated grid', () {
    testWidgets('renders one page and reports the whole dataset', (
      tester,
    ) async {
      final controller = _controller(1000);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          FitGrid<_Row>(controller: controller, paginated: true, pageSize: 25),
        ),
      );

      expect(fitGridRowCount(), 25);
      expect(fitGridCellText(row: 0, column: 0), 'Person 0');

      controller.pagination.next();
      await tester.pump();

      expect(fitGridCellText(row: 0, column: 0), 'Person 25');
      expect(controller.pagination.pageCount, 40);
    });

    testWidgets('column widths do not jump between pages', (tester) async {
      // Page 1 holds short names, a later page holds a very long one. Measuring
      // the page rather than the dataset would resize the column mid-paging.
      final rows = <_Row>[
        for (var i = 0; i < 60; i++)
          _Row(i == 55 ? 'An Extremely Long Name Indeed' : 'P$i'),
      ];
      final controller = FitGridController<_Row>(
        rows: rows,
        columns: <FitGridColumn<_Row>>[
          FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          FitGrid<_Row>(
            controller: controller,
            paginated: true,
            pageSize: 25,
            stretchColumnsToFill: false,
          ),
        ),
      );

      final onPageOne = fitGridColumnWidth('name');
      controller.pagination.last();
      await tester.pump();

      expect(fitGridColumnWidth('name'), onPageOne);
    });

    testWidgets('taps and selection speak in global row indices', (
      tester,
    ) async {
      final taps = <int>[];
      final controller = _controller(100);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          FitGrid<_Row>(
            controller: controller,
            paginated: true,
            pageSize: 25,
            onRowTap: (row, index) => taps.add(index),
          ),
        ),
      );

      controller.pagination.next();
      await tester.pump();

      final section = fitGridSection();
      final topLeft = tester.getTopLeft(find.byType(FitGridSection));
      await tester.tapAt(
        topLeft +
            Offset(20, section.rowOffsetAt(2) + section.rowHeightAt(2) / 2),
      );
      await tester.pump();

      // Third row of page two is row 27 of the dataset, not row 2.
      expect(taps, <int>[27]);
    });

    testWidgets('sorting keeps the page and repages the sorted view', (
      tester,
    ) async {
      final controller = _controller(100);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          FitGrid<_Row>(controller: controller, paginated: true, pageSize: 10),
        ),
      );

      controller.pagination.next();
      await tester.pump();
      expect(fitGridCellText(row: 0, column: 0), 'Person 10');

      controller.toggleSort('name');
      await tester.pump();

      // Still page two, now of the sorted order — string sort, so 'Person 18'
      // lands where 'Person 10' was.
      expect(controller.pagination.pageIndex, 1);
      expect(fitGridRowCount(), 10);
    });

    testWidgets('the pager drives the grid', (tester) async {
      final controller = _controller(60);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          FitGrid<_Row>(controller: controller, paginated: true, pageSize: 25),
        ),
      );

      expect(find.text('1–25 of 60'), findsOneWidget);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pump();
      expect(find.text('26–50 of 60'), findsOneWidget);

      await tester.tap(find.byTooltip('Last page'));
      await tester.pump();
      expect(find.text('51–60 of 60'), findsOneWidget);
      expect(fitGridRowCount(), 10);
    });

    testWidgets('a custom pager replaces the built-in one', (tester) async {
      final controller = _controller(60);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          FitGrid<_Row>(
            controller: controller,
            paginated: true,
            pageSize: 25,
            pagerBuilder: (context, pagination) => Text(
              'page ${pagination.pageIndex + 1}/${pagination.pageCount}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );

      expect(find.text('page 1/3'), findsOneWidget);
      expect(find.byType(FitGridPager), findsNothing);
    });

    testWidgets('no pager and no paging when it is off', (tester) async {
      final controller = _controller(60);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(FitGrid<_Row>(controller: controller)));

      expect(find.byType(FitGridPager), findsNothing);
      expect(fitGridRowCount(), 60);
    });
  });
}
