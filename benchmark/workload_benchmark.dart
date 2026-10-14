// Million-row workload benchmark. Run with:
//
//     flutter test benchmark/workload_benchmark.dart
//
// `frame_benchmark.dart` shows that scrolling cost tracks the viewport. This
// one answers the next question a team asks: what do the operations that do
// walk every row cost — sorting, filtering, exporting — and how much memory
// does all of it take? Each is timed on its own, so a smooth scroll cannot hide
// a slow sort, and each is split into the data work (building the sorted or
// filtered view) and the frame that shows the result.
//
// It prints markdown tables and the machine they were measured on. Like the
// other benchmarks it is not a CI gate.

import 'dart:async';
import 'dart:math' as math;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bench_support.dart';

const int rowCount = 1000000;
const Size viewport = Size(1280, 800);

class Order {
  const Order(
    this.id,
    this.customer,
    this.region,
    this.status,
    this.amount,
    this.placed,
    this.note,
  );

  final int id;
  final String customer;
  final String region;
  final String status;
  final int amount;
  final DateTime placed;
  final String note;
}

const _regions = <String>['North', 'South', 'East', 'West', 'Central'];
const _statuses = <String>['Open', 'Shipped', 'Delivered', 'Returned'];
const _words = <String>[
  'priority',
  'fragile',
  'gift',
  'wrap',
  'call',
  'before',
  'delivery',
  'leave',
  'at',
  'door',
  'backorder',
  'partial',
  'refund',
  'review',
];

List<Order> makeOrders(int count) {
  final random = math.Random(42);
  final start = DateTime(2020);
  return List<Order>.generate(count, (i) {
    final words = random.nextInt(12);
    return Order(
      i,
      'Customer ${random.nextInt(200000)}',
      _regions[random.nextInt(_regions.length)],
      _statuses[random.nextInt(_statuses.length)],
      random.nextInt(500000),
      start.add(Duration(days: random.nextInt(2000))),
      <String>[
        for (var w = 0; w < words; w++) _words[random.nextInt(_words.length)],
      ].join(' '),
    );
  }, growable: false);
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

List<FitGridColumn<Order>> makeColumns() => <FitGridColumn<Order>>[
  FitGridColumn<Order>(
    id: 'id',
    label: 'Order',
    value: (o) => '#${o.id}',
    sortable: true,
    comparator: (a, b) => a.id.compareTo(b.id),
  ),
  FitGridColumn<Order>(
    id: 'customer',
    label: 'Customer',
    value: (o) => o.customer,
    sortable: true,
    filter: const FitGridFilterSpec.text(),
  ),
  FitGridColumn<Order>(
    id: 'region',
    label: 'Region',
    value: (o) => o.region,
    sortable: true,
    filter: const FitGridFilterSpec.values(options: _regions),
  ),
  FitGridColumn<Order>(
    id: 'status',
    label: 'Status',
    value: (o) => o.status,
    sortable: true,
    filter: const FitGridFilterSpec.values(options: _statuses),
  ),
  FitGridColumn<Order>(
    id: 'amount',
    label: 'Amount',
    value: (o) => (o.amount / 100).toStringAsFixed(2),
    alignment: FitGridAlignment.end,
    sortable: true,
    sortValue: (o) => o.amount,
    filter: FitGridFilterSpec<Order>.number((o) => o.amount / 100),
  ),
  FitGridColumn<Order>(
    id: 'placed',
    label: 'Placed',
    value: (o) => _date(o.placed),
    sortable: true,
    sortValue: (o) => o.placed,
  ),
  FitGridColumn<Order>(
    id: 'note',
    label: 'Note',
    value: (o) => o.note,
    width: const FitGridColumnWidth.fixed(260),
  ),
];

void main() {
  // Pays for the binding and the first JIT of the render pipeline, which
  // belong to the test framework rather than to the grid.
  testWidgets('warm up', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FitGrid<Order>(rows: makeOrders(200), columns: makeColumns()),
        ),
      ),
    );
    await tester.drag(find.byType(FitGrid<Order>), const Offset(0, -300));
    await tester.pump();
  });

  testWidgets('$rowCount-row workload', (tester) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final baseline = Samples('Baseline (harness, no data)')..rssAfter = rss;

    final generate = Samples('Generate $rowCount rows (app side)');
    final rows = await generate.time(() async => makeOrders(rowCount));
    generate.rssAfter = rss;

    final controller = FitGridController<Order>(
      rows: rows,
      columns: makeColumns(),
      selectionMode: FitGridSelectionMode.multiple,
    );
    addTearDown(controller.dispose);

    final mount = Samples('Mount + first frame');
    await mount.time(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FitGrid<Order>(controller: controller)),
        ),
      );
    });
    mount.rssAfter = rss;

    // ---- Scrolling ----------------------------------------------------------
    final grid = find.byType(FitGrid<Order>);
    final scrollFrame = Samples('Scroll one viewport (drag + frame)');
    for (var i = 0; i < 120; i++) {
      await scrollFrame.time(() async {
        await tester.drag(grid, const Offset(0, -700));
        await tester.pump();
      });
    }
    scrollFrame.rssAfter = rss;

    final jump = Samples('Jump to a random row (scrollTo + frame)');
    final random = math.Random(1);
    for (var i = 0; i < 40; i++) {
      final target = random.nextInt(rowCount);
      await jump.time(() async {
        controller.scrollTo(target);
        await tester.pump();
      });
    }
    jump.rssAfter = rss;
    expect(fitGridLaidOutRowCount(), lessThan(80));

    // ---- Sorting ------------------------------------------------------------
    // From 50,000 rows a sort runs on a background isolate, with the keys read
    // out of the rows in slices on the UI thread. Three numbers per sort:
    //  - stall: the longest the UI thread went without returning to the event
    //    loop while the sort was in progress — what decides dropped frames;
    //  - until sorted: from the request to the sorted order being in the view;
    //  - frame: the frame that then shows it.
    // The `id` column has only a closure comparator, which cannot cross an
    // isolate, so it is the UI-thread sort for comparison.
    Future<void> settleRun(
      Samples stall,
      Samples total,
      Samples frame,
      void Function() reset,
      void Function() apply,
    ) async {
      for (var run = 0; run < 3; run++) {
        reset();
        await tester.pump();
        await tester.runAsync(() async {
          final watch = Stopwatch()..start();
          var last = 0;
          var longest = 0;
          void tick() {
            final now = watch.elapsedMicroseconds;
            longest = math.max(longest, now - last);
            last = now;
          }

          apply();
          controller.data.view;
          tick();
          var done = false;
          unawaited(controller.data.whenSorted().then((_) => done = true));
          while (!done) {
            await Future<void>.delayed(Duration.zero);
            tick();
          }
          stall.add(longest);
          total.add(watch.elapsedMicroseconds);
        });
        await frame.time(() => tester.pump());
      }
      total.rssAfter = rss;
    }

    Future<void> sortRun(
      Samples stall,
      Samples total,
      Samples frame,
      List<FitGridSortKey> keys,
    ) => settleRun(
      stall,
      total,
      frame,
      controller.clearSort,
      () => controller.setSort(keys),
    );

    final sorts = <Samples>[];
    for (final (label, keys) in <(String, List<FitGridSortKey>)>[
      (
        'text (customer) asc',
        [const FitGridSortKey('customer', FitGridSortDirection.ascending)],
      ),
      (
        'text (customer) desc',
        [const FitGridSortKey('customer', FitGridSortDirection.descending)],
      ),
      (
        'number (amount) asc',
        [const FitGridSortKey('amount', FitGridSortDirection.ascending)],
      ),
      (
        'date (placed) desc',
        [const FitGridSortKey('placed', FitGridSortDirection.descending)],
      ),
      (
        'multi-key (region, status, amount)',
        [
          const FitGridSortKey('region', FitGridSortDirection.ascending),
          const FitGridSortKey('status', FitGridSortDirection.ascending),
          const FitGridSortKey('amount', FitGridSortDirection.descending),
        ],
      ),
      (
        'comparator only (id), UI thread',
        [const FitGridSortKey('id', FitGridSortDirection.descending)],
      ),
    ]) {
      final stall = Samples('Sort $label: longest UI stall');
      final total = Samples('Sort $label: until sorted');
      final frame = Samples('Sort $label: frame');
      await sortRun(stall, total, frame, keys);
      sorts.addAll(<Samples>[stall, total, frame]);
    }
    controller.clearSort();
    await tester.pump();

    // ---- Filtering ----------------------------------------------------------
    // From 50,000 rows a filter runs in slices across frames, so the same
    // three numbers as a sort: longest UI stall, until shown, and the frame.
    Future<void> filterRun(
      Samples stall,
      Samples total,
      Samples frame,
      void Function() apply,
    ) => settleRun(stall, total, frame, controller.filter.clear, apply);

    final filters = <Samples>[];
    var matched = <String, int>{};
    for (final (label, apply) in <(String, void Function())>[
      ('search "customer 12"', () => controller.filter.query = 'customer 12'),
      (
        'checklist status = Returned',
        () => controller.filter.setFilter(
          'status',
          const FitGridColumnFilter.oneOf(<String>{'Returned'}),
        ),
      ),
      (
        'number amount > 4000',
        () => controller.filter.setFilter(
          'amount',
          const FitGridColumnFilter(
            operator: FitGridFilterOperator.greaterThan,
            value: 4000,
          ),
        ),
      ),
      (
        'combined (region, amount, search)',
        () {
          controller.filter
            ..setFilter(
              'region',
              const FitGridColumnFilter.oneOf(<String>{'North', 'East'}),
            )
            ..setFilter(
              'amount',
              const FitGridColumnFilter(
                operator: FitGridFilterOperator.between,
                value: 1000,
                value2: 3000,
              ),
            )
            ..query = 'gift';
        },
      ),
    ]) {
      final stall = Samples('Filter $label: longest UI stall');
      final total = Samples('Filter $label: until shown');
      final frame = Samples('Filter $label: frame');
      await filterRun(stall, total, frame, apply);
      matched[label] = controller.data.length;
      filters.addAll(<Samples>[stall, total, frame]);
    }

    // Filter and sort together: the order is kept for every row and the
    // filter applied on top, so this is the sort's cost plus a filter pass.
    final filterSortData = Samples(
      'Filter (status) + sort (amount): until shown',
    );
    final filterSortFrame = Samples('Filter (status) + sort (amount): frame');
    for (var run = 0; run < 3; run++) {
      controller.filter.clear();
      controller.clearSort();
      await tester.pump();
      await tester.runAsync(() async {
        await filterSortData.time(() async {
          controller.filter.setFilter(
            'status',
            const FitGridColumnFilter.oneOf(<String>{'Open', 'Shipped'}),
          );
          controller.setSort(const <FitGridSortKey>[
            FitGridSortKey('amount', FitGridSortDirection.descending),
          ]);
          await controller.data.whenSorted();
          return controller.data.view;
        });
      });
      await filterSortFrame.time(() => tester.pump());
    }
    filterSortData.rssAfter = rss;
    filters.addAll(<Samples>[filterSortData, filterSortFrame]);

    // Search as you type, at a fast typist's pace. Two numbers: the longest
    // the UI thread stalled while a keystroke was being filtered — what
    // decides whether the typing itself drops frames — and, after the last
    // key, how long until the results are on screen.
    const typed = 'customer 1234';
    const keyGap = Duration(milliseconds: 80);
    Future<void> typingRun(Samples stall, Samples settle) async {
      for (var round = 0; round < 2; round++) {
        await tester.runAsync(() async {
          for (var i = 1; i <= typed.length; i++) {
            final watch = Stopwatch()..start();
            var last = 0;
            var longest = 0;
            void tick() {
              final now = watch.elapsedMicroseconds;
              longest = math.max(longest, now - last);
              last = now;
            }

            controller.filter.query = typed.substring(0, i);
            controller.data.view;
            tick();
            final lastKey = i == typed.length;
            var done = false;
            unawaited(controller.data.whenSorted().then((_) => done = true));
            while (lastKey ? !done : watch.elapsed < keyGap) {
              await Future<void>.delayed(Duration.zero);
              tick();
            }
            stall.add(longest);
            if (lastKey) settle.add(watch.elapsedMicroseconds);
          }
        });
        await tester.pump();
        expect(controller.data.isFiltering, isFalse);
        controller.filter.query = '';
        await tester.pump();
      }
      settle.rssAfter = rss;
    }

    controller.filter.clear();
    controller.clearSort();
    await tester.pump();
    final keystroke = Samples('Search-as-you-type: longest UI stall per key');
    final typedSettle = Samples('Search-as-you-type: last key until shown');
    await typingRun(keystroke, typedSettle);
    filters.addAll(<Samples>[keystroke, typedSettle]);

    // The same typing over a sorted grid: the order is kept for all rows and
    // the filter applied on top, so a keystroke never sorts again.
    // Inside runAsync: the sort starts wherever the view is first read, and a
    // background sort started in the test's fake-async zone waits on timers
    // that only fire when the test pumps.
    await tester.runAsync(() {
      controller.setSort(const <FitGridSortKey>[
        FitGridSortKey('amount', FitGridSortDirection.descending),
      ]);
      return controller.data.whenSorted();
    });
    await tester.pump();
    final sortedKeystroke = Samples(
      'Search-as-you-type on a sorted grid: longest UI stall per key',
    );
    final sortedSettle = Samples(
      'Search-as-you-type on a sorted grid: last key until shown',
    );
    await typingRun(sortedKeystroke, sortedSettle);
    expect(controller.data.isSorting, isFalse);
    controller.filter.query = '';
    controller.clearSort();
    await tester.pump();
    filters.addAll(<Samples>[sortedKeystroke, sortedSettle]);

    // ---- Export -------------------------------------------------------------
    final exports = <Samples>[];
    final sizes = <String, int>{};
    Future<void> exportRun(String scope) async {
      final build = Samples('Export $scope: collect cells');
      final csv = Samples('Export $scope: CSV');
      final xlsx = Samples('Export $scope: xlsx');
      for (var run = 0; run < 2; run++) {
        final data = await build.time(() async => controller.export());
        final text = await csv.time(() async => fitGridToCsv(data));
        final bytes = await xlsx.time(() async => fitGridToXlsx(data));
        sizes['$scope CSV'] = text.length;
        sizes['$scope xlsx'] = bytes.length;
      }
      build.rssAfter = rss;
      csv.rssAfter = rss;
      xlsx.rssAfter = rss;
      exports.addAll(<Samples>[build, csv, xlsx]);
    }

    await exportRun('all $rowCount rows');
    // A large filter lands in the background; an export waits for it.
    await tester.runAsync(() {
      controller.filter.setFilter(
        'status',
        const FitGridColumnFilter.oneOf(<String>{'Returned'}),
      );
      return controller.data.whenSorted();
    });
    await tester.pump();
    final filteredCount = controller.data.length;
    await exportRun('filtered ($filteredCount rows)');

    controller.filter.clear();
    await tester.pump();
    controller.selection.selectRange(0, 9999);
    final selected = Samples('Export 10,000 selected rows: collect + CSV');
    for (var run = 0; run < 3; run++) {
      await selected.time(
        () async => fitGridToCsv(controller.export(selectedOnly: true)),
      );
    }
    selected.rssAfter = rss;
    exports.add(selected);

    // ---- Report -------------------------------------------------------------
    final out = StringBuffer()
      ..writeln()
      ..writeln('## fitgrid workload: $rowCount rows × 7 columns')
      ..write(deviceReport())
      ..write(table('Setup', <Samples>[baseline, generate, mount]))
      ..write(table('Scrolling', <Samples>[scrollFrame, jump]))
      ..write(table('Sorting (3 runs each)', sorts))
      ..write(table('Filtering (3 runs each)', filters))
      ..writeln()
      ..writeln(
        'Rows matched: ${matched.entries.map((e) => '${e.key} → ${e.value}').join('; ')}',
      )
      ..write(table('Export', exports))
      ..writeln()
      ..writeln(
        'Export sizes: ${sizes.entries.map((e) => '${e.key} ${mb(e.value)} MB').join('; ')}',
      )
      ..writeln()
      ..writeln('### Memory')
      ..writeln()
      ..writeln('| | MB |')
      ..writeln('|---|--:|')
      ..writeln('| Baseline RSS (harness) | ${mb(baseline.rssAfter!)} |')
      ..writeln('| After generating rows | ${mb(generate.rssAfter!)} |')
      ..writeln('| After mounting the grid | ${mb(mount.rssAfter!)} |')
      ..writeln(
        '| Grid over the data (mount − generate) | ${mb(mount.rssAfter! - generate.rssAfter!)} |',
      )
      ..writeln(
        '| Peak RSS (whole run, includes export buffers) | ${mb(peakRss)} |',
      )
      ..writeln()
      ..writeln(caveat);
    // ignore: avoid_print
    print(out);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
