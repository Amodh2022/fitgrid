// Sizing benchmarks. Run with:
//
//     flutter test benchmark/measurement_benchmark.dart
//
// No widget tree and no device, but `flutter test` rather than `dart run`:
// measuring text needs the engine's font machinery, which the bare Dart VM does
// not have. This times the two passes that are bounded by the number of rows
// rather than by the viewport — the only places this package can accidentally
// become O(rows) per frame.

import 'dart:math' as math;

import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/src/sizing/column_sizer.dart';
import 'package:fitgrid/src/sizing/row_sizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Row {
  Row(this.name, this.role, this.salary, this.note);

  final String name;
  final String role;
  final int salary;
  final String note;
}

List<Row> makeRows(int count) {
  final random = math.Random(7);
  const roles = <String>['Engineer', 'Designer', 'Analyst', 'Manager'];
  return <Row>[
    for (var i = 0; i < count; i++)
      Row(
        'Person ${random.nextInt(1000000)}',
        roles[i % roles.length],
        40000 + random.nextInt(90000),
        'A note of about ${random.nextInt(200)} characters, give or take, '
            'so that a wrapping column has something to wrap.',
      ),
  ];
}

List<FitGridColumn<Row>> makeColumns({bool wrapping = false}) =>
    <FitGridColumn<Row>>[
      FitGridColumn<Row>(id: 'name', label: 'Name', value: (r) => r.name),
      FitGridColumn<Row>(id: 'role', label: 'Role', value: (r) => r.role),
      FitGridColumn<Row>(
        id: 'salary',
        label: 'Salary',
        value: (r) => r.salary.toString(),
        alignment: FitGridAlignment.end,
      ),
      if (wrapping)
        FitGridColumn<Row>(
          id: 'note',
          label: 'Note',
          value: (r) => r.note,
          width: const FitGridColumnWidth.fixed(280),
          maxLines: 3,
        ),
    ];

Duration time(String label, int runs, void Function() body) {
  // One warm-up pass, so the first run's JIT does not become the measurement.
  body();
  final watch = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    body();
  }
  watch.stop();
  final each = Duration(microseconds: watch.elapsedMicroseconds ~/ runs);
  print('${label.padRight(46)} ${_ms(each).padLeft(10)}');
  return each;
}

String _ms(Duration d) => '${(d.inMicroseconds / 1000).toStringAsFixed(2)} ms';

void main() {
  testWidgets('sizing benchmarks', (tester) async {
    _run();
  }, timeout: const Timeout(Duration(minutes: 10)));
}

void _run() {
  final theme = FitGridThemeData.fromTheme(ThemeData.light(useMaterial3: true));

  print('\nColumn measurement — sampled `auto` (the default)');
  print('-' * 60);
  for (final count in <int>[1000, 10000, 100000, 1000000]) {
    final rows = makeRows(count);
    final columns = makeColumns();
    final sizer = FitGridColumnSizer();
    time('${_n(count)} rows', count > 100000 ? 3 : 20, () {
      sizer.resolve(
        columns: columns,
        rows: rows,
        theme: theme,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
    });
    sizer.dispose();
  }

  print(
    '\nColumn measurement — measureAllRows, one budgeted pass '
    '(${FitGridColumnSizer().measurementBudget} rows)',
  );
  print('-' * 60);
  for (final count in <int>[1000, 10000, 100000]) {
    final rows = makeRows(count);
    final columns = <FitGridColumn<Row>>[
      FitGridColumn<Row>(
        id: 'name',
        label: 'Name',
        value: (r) => r.name,
        width: const FitGridColumnWidth.auto(measureAllRows: true),
      ),
    ];
    // A fresh sizer per run: progress is remembered between passes, so reusing
    // one would time an empty pass on every run after the first and report the
    // budget as free.
    time('${_n(count)} rows, one pass', 5, () {
      final sizer = FitGridColumnSizer()
        ..resolve(
          columns: columns,
          rows: rows,
          theme: theme,
          availableWidth: 1200,
          textDirection: TextDirection.ltr,
        );
      sizer.dispose();
    });
  }

  print('\nRow measurement — no wrapping column (should be free)');
  print('-' * 60);
  for (final count in <int>[10000, 1000000]) {
    final rows = makeRows(count);
    final columns = makeColumns();
    final layout = FitGridColumnSizer().resolve(
      columns: columns,
      rows: rows,
      theme: theme,
      availableWidth: 1200,
      textDirection: TextDirection.ltr,
    );
    final sizer = FitGridRowSizer();
    time('${_n(count)} rows', 20, () {
      sizer.resolve(
        policy: const FitGridRowHeight.contentSized(),
        columns: columns,
        rows: FitGridRowsView<Row>.of(rows),
        layout: layout,
        theme: theme,
        textDirection: TextDirection.ltr,
      );
    });
    sizer.dispose();
  }

  print('\nRow measurement — one wrapping column (the real cost)');
  print('-' * 60);
  for (final count in <int>[1000, 10000, 50000]) {
    final rows = makeRows(count);
    final columns = makeColumns(wrapping: true);
    final layout = FitGridColumnSizer().resolve(
      columns: columns,
      rows: rows,
      theme: theme,
      availableWidth: 1200,
      textDirection: TextDirection.ltr,
    );
    final sizer = FitGridRowSizer();
    time('${_n(count)} rows', 3, () {
      sizer.resolve(
        policy: const FitGridRowHeight.contentSized(),
        columns: columns,
        rows: FitGridRowsView<Row>.of(rows),
        layout: layout,
        theme: theme,
        textDirection: TextDirection.ltr,
      );
    });
    sizer.dispose();
  }

  print('');
}

String _n(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
