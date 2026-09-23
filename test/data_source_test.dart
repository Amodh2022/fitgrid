import 'dart:async';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// A source that records what it was asked for, so a test can assert on the
/// requests as well as the rows.
class RecordingSource {
  RecordingSource({int total = 1000, int pageSize = 50}) {
    source = FitGridAsyncDataSource<Employee>(
      pageSize: pageSize,
      maxCachedPages: 4,
      initialRowCount: total,
      fetch: (request) async {
        requests.add(request);
        return FitGridPageResult<Employee>(
          rows: <Employee>[
            for (
              var i = request.offset;
              i < request.offset + request.limit && i < total;
              i++
            )
              Employee('Person $i', 'Engineer', 50000 + i),
          ],
          totalCount: total,
        );
      },
    );
  }

  late final FitGridAsyncDataSource<Employee> source;
  final List<FitGridPageRequest> requests = <FitGridPageRequest>[];
}

void main() {
  testWidgets('a source-backed grid shows its total and fills as it loads', (
    tester,
  ) async {
    final recorder = RecordingSource(total: 5000);
    final source = recorder.source;
    addTearDown(source.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(dataSource: source, columns: columns()),
        size: const Size(800, 400),
      ),
    );
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 5000);
    expect(fitGridCellText(row: 0, column: 0), 'Person 0');
    // Virtualization still holds: nobody fetched five thousand rows.
    expect(fitGridLaidOutRowCount(), lessThan(40));
    expect(recorder.requests.length, lessThan(3));
  });

  testWidgets('an unloaded row paints blank rather than shifting the layout', (
    tester,
  ) async {
    final source = FitGridAsyncDataSource<Employee>(
      fetch: (_) => Future<FitGridPageResult<Employee>>.delayed(
        const Duration(seconds: 1),
        () => const FitGridPageResult<Employee>(rows: <Employee>[]),
      ),
      initialRowCount: 500,
    );
    addTearDown(source.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(dataSource: source, columns: columns()),
        size: const Size(800, 400),
      ),
    );
    await tester.pump();

    expect(fitGridRowCount(), 500);
    expect(fitGridCellText(row: 0, column: 0), '');
    // The geometry is already right, so nothing jumps when the rows land.
    expect(fitGridRowHeight(0), greaterThan(0));

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the page cache stays bounded while scrolling', (tester) async {
    final recorder = RecordingSource(total: 10000, pageSize: 20);
    final source = recorder.source;
    addTearDown(source.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(dataSource: source, columns: columns()),
        size: const Size(800, 400),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(FitGrid<Employee>), const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    expect(source.cachedPageCount, lessThanOrEqualTo(6));
  });

  test('sorting is forwarded, and stale pages are dropped', () async {
    final recorder = RecordingSource(total: 100);
    final source = recorder.source;
    addTearDown(source.dispose);

    source.loadWindow(0, 10);
    await Future<void>.delayed(Duration.zero);
    expect(source.cachedPageCount, 1);

    source.sortBy('salary', FitGridSortDirection.descending);
    expect(source.cachedPageCount, 0);

    source.loadWindow(0, 10);
    await Future<void>.delayed(Duration.zero);
    expect(recorder.requests.last.sortColumnId, 'salary');
    expect(
      recorder.requests.last.sortDirection,
      FitGridSortDirection.descending,
    );
  });

  test('a search resets the count, because the result set changed', () async {
    final recorder = RecordingSource(total: 100);
    final source = recorder.source;
    addTearDown(source.dispose);

    expect(source.rowCount, 100);
    source.search('engineer');
    expect(source.rowCount, 0);
    expect(source.cachedPageCount, 0);
  });

  test(
    'a backend that will not count grows the row count as pages land',
    () async {
      var served = 0;
      final source = FitGridAsyncDataSource<Employee>(
        pageSize: 10,
        fetch: (request) async {
          served++;
          return FitGridPageResult<Employee>(
            rows: <Employee>[
              for (var i = 0; i < (request.offset < 20 ? 10 : 4); i++)
                Employee('Person $i', 'Engineer', i),
            ],
          );
        },
      );
      addTearDown(source.dispose);

      source.loadWindow(0, 9);
      await Future<void>.delayed(Duration.zero);
      // A full page came back, so assume there is at least one more row.
      expect(source.rowCount, 11);

      source.loadWindow(20, 29);
      await Future<void>.delayed(Duration.zero);
      // A short page is the end of the data, and the count settles exactly.
      expect(source.rowCount, 24);
      expect(served, 2);
    },
  );

  testWidgets('a source and pagination cannot both be on', (tester) async {
    expect(
      () => FitGrid<Employee>(
        dataSource: RecordingSource().source,
        columns: columns(),
        paginated: true,
      ),
      throwsAssertionError,
    );
  });

  test('a fetch that lands after dispose is dropped quietly', () async {
    final pending = Completer<FitGridPageResult<Employee>>();
    final source = FitGridAsyncDataSource<Employee>(
      pageSize: 10,
      fetch: (_) => pending.future,
    );
    source.loadWindow(0, 9);
    expect(source.isLoading, isTrue);

    // The screen that owned the source is gone before the server answered.
    source.dispose();
    pending.complete(
      const FitGridPageResult<Employee>(rows: <Employee>[], totalCount: 0),
    );
    // Would throw "used after being disposed" if the answer still notified.
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets('a source that starts with no known rows still loads', (
    tester,
  ) async {
    // No initialRowCount: the grid has nothing to lay out, so nothing reports
    // a window. It has to ask for the first page anyway.
    final source = FitGridAsyncDataSource<Employee>(
      pageSize: 20,
      fetch: (request) async => FitGridPageResult<Employee>(
        rows: <Employee>[
          for (var i = request.offset; i < request.offset + 20; i++)
            Employee('Person $i', 'Engineer', 50000 + i),
        ],
        totalCount: 300,
      ),
    );
    addTearDown(source.dispose);

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(dataSource: source, columns: columns()),
        size: const Size(800, 400),
      ),
    );
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 300);
    expect(fitGridCellText(row: 0, column: 0), 'Person 0');

    // A search resets the count to zero, which is the same situation again.
    source.search('person');
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 300);
  });
}
