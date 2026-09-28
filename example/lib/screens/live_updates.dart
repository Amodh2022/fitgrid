import 'dart:async';
import 'dart:io' show Platform, ProcessInfo;
import 'dart:math' as math;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../shared/demo_page.dart';

/// The stress case from `benchmark/stress_benchmark.dart`, live: 100,000 rows
/// by 30 columns of mixed text lengths, two frozen columns, a filter on, and
/// rows replaced underneath while you scroll, select and sort. The readouts are
/// the engine's own frame timings, so on a device in profile mode they are the
/// numbers to quote.
class LiveUpdatesScreen extends StatefulWidget {
  const LiveUpdatesScreen({super.key, this.rowCount = 100000});

  /// Tests pass fewer; the demo is the full size.
  final int rowCount;

  @override
  State<LiveUpdatesScreen> createState() => _LiveUpdatesScreenState();
}

class _Record {
  const _Record(this.id, this.status, this.price, this.change, this.cells);

  final int id;
  final String status;
  final int price;
  final int change;
  final List<String> cells;

  _Record tick(math.Random random) {
    final delta = random.nextInt(2001) - 1000;
    return _Record(
      id,
      random.nextInt(20) == 0
          ? _statuses[random.nextInt(_statuses.length)]
          : status,
      math.max(1, price + delta),
      delta,
      cells,
    );
  }
}

const _statuses = <String>['Active', 'Pending', 'Halted', 'Closed'];
const _columnCount = 30;
const _lorem =
    'lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod '
    'tempor incididunt ut labore et dolore magna aliqua ut enim ad minim '
    'veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
    'commodo consequat duis aute irure dolor in reprehenderit in voluptate';

enum _Kind { code, name, sentence, paragraph, number, date }

_Kind _kindOf(int column) => _Kind.values[column % _Kind.values.length];

String _cell(_Kind kind, math.Random random) => switch (kind) {
  _Kind.code => String.fromCharCodes(
    List<int>.generate(2 + random.nextInt(5), (_) => 65 + random.nextInt(26)),
  ),
  _Kind.name => 'Name ${random.nextInt(1000000)}',
  _Kind.sentence => () {
    final start = random.nextInt(100);
    return _lorem.substring(start, start + 15 + random.nextInt(50));
  }(),
  _Kind.paragraph => (_lorem * 2).substring(0, 60 + random.nextInt(240)),
  _Kind.number => (random.nextDouble() * 1e6).toStringAsFixed(
    random.nextInt(4),
  ),
  _Kind.date =>
    '20${10 + random.nextInt(16)}-0${1 + random.nextInt(9)}-'
        '1${random.nextInt(10)}',
};

List<_Record> _generate(int count) {
  final random = math.Random(3);
  return List<_Record>.generate(
    count,
    (i) => _Record(
      i,
      _statuses[random.nextInt(_statuses.length)],
      random.nextInt(1000000),
      0,
      List<String>.generate(
        _columnCount - 4,
        (c) => _cell(_kindOf(c), random),
        growable: false,
      ),
    ),
    growable: false,
  );
}

/// Rolling percentiles over the last [capacity] samples, in microseconds.
class _Window {
  _Window([this.capacity = 240]);

  final int capacity;
  final List<int> _values = <int>[];

  void add(int micros) {
    _values.add(micros);
    if (_values.length > capacity) _values.removeAt(0);
  }

  void clear() => _values.clear();

  bool get isEmpty => _values.isEmpty;

  double percentile(double p) {
    if (_values.isEmpty) return 0;
    final sorted = List<int>.of(_values)..sort();
    return sorted[((sorted.length - 1) * p).round()] / 1000;
  }
}

class _LiveUpdatesScreenState extends State<LiveUpdatesScreen> {
  static const _rates = <int>[1, 100, 1000];
  static const _ticksPerSecond = <int>[1, 5, 10];

  late List<_Record> _rows = _generate(widget.rowCount);
  late final FitGridController<_Record> _controller =
      FitGridController<_Record>(
        rows: _rows,
        columns: _buildColumns(),
        selectionMode: FitGridSelectionMode.multiple,
      );
  final math.Random _random = math.Random(9);

  Timer? _timer;
  int _changesPerTick = 100;
  int _tickRate = 5;
  int _ticks = 0;
  bool _filterOn = true;

  final _Window _build = _Window();
  final _Window _raster = _Window();
  final _Window _updateToFrame = _Window(60);
  int _peakRss = 0;

  /// Refreshes the readouts without rebuilding the grid: the page listens to
  /// this, not to setState.
  final ValueNotifier<int> _stats = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _applyFilter();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _controller.dispose();
    _stats.dispose();
    super.dispose();
  }

  List<FitGridColumn<_Record>> _buildColumns() => <FitGridColumn<_Record>>[
    FitGridColumn<_Record>(
      id: 'id',
      label: 'ID',
      value: (r) => '#${r.id}',
      freeze: FitGridFreeze.start,
      alignment: FitGridAlignment.end,
      sortable: true,
      sortValue: (r) => r.id,
      searchable: false,
    ),
    FitGridColumn<_Record>(
      id: 'status',
      label: 'Status',
      value: (r) => r.status,
      freeze: FitGridFreeze.start,
      // Room for the header's sort and filter glyphs as well as the label.
      width: const FitGridColumnWidth.auto(min: 120),
      sortable: true,
      filter: const FitGridFilterSpec.values(options: _statuses),
    ),
    FitGridColumn<_Record>(
      id: 'price',
      label: 'Price',
      value: (r) => r.price.toString(),
      alignment: FitGridAlignment.end,
      sortable: true,
      sortValue: (r) => r.price,
    ),
    FitGridColumn<_Record>(
      id: 'change',
      label: 'Δ',
      value: (r) => r.change > 0 ? '+${r.change}' : '${r.change}',
      alignment: FitGridAlignment.end,
      sortable: true,
      sortValue: (r) => r.change,
      cellStyle: (r, _) => r.change == 0
          ? null
          : TextStyle(
              color: r.change > 0
                  ? const Color(0xFF1E8E3E)
                  : const Color(0xFFD93025),
            ),
    ),
    for (var c = 0; c < _columnCount - 4; c++)
      FitGridColumn<_Record>(
        id: 'c$c',
        label: '${_kindOf(c).name} $c',
        value: (r) => r.cells[c],
        sortable: true,
        width: _kindOf(c) == _Kind.paragraph
            ? const FitGridColumnWidth.auto(max: 320)
            : const FitGridColumnWidth.auto(),
      ),
  ];

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ _tickRate),
      (_) => _tick(),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _stats.value++;
  }

  /// One server push: [_changesPerTick] records replaced with new objects.
  void _tick() {
    final next = List<_Record>.of(_rows, growable: false);
    for (var i = 0; i < _changesPerTick; i++) {
      final at = _random.nextInt(next.length);
      next[at] = next[at].tick(_random);
    }
    _rows = next;
    final watch = Stopwatch()..start();
    _controller.data.rows = next;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateToFrame.add(watch.elapsedMicroseconds);
    });
    _ticks++;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _build.add(timing.buildDuration.inMicroseconds);
      _raster.add(timing.rasterDuration.inMicroseconds);
    }
    _peakRss = math.max(_peakRss, _currentRss() ?? 0);
    if (mounted) _stats.value++;
  }

  static int? _currentRss() {
    if (kIsWeb) return null;
    try {
      return ProcessInfo.currentRss;
    } on Object {
      return null;
    }
  }

  void _applyFilter() {
    _controller.filter.setFilter(
      'status',
      _filterOn
          ? const FitGridColumnFilter.oneOf(<String>{'Active', 'Pending'})
          : null,
    );
  }

  String get _mode => kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  String get _device {
    if (kIsWeb) return 'web';
    return '${Platform.operatingSystem} · '
        '${Platform.numberOfProcessors} cores';
  }

  String _ms(double value) => value.toStringAsFixed(1);

  String _report() {
    final rss = _currentRss();
    return '''
fitgrid live updates — ${widget.rowCount} rows × $_columnCount columns, 2 frozen, filter ${_filterOn ? 'on' : 'off'}
Device: $_device, $_mode mode
Updates: $_changesPerTick rows × $_tickRate/s ($_ticks ticks)
Build ms p50/p90/p99: ${_ms(_build.percentile(.5))} / ${_ms(_build.percentile(.9))} / ${_ms(_build.percentile(.99))}
Raster ms p50/p90/p99: ${_ms(_raster.percentile(.5))} / ${_ms(_raster.percentile(.9))} / ${_ms(_raster.percentile(.99))}
Update to frame ms p50/p90: ${_ms(_updateToFrame.percentile(.5))} / ${_ms(_updateToFrame.percentile(.9))}
RSS MB now/peak: ${rss == null ? 'n/a' : rss ~/ (1 << 20)} / ${_peakRss == 0 ? 'n/a' : _peakRss ~/ (1 << 20)}
''';
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Live updates',
      notes: const [
        DemoNote(
          'The stress case: 100,000 rows by 30 columns of mixed text lengths, '
          'ID and Status frozen, a status filter on, and records replaced '
          'while you scroll, move with the arrow keys, select with Space and '
          'sort from the headers.',
        ),
        DemoNote(
          'Build and raster come from the engine\'s own frame timings. Run '
          'with `flutter run --profile` on the device you care about, then '
          'copy the report: debug-mode numbers are several times slower.',
          code: 'cd example && flutter run --profile',
        ),
        DemoNote.recommended(
          'Replace changed records with new objects and hand the grid the new '
          'list, with rowKey set to the record id, so anything tracking a '
          'record can find it again.',
          code:
              'rows = [for (final r in rows) changed[r.id] ?? r];\n'
              'controller.data.rows = rows;\n\n'
              'FitGrid(controller: controller, rowKey: (r) => r.id)',
        ),
        DemoNote(
          'The "Selected" readout shows which records the selection points '
          'at. Select a few rows, then sort, to see whether it stays on them.',
        ),
      ],
      actions: [
        IconButton(
          tooltip: 'Copy report',
          icon: const Icon(Icons.content_copy_outlined),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _report()));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Report copied')));
          },
        ),
      ],
      controls: _Controls(state: this),
      child: FitGrid<_Record>(
        controller: _controller,
        rowKey: (r) => r.id,
        showSelectionColumn: true,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final _LiveUpdatesScreenState state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: state._stats,
      builder: (context, _, _) {
        final s = state;
        final running = s._timer != null;
        final rss = _LiveUpdatesScreenState._currentRss();
        final selected = s._controller.selection.sorted;
        final view = s._controller.data.view;
        final selectedIds = [
          for (final i in selected.take(4))
            if (i < view.length) '#${view[i].id}',
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    if (running) {
                      s._stop();
                    } else {
                      s._start();
                      s._stats.value++;
                    }
                  },
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(running ? 'Pause updates' : 'Resume updates'),
                ),
                SegmentedButton<int>(
                  segments: [
                    for (final rate in _LiveUpdatesScreenState._rates)
                      ButtonSegment<int>(
                        value: rate,
                        label: Text('$rate rows'),
                      ),
                  ],
                  selected: <int>{s._changesPerTick},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    s._changesPerTick = value.first;
                    s._updateToFrame.clear();
                    s._stats.value++;
                  },
                ),
                SegmentedButton<int>(
                  segments: [
                    for (final rate in _LiveUpdatesScreenState._ticksPerSecond)
                      ButtonSegment<int>(value: rate, label: Text('$rate/s')),
                  ],
                  selected: <int>{s._tickRate},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    s._tickRate = value.first;
                    if (running) s._start();
                    s._stats.value++;
                  },
                ),
                FilterChip(
                  label: const Text('Filter: Active + Pending'),
                  selected: s._filterOn,
                  onSelected: (on) {
                    s._filterOn = on;
                    s._applyFilter();
                    s._stats.value++;
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatChip(
                  label: 'Rows',
                  value: '${view.length} of ${s.widget.rowCount}',
                ),
                StatChip(label: 'Ticks', value: '${s._ticks}'),
                StatChip(
                  label: 'Build p50/p90',
                  value:
                      '${s._ms(s._build.percentile(.5))} / '
                      '${s._ms(s._build.percentile(.9))} ms',
                ),
                StatChip(
                  label: 'Raster p50/p90',
                  value:
                      '${s._ms(s._raster.percentile(.5))} / '
                      '${s._ms(s._raster.percentile(.9))} ms',
                ),
                StatChip(
                  label: 'Update to frame p50',
                  value: '${s._ms(s._updateToFrame.percentile(.5))} ms',
                ),
                StatChip(
                  label: 'RSS',
                  value: rss == null
                      ? 'n/a'
                      : '${rss ~/ (1 << 20)} MB · peak '
                            '${s._peakRss ~/ (1 << 20)} MB',
                ),
                StatChip(label: 'Mode', value: '${s._mode} · ${s._device}'),
                StatChip(
                  label: 'Selected',
                  value: selected.isEmpty
                      ? 'none'
                      : '${selectedIds.join(', ')}'
                            '${selected.length > 4 ? ' +${selected.length - 4}' : ''}',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
