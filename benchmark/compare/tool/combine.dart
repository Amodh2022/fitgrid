// Turns the output of tool/run.sh into one markdown report: a table per size
// with a column per grid.
//
//   dart run tool/combine.dart build/compare > report.md

import 'dart:io';

const _order = <String>['fitgrid', 'syncfusion', 'trina', 'pluto'];

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'build/compare' : args.first);
  final names = <String, String>{};
  // rows -> metric -> grid -> (median, p90, max) in microseconds
  final results = <int, Map<String, Map<String, List<int>>>>{};
  final metrics = <String>[];
  // rows -> sort -> grid -> first keys
  final orders = <int, Map<String, Map<String, String>>>{};
  final memory = <int, Map<String, List<String>>>{};
  final dnf = <int, Set<String>>{};
  final device = <String>[];

  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.txt')) continue;
    for (final line in file.readAsLinesSync()) {
      final f = line.split('\t');
      switch (f.first) {
        case 'META':
          names[f[1]] = f[3];
        case 'DEVICE':
          if (!device.contains(f[1])) device.add(f[1]);
        case 'RESULT':
          final rows = int.parse(f[2]);
          if (!metrics.contains(f[3])) metrics.add(f[3]);
          results
              .putIfAbsent(rows, () => {})
              .putIfAbsent(f[3], () => {})[f[1]] = [
            int.parse(f[4]),
            int.parse(f[5]),
            int.parse(f[6]),
          ];
        case 'ORDER':
          orders
                  .putIfAbsent(int.parse(f[2]), () => {})
                  .putIfAbsent(f[3], () => {})[f[1]] =
              f[4];
        case 'MEM':
          memory.putIfAbsent(int.parse(f[2]), () => {})[f[1]] = f.sublist(3);
        case 'DNF':
          dnf.putIfAbsent(int.parse(f[2]), () => {}).add(f[1]);
      }
    }
  }

  String ms(int micros) => (micros / 1000).toStringAsFixed(1);
  final out = StringBuffer()
    ..writeln('# Sort benchmark: fitgrid vs Syncfusion vs PlutoGrid/TrinaGrid')
    ..writeln()
    ..writeln(
      'Same rows (the Order dataset from `benchmark/workload_benchmark.dart`, '
      '7 columns), same 1280×800 viewport, same harness for every grid. Each '
      'grid is set up the way its documentation shows, with typed values and '
      'its own column types. Each grid runs in its own process.',
    )
    ..writeln()
    ..writeln(
      '**Longest UI stall** is the longest the UI thread went without '
      'returning to the event loop while the sort was in progress. A sort '
      'run on the UI thread shows its whole duration here, and anything over '
      '16 ms is a dropped frame at 60 Hz. **Until sorted** is from the '
      'request to the grid\'s model being in the new order. Figures are '
      'medians of 3 runs; stall cells show `median (max)`.',
    )
    ..writeln()
    ..writeln(
      'Versions: ${[for (final g in _order)
        if (names[g] != null) names[g]].join(' · ')}',
    )
    ..writeln()
    ..writeln('### Test device')
    ..writeln()
    ..writeln('| | |')
    ..writeln('|---|---|');
  for (final line in device) {
    out.writeln(line);
  }

  for (final rows in results.keys.toList()..sort()) {
    final grids = [
      for (final g in _order)
        if (names.containsKey(g) || (dnf[rows]?.contains(g) ?? false)) g,
    ];
    out
      ..writeln()
      ..writeln('## ${_thousands(rows)} rows')
      ..writeln()
      ..writeln('| | ${[for (final g in grids) names[g] ?? g].join(' | ')} |')
      ..writeln('|---|${[for (final _ in grids) '--:'].join('|')}|');
    for (final metric in metrics) {
      final row = results[rows]![metric];
      if (row == null) continue;
      final cells = [
        for (final g in grids)
          if (row[g] == null)
            (dnf[rows]?.contains(g) ?? false) ? 'did not finish' : '—'
          else if (metric.contains('stall'))
            '${ms(row[g]![0])} (${ms(row[g]![2])})'
          else
            ms(row[g]![0]),
      ];
      out.writeln('| $metric (ms) | ${cells.join(' | ')} |');
    }
    final mem = memory[rows] ?? {};
    String memCell(String g, int Function(List<int>) pick) {
      final m = mem[g];
      if (m == null) return '—';
      return '${pick([for (final v in m) int.parse(v)])}';
    }

    out
      ..writeln(
        '| Memory for the grid\'s row model (MB) | '
        '${[for (final g in grids) memCell(g, (m) => m[2] - m[1])].join(' | ')} |',
      )
      ..writeln(
        '| Memory added by mounting (MB) | '
        '${[for (final g in grids) memCell(g, (m) => m[3] - m[2])].join(' | ')} |',
      )
      ..writeln(
        '| Peak RSS, whole process (MB) | '
        '${[for (final g in grids) memCell(g, (m) => m[4])].join(' | ')} |',
      );

    // Every grid must have produced the same order, by sort key.
    for (final entry in (orders[rows] ?? {}).entries) {
      final keys = entry.value.values.toSet();
      out.writeln(
        '| Same order as the others: ${entry.key} | '
        '${[for (final g in grids) entry.value[g] == null ? '—' : (keys.length == 1 ? 'yes' : (entry.value[g] == entry.value['fitgrid'] ? 'yes' : 'DIFFERS'))].join(' | ')} |',
      );
    }
  }

  out
    ..writeln()
    ..writeln(
      'Measured under `flutter test` in debug mode (JIT, asserts on), '
      'headless, with no GPU rasterisation — the same for every grid. '
      'Absolute times are higher than a profile or release build on a '
      'device; the comparison between grids is the point. RSS is the whole '
      'test process, framework included.',
    );
  stdout.write(out);
}

String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
