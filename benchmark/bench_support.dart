// Shared by the workload and stress benchmarks: timing statistics, memory
// sampling and a description of the machine, so every number printed comes
// with what it was measured on.

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Timings of one operation, in microseconds, summarised as a table row.
class Samples {
  Samples(this.label);

  final String label;
  final List<int> _micros = <int>[];

  /// Resident memory after the last sample, so a row says what the operation
  /// left behind as well as how long it took.
  int? rssAfter;

  bool get isEmpty => _micros.isEmpty;

  void add(int micros) => _micros.add(micros);

  /// Times [body], adds it, and returns its result.
  Future<R> time<R>(Future<R> Function() body) async {
    final watch = Stopwatch()..start();
    final result = await body();
    watch.stop();
    add(watch.elapsedMicroseconds);
    return result;
  }

  int _percentile(double p) {
    final sorted = List<int>.of(_micros)..sort();
    final at = ((sorted.length - 1) * p).round();
    return sorted[at];
  }

  int get median => _percentile(0.5);
  int get p90 => _percentile(0.9);
  int get p99 => _percentile(0.99);
  int get max => _percentile(1);
  int get count => _micros.length;
}

String ms(int micros) => (micros / 1000).toStringAsFixed(2);

String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

int get rss => ProcessInfo.currentRss;

int get peakRss => ProcessInfo.maxRss;

/// A markdown table of [rows], ready to paste into an issue or a post.
String table(String title, List<Samples> rows) {
  final out = StringBuffer()
    ..writeln()
    ..writeln('### $title')
    ..writeln()
    ..writeln(
      '| Operation | n | median ms | p90 ms | p99 ms | max ms | RSS after MB |',
    )
    ..writeln('|---|--:|--:|--:|--:|--:|--:|');
  for (final row in rows) {
    if (row.isEmpty) continue;
    out.writeln(
      '| ${row.label} | ${row.count} | ${ms(row.median)} | ${ms(row.p90)} '
      '| ${ms(row.p99)} | ${ms(row.max)} '
      '| ${row.rssAfter == null ? '' : mb(row.rssAfter!)} |',
    );
  }
  return out.toString();
}

/// What the numbers were measured on. Best effort: every field that cannot be
/// read on this platform says so rather than guessing.
String deviceReport() {
  String? read(String path, RegExp pattern) {
    try {
      final match = pattern.firstMatch(File(path).readAsStringSync());
      return match?.group(1)?.trim();
    } on Object {
      return null;
    }
  }

  String? run(String command, List<String> args) {
    try {
      final result = Process.runSync(command, args);
      if (result.exitCode != 0) return null;
      final text = (result.stdout as String).trim();
      return text.isEmpty ? null : text;
    } on Object {
      return null;
    }
  }

  String? cpu;
  String? memory;
  if (Platform.isLinux) {
    cpu = read('/proc/cpuinfo', RegExp(r'model name\s*:\s*(.+)'));
    final kb = read('/proc/meminfo', RegExp(r'MemTotal:\s*(\d+)'));
    if (kb != null) memory = '${(int.parse(kb) / 1024 / 1024).round()} GB';
  } else if (Platform.isMacOS) {
    cpu = run('sysctl', <String>['-n', 'machdep.cpu.brand_string']);
    final bytes = run('sysctl', <String>['-n', 'hw.memsize']);
    if (bytes != null) {
      memory = '${(int.parse(bytes) / 1024 / 1024 / 1024).round()} GB';
    }
  } else if (Platform.isWindows) {
    cpu = Platform.environment['PROCESSOR_IDENTIFIER'];
  }

  final mode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug (JIT, asserts on)';
  return '''

### Test device

| | |
|---|---|
| OS | ${Platform.operatingSystem} ${Platform.operatingSystemVersion} |
| CPU | ${cpu ?? 'unknown'} |
| Logical cores | ${Platform.numberOfProcessors} |
| Memory | ${memory ?? 'unknown'} |
| Dart | ${Platform.version.split(' (').first} |
| Build mode | $mode |
| Harness | `flutter test`: headless, build + layout + paint on the CPU, no GPU raster |
''';
}

/// The caveat that has to travel with every table these benchmarks print.
const String caveat = '''
Timings are wall-clock on the UI thread for build, layout and paint, measured
under `flutter test` in debug mode. That overstates absolute cost against a
profile or release build on a device, and it leaves out GPU rasterisation. Read
them for how cost scales across rows, columns and operations, not as frame
times a phone will show.
RSS is the whole test process, framework included; the baseline row is the
cost of the harness before any data exists.
''';
