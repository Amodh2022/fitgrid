// Frame benchmarks. Run with:
//
//     flutter test benchmark/frame_benchmark.dart
//
// This is the measurement the package's claim rests on: build, layout and paint
// cost should track the viewport and not the dataset. A grid of a thousand rows
// and a grid of a million, in the same window, should report the same number of
// laid-out cells and roughly the same frame time.
//
// It is not a CI gate. A timing assertion on a shared runner fails for reasons
// that have nothing to do with the code, and a benchmark that cries wolf gets
// ignored. It prints; read it.

import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Row {
  const Row(this.name, this.role, this.salary);

  final String name;
  final String role;
  final int salary;
}

List<Row> makeRows(int count) => <Row>[
  for (var i = 0; i < count; i++)
    Row('Person $i', i.isEven ? 'Engineer' : 'Designer', 40000 + i),
];

List<FitGridColumn<Row>> makeColumns() => <FitGridColumn<Row>>[
  FitGridColumn<Row>(id: 'name', label: 'Name', value: (r) => r.name),
  FitGridColumn<Row>(id: 'role', label: 'Role', value: (r) => r.role),
  FitGridColumn<Row>(
    id: 'salary',
    label: 'Salary',
    value: (r) => r.salary.toString(),
    alignment: FitGridAlignment.end,
  ),
];

String _ms(int microseconds) =>
    '${(microseconds / 1000).toStringAsFixed(3)} ms';

void main() {
  const viewport = Size(1000, 700);

  for (final count in <int>[1000, 10000, 100000, 1000000]) {
    testWidgets('$count rows', (tester) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rows = makeRows(count);

      final firstFrame = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FitGrid<Row>(rows: rows, columns: makeColumns()),
          ),
        ),
      );
      firstFrame.stop();

      // Scroll a viewport at a time and time each resulting frame. This is the
      // number that matters: a first frame is paid once, a scroll frame is paid
      // sixty times a second.
      final frames = <int>[];
      for (var i = 0; i < 30; i++) {
        final watch = Stopwatch()..start();
        await tester.drag(find.byType(FitGrid<Row>), const Offset(0, -600));
        await tester.pump();
        watch.stop();
        frames.add(watch.elapsedMicroseconds);
      }
      frames.sort();

      final section = fitGridSection();
      // ignore: avoid_print
      print(
        '${count.toString().padLeft(9)} rows  '
        'first ${_ms(firstFrame.elapsedMicroseconds).padLeft(10)}  '
        'median ${_ms(frames[frames.length ~/ 2]).padLeft(10)}  '
        'p90 ${_ms(frames[(frames.length * 9) ~/ 10]).padLeft(10)}  '
        'cells ${section.paintedCellCount.toString().padLeft(4)}  '
        'rows laid out ${fitGridLaidOutRowCount().toString().padLeft(3)}',
      );

      // The one thing worth failing on, because it is a correctness claim
      // rather than a timing one: the work must be bounded by the window.
      expect(fitGridLaidOutRowCount(), lessThan(60));
    });
  }
}
