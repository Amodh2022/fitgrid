// Head-to-head sort benchmark. One grid and one size per process, so peak
// memory is that grid's alone:
//
//     flutter test test/compare_benchmark.dart \
//       --dart-define=GRID=syncfusion --dart-define=ROWS=100000
//
// GRID is fitgrid, syncfusion, trina or pluto. `tool/run.sh` runs every
// combination and `tool/combine.dart` turns the output into one table.
//
// Every grid gets the same rows, viewport, sorts and measurements. For each
// sort there are three numbers:
//  - longest UI stall: the longest the UI thread went without returning to the
//    event loop while the sort was in progress. A sort on the UI thread shows
//    its whole duration here; this is what decides dropped frames.
//  - until sorted: from the request to the grid's model being in the new
//    order.
//  - frame: the frame that then shows it.
//
// Lines starting RESULT, ORDER and META are for the combiner.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitgrid_compare_bench/adapters.dart';
import 'package:fitgrid_compare_bench/bench_support.dart';
import 'package:fitgrid_compare_bench/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const grid = String.fromEnvironment('GRID', defaultValue: 'fitgrid');
const rowCount = int.fromEnvironment('ROWS', defaultValue: 100000);
const viewport = Size(1280, 800);

String _version(String package) {
  if (package == 'fitgrid_table') {
    final pubspec = File('../../pubspec.yaml').readAsStringSync();
    return RegExp(
          r'^version:\s*(\S+)',
          multiLine: true,
        ).firstMatch(pubspec)?.group(1) ??
        '?';
  }
  final lock = File('pubspec.lock').readAsStringSync();
  final match = RegExp(
    '  $package:\\n(?:    .*\\n)*?    version: "([^"]+)"',
  ).firstMatch(lock);
  return match?.group(1) ?? '?';
}

GridAdapter _adapter() => switch (grid) {
  'fitgrid' => FitGridAdapter(_version('fitgrid_table')),
  'syncfusion' => SyncfusionAdapter(_version('syncfusion_flutter_datagrid')),
  'trina' => TrinaAdapter(_version('trina_grid')),
  'pluto' => PlutoAdapter(_version('pluto_grid')),
  _ => throw ArgumentError('Unknown GRID "$grid"'),
};

Widget _host(Widget child) =>
    MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child));

void _emit(String kind, List<Object?> fields) =>
    // ignore: avoid_print
    print('$kind\t${fields.join('\t')}');

void _result(String metric, Samples samples) => _emit('RESULT', <Object?>[
  grid,
  rowCount,
  metric,
  samples.median,
  samples.p90,
  samples.max,
]);

void main() {
  testWidgets('$grid × $rowCount', (tester) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Warm-up on a small copy of the same grid, so the first JIT of its code
    // is not counted against it.
    {
      final warm = _adapter()..prepare(makeOrders(300));
      await tester.pumpWidget(_host(warm.build()));
      await tester.pump();
      await tester.drag(find.byType(Scaffold), const Offset(0, -300));
      await tester.pump();
      await tester.runAsync(() => warm.sort('customer', true));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      warm.dispose();
    }

    final adapter = _adapter();
    _emit('META', <Object?>[grid, rowCount, adapter.name]);
    for (final line in deviceReport().split('\n')) {
      if (line.startsWith('| ') && !line.startsWith('| |')) {
        _emit('DEVICE', <Object?>[line]);
      }
    }
    final baseline = rss;
    final orders = makeOrders(rowCount);
    final afterData = rss;

    final model = Samples('model');
    await model.time(() async => adapter.prepare(orders));
    final afterModel = rss;

    final mount = Samples('mount');
    await mount.time(() async {
      await tester.pumpWidget(_host(adapter.build()));
      await tester.pump();
    });
    // Anything the grid finishes on the frames after its first.
    for (var i = 0; i < 20 && tester.binding.hasScheduledFrame; i++) {
      await tester.pump();
    }
    final afterMount = rss;

    final scroll = Samples('scroll');
    final body = find.byType(Scaffold);
    for (var i = 0; i < 60; i++) {
      await scroll.time(() async {
        await tester.drag(body, const Offset(0, -600));
        await tester.pump();
      });
    }
    // Back to the top, so every sort starts from the same place.
    for (var i = 0; i < 70; i++) {
      await tester.drag(body, const Offset(0, 600));
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    _result('Build the grid\'s row model (app side)', model);
    _result('Mount + first frame', mount);
    _result('Scroll one viewport (drag + frame)', scroll);

    for (final (label, field, ascending) in sorts) {
      final stall = Samples('stall');
      final total = Samples('total');
      final frame = Samples('frame');
      for (var run = 0; run < 3; run++) {
        // Alternate the direction first, so every run really reorders.
        await tester.runAsync(() => adapter.sort(field, !ascending));
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

          var done = false;
          unawaited(adapter.sort(field, ascending).then((_) => done = true));
          tick();
          while (!done) {
            await Future<void>.delayed(Duration.zero);
            tick();
          }
          stall.add(longest);
          total.add(watch.elapsedMicroseconds);
        });
        await frame.time(() => tester.pump());
      }
      _result('Sort $label: longest UI stall', stall);
      _result('Sort $label: until sorted', total);
      _result('Sort $label: frame', frame);
      // The sort keys of the first rows, not their ids: rows that tie may
      // come out in either order, and only fitgrid promises a stable sort.
      String keyOf(Order o) => switch (field) {
        'customer' => o.customer,
        'amount' => '${o.amount}',
        _ => formatDate(o.placed),
      };
      _emit('ORDER', <Object?>[
        grid,
        rowCount,
        label,
        <String>[
          for (var i = 0; i < 20; i++) keyOf(orders[adapter.idAt(i)]),
        ].join(','),
      ]);
    }

    _emit('MEM', <Object?>[
      grid,
      rowCount,
      mb(baseline),
      mb(afterData),
      mb(afterModel),
      mb(afterMount),
      mb(peakRss),
    ]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    adapter.dispose();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
