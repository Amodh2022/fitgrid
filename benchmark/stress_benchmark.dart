// Live-update stress benchmark. Run with:
//
//     flutter test benchmark/stress_benchmark.dart
//
// The case a trading blotter or an ops dashboard puts a grid in: 100,000 rows
// by 30 columns of mixed text lengths, two columns frozen at the start, a
// filter active, and rows being replaced underneath while the user scrolls,
// moves with the keyboard, selects and sorts.
//
// It reports three things:
//
//  - how long an update takes to reach the screen, at 1, 100 and 1,000
//    changed rows per tick;
//  - how long an interaction takes when an update lands in the same frame,
//    against the same interaction with no updates flowing;
//  - whether the selection is still on the same record after sorting and
//    updating — a correctness check, printed as PASS or FAIL. The assertions
//    live in `test/record_identity_test.dart`; this shows it at scale.
//
// Rows are immutable and replaced with new objects, the way a server push or
// an immutable state store delivers them, with `FitGrid.rowKey` set to the
// record id. Like the other benchmarks it is not a CI gate.

import 'dart:async';
import 'dart:math' as math;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bench_support.dart';

const int rowCount = 100000;
const int columnCount = 30;
const Size viewport = Size(1440, 900);

/// One record: an id and 29 cells, deliberately of very different lengths.
class Record {
  const Record(this.id, this.status, this.price, this.cells);

  final int id;
  final String status;
  final int price;
  final List<String> cells;

  Record tick(math.Random random) => Record(
    id,
    random.nextInt(10) == 0
        ? _statuses[random.nextInt(_statuses.length)]
        : status,
    math.max(1, price + random.nextInt(2001) - 1000),
    cells,
  );
}

const _statuses = <String>['Active', 'Pending', 'Halted', 'Closed'];
const _lorem =
    'lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod '
    'tempor incididunt ut labore et dolore magna aliqua ut enim ad minim '
    'veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
    'commodo consequat duis aute irure dolor in reprehenderit in voluptate';

/// Column kinds, cycled across the 27 free columns: short codes, names,
/// sentences, long paragraphs, numbers and dates.
enum Kind { code, name, sentence, paragraph, number, date }

String _cell(Kind kind, math.Random random) {
  switch (kind) {
    case Kind.code:
      return String.fromCharCodes(
        List<int>.generate(
          2 + random.nextInt(5),
          (_) => 65 + random.nextInt(26),
        ),
      );
    case Kind.name:
      return 'Name ${random.nextInt(1000000)}';
    case Kind.sentence:
      final start = random.nextInt(100);
      return _lorem.substring(start, start + 15 + random.nextInt(50));
    case Kind.paragraph:
      final length = 60 + random.nextInt(240);
      final buffer = StringBuffer();
      while (buffer.length < length) {
        buffer.write(_lorem);
      }
      return buffer.toString().substring(0, length);
    case Kind.number:
      return (random.nextDouble() * 1e6).toStringAsFixed(random.nextInt(4));
    case Kind.date:
      return '20${10 + random.nextInt(16)}-0${1 + random.nextInt(9)}-1${random.nextInt(10)}';
  }
}

Kind _kindOf(int column) => Kind.values[column % Kind.values.length];

List<Record> makeRecords(int count) {
  final random = math.Random(3);
  return List<Record>.generate(count, (i) {
    return Record(
      i,
      _statuses[random.nextInt(_statuses.length)],
      random.nextInt(1000000),
      List<String>.generate(
        columnCount - 3,
        (c) => _cell(_kindOf(c), random),
        growable: false,
      ),
    );
  }, growable: false);
}

List<FitGridColumn<Record>> makeColumns() => <FitGridColumn<Record>>[
  // The two frozen columns.
  FitGridColumn<Record>(
    id: 'id',
    label: 'ID',
    value: (r) => r.id.toString(),
    freeze: FitGridFreeze.start,
    sortable: true,
    comparator: (a, b) => a.id.compareTo(b.id),
  ),
  FitGridColumn<Record>(
    id: 'status',
    label: 'Status',
    value: (r) => r.status,
    freeze: FitGridFreeze.start,
    sortable: true,
    filter: const FitGridFilterSpec.values(options: _statuses),
  ),
  FitGridColumn<Record>(
    id: 'price',
    label: 'Price',
    value: (r) => r.price.toString(),
    alignment: FitGridAlignment.end,
    sortable: true,
    sortValue: (r) => r.price,
    editor: FitGridEditor<Record>(onCommit: (row, index, value) {}),
  ),
  for (var c = 0; c < columnCount - 3; c++)
    FitGridColumn<Record>(
      id: 'c$c',
      label: '${_kindOf(c).name} $c',
      value: (r) => r.cells[c],
      sortable: true,
      // Paragraph columns are capped, as a real app would; everything else
      // sizes to its content.
      width: _kindOf(c) == Kind.paragraph
          ? const FitGridColumnWidth.auto(max: 320)
          : const FitGridColumnWidth.auto(),
    ),
];

/// Replaces [changes] random records with ticked copies, returning a new list —
/// what an app holding immutable rows hands the grid on every push.
List<Record> applyTick(List<Record> rows, int changes, math.Random random) {
  final next = List<Record>.of(rows, growable: false);
  for (var i = 0; i < changes; i++) {
    final at = random.nextInt(next.length);
    next[at] = next[at].tick(random);
  }
  return next;
}

void main() {
  testWidgets('warm up', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FitGrid<Record>(rows: makeRecords(300), columns: makeColumns()),
        ),
      ),
    );
    await tester.drag(find.byType(FitGrid<Record>), const Offset(0, -300));
    await tester.drag(find.byType(FitGrid<Record>), const Offset(-300, 0));
    await tester.pump();
    // Drags start on cells, which arms the double-tap recognizer's timer.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('$rowCount × $columnCount live-update stress', (tester) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final baseline = Samples('Baseline (harness, no data)')..rssAfter = rss;
    final generate = Samples(
      'Generate $rowCount × $columnCount rows (app side)',
    );
    var rows = await generate.time(() async => makeRecords(rowCount));
    generate.rssAfter = rss;

    final controller = FitGridController<Record>(
      rows: rows,
      columns: makeColumns(),
      selectionMode: FitGridSelectionMode.multiple,
    );
    addTearDown(controller.dispose);

    final mount = Samples('Mount + first frame');
    await mount.time(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FitGrid<Record>(
              controller: controller,
              rowKey: (r) => r.id,
              autofocus: true,
            ),
          ),
        ),
      );
    });
    // Let progressive column measurement finish, so its frames are not
    // counted against the first update.
    final settle = Samples('Column measurement settles');
    await settle.time(() async {
      for (var i = 0; i < 200 && tester.binding.hasScheduledFrame; i++) {
        await tester.pump();
      }
    });
    mount.rssAfter = rss;
    settle.rssAfter = rss;

    // The filter stays on for the rest of the run: half the statuses.
    final filterOn = Samples(
      'Apply filter (status in Active, Pending) + frame',
    );
    await filterOn.time(() async {
      controller.filter.setFilter(
        'status',
        const FitGridColumnFilter.oneOf(<String>{'Active', 'Pending'}),
      );
      await tester.pump();
    });
    filterOn.rssAfter = rss;
    final filtered = controller.data.length;

    final grid = find.byType(FitGrid<Record>);
    final random = math.Random(9);

    // ---- Frozen columns hold still under horizontal scroll -----------------
    final idLeft = fitGridColumnLeft('id');
    final statusLeft = fitGridColumnLeft('status');
    final hscroll = Samples('Horizontal scroll 400px (idle)');
    for (var i = 0; i < 10; i++) {
      await hscroll.time(() async {
        await tester.drag(grid, Offset(i.isEven ? -400 : 400, 0));
        await tester.pump();
      });
      expect(fitGridColumnLeft('id'), idLeft);
      expect(fitGridColumnLeft('status'), statusLeft);
    }
    await tester.drag(grid, const Offset(-1200, 0));
    await tester.pump();
    expect(fitGridColumnLeft('id'), idLeft, reason: 'frozen column moved');
    expect(
      fitGridColumnLeft('status'),
      statusLeft,
      reason: 'frozen column moved',
    );
    hscroll.rssAfter = rss;

    // ---- Interactions with no updates flowing, as the baseline -------------
    Future<void> scroll() async {
      await tester.drag(grid, Offset(0, random.nextBool() ? -500 : 500));
      await tester.pump();
    }

    Future<void> arrow() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }

    Future<void> toggleSelect() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
    }

    controller.focus.moveTo(0, 'price');
    await tester.pump();

    final idle = <String, Samples>{
      'scroll': Samples('Scroll 500px, idle'),
      'arrow': Samples('Arrow key, idle'),
      'select': Samples('Space to select, idle'),
    };
    for (var i = 0; i < 30; i++) {
      await idle['scroll']!.time(scroll);
      await idle['arrow']!.time(arrow);
      await idle['select']!.time(toggleSelect);
    }
    for (final s in idle.values) {
      s.rssAfter = rss;
    }

    // ---- Updates, then updates with an interaction in the same frame -------
    final updates = <Samples>[];
    final during = <Samples>[];
    final host = <Samples>[];
    for (final changes in <int>[1, 100, 1000]) {
      final build = Samples('Host builds next list ($changes changed)');
      final update = Samples('Update → frame ($changes rows/tick)');
      final withScroll = Samples(
        'Scroll + update in same frame ($changes/tick)',
      );
      final withArrow = Samples('Arrow key + update ($changes/tick)');
      final withSelect = Samples('Space to select + update ($changes/tick)');

      for (var tick = 0; tick < 30; tick++) {
        rows = await build.time(() async => applyTick(rows, changes, random));
        await update.time(() async {
          controller.data.rows = rows;
          await tester.pump();
        });

        for (final (samples, interaction)
            in <(Samples, Future<void> Function())>[
              (withScroll, scroll),
              (withArrow, arrow),
              (withSelect, toggleSelect),
            ]) {
          rows = applyTick(rows, changes, random);
          await samples.time(() async {
            controller.data.rows = rows;
            await interaction();
          });
        }
      }
      for (final s in <Samples>[
        build,
        update,
        withScroll,
        withArrow,
        withSelect,
      ]) {
        s.rssAfter = rss;
      }
      host.add(build);
      updates.add(update);
      during.addAll(<Samples>[withScroll, withArrow, withSelect]);
    }

    // ---- Sorting while updates flow, and whether selection holds ----------
    controller.selection.clear();
    await tester.pump();
    final watched = <int>[
      for (var i = 0; i < 5; i++) random.nextInt(controller.data.length),
    ];
    controller.selection.select(watched);
    await tester.pump();
    final watchedIds = <int>{
      for (final i in controller.selection.selected) controller.data.view[i].id,
    };

    // From 50,000 rows a sort runs on a background isolate, reading its keys
    // out of the rows in slices on the UI thread. Measured on real time, with
    // the longest the UI thread went without returning to the event loop as
    // the number that decides dropped frames.
    final sortStall = Samples('Sort: longest UI stall');
    final sortTotal = Samples('Sort: until sorted');
    final sortFrame = Samples('Sort: frame that shows it');
    final feedStall = Samples(
      'Sort with 100 rows/tick every 50 ms: longest UI stall',
    );
    const sortColumns = <String>['price', 'c1', 'c2', 'c4', 'status'];
    for (var i = 0; i < 10; i++) {
      final withFeed = i.isOdd;
      await tester.runAsync(() async {
        final watch = Stopwatch()..start();
        var last = 0;
        var longest = 0;
        void tick() {
          final now = watch.elapsedMicroseconds;
          longest = math.max(longest, now - last);
          last = now;
        }

        controller.toggleSort(sortColumns[i % sortColumns.length]);
        controller.data.view;
        tick();
        if (withFeed) {
          // A feed keeps landing while the sort runs; each tick re-derives the
          // view from the last order and queues another sort.
          var nextTick = 0;
          while (watch.elapsedMilliseconds < 400) {
            if (watch.elapsedMilliseconds >= nextTick) {
              rows = applyTick(rows, 100, random);
              controller.data.rows = rows;
              controller.data.view;
              nextTick += 50;
            }
            await Future<void>.delayed(Duration.zero);
            tick();
          }
          feedStall.add(longest);
          await controller.data.whenSorted();
        } else {
          var done = false;
          unawaited(controller.data.whenSorted().then((_) => done = true));
          while (!done) {
            await Future<void>.delayed(Duration.zero);
            tick();
          }
          sortStall.add(longest);
          sortTotal.add(watch.elapsedMicroseconds);
        }
      });
      await sortFrame.time(() => tester.pump());
    }
    sortTotal.rssAfter = rss;
    feedStall.rssAfter = rss;

    final heldIds = <int>{
      for (final i in controller.selection.selected)
        if (i < controller.data.length) controller.data.view[i].id,
    };
    final selectionHeld =
        heldIds.containsAll(watchedIds) && heldIds.length == watchedIds.length;

    // Same check for an open editor.
    final editTarget = controller.data.view[3].id;
    controller.editing.begin(3, 'price');
    await tester.pump();
    await tester.runAsync(() async {
      controller.toggleSort('price');
      rows = applyTick(rows, 100, random);
      controller.data.rows = rows;
      await controller.data.whenSorted();
    });
    await tester.pump();
    final editingRow = controller.editing.rowIndex;
    final editHeldId = editingRow == null
        ? null
        : controller.data.view[editingRow].id;
    controller.editing.cancel();
    await tester.pump();

    expect(fitGridLaidOutRowCount(), lessThan(80));
    expect(fitGridColumnLeft('id'), idLeft);

    // ---- Report -------------------------------------------------------------
    final out = StringBuffer()
      ..writeln()
      ..writeln(
        '## fitgrid stress: $rowCount rows × $columnCount columns, '
        '2 frozen, filter active ($filtered of $rowCount visible), live updates',
      )
      ..write(deviceReport())
      ..write(
        table('Setup', <Samples>[baseline, generate, mount, settle, filterOn]),
      )
      ..write(
        table('Interaction, no updates (baseline)', <Samples>[
          hscroll,
          ...idle.values,
        ]),
      )
      ..write(
        table('Update to screen (filter re-applied, rowKey set)', updates),
      )
      ..write(
        table('Interaction latency with an update in the same frame', during),
      )
      ..write(
        table('Sorting (background isolate from 50,000 rows)', <Samples>[
          sortStall,
          sortTotal,
          sortFrame,
          feedStall,
        ]),
      )
      ..write(
        table('App side, not the grid: building the next immutable list', host),
      )
      ..writeln()
      ..writeln('### Record identity after sort + updates')
      ..writeln()
      ..writeln('| Check | Result |')
      ..writeln('|---|---|')
      ..writeln('| Frozen columns stay put under horizontal scroll | PASS |')
      ..writeln(
        '| Selection stays on the same 5 records | '
        '${selectionHeld ? 'PASS' : 'FAIL — selected ${watchedIds.toList()..sort()}, now on ${heldIds.toList()..sort()}'} |',
      )
      ..writeln(
        '| Open editor stays on the same record | '
        '${editHeldId == editTarget ? 'PASS' : 'FAIL — opened on #$editTarget, now on #$editHeldId'} |',
      )
      ..writeln()
      ..writeln('### Memory')
      ..writeln()
      ..writeln('| | MB |')
      ..writeln('|---|--:|')
      ..writeln('| Baseline RSS (harness) | ${mb(baseline.rssAfter!)} |')
      ..writeln('| After generating rows | ${mb(generate.rssAfter!)} |')
      ..writeln('| After mounting and measuring | ${mb(settle.rssAfter!)} |')
      ..writeln('| Peak RSS (whole run) | ${mb(peakRss)} |')
      ..writeln()
      ..writeln(caveat);
    // ignore: avoid_print
    print(out);
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
