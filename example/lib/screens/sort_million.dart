import 'dart:async';
import 'dart:math' as math;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/sort_benchmark_results.dart';
import '../shared/demo_page.dart';

/// Sorting a million rows with the UI still drawing: a dot that keeps moving,
/// a meter of the longest gap between frames, and a switch to sort on the UI
/// thread instead, so the difference shows on whatever device runs it.
class SortMillionScreen extends StatefulWidget {
  const SortMillionScreen({
    super.key,
    this.sizes = const <int>[100000, 1000000],
  });

  /// The row counts on offer. Tests pass small ones.
  final List<int> sizes;

  @override
  State<SortMillionScreen> createState() => _SortMillionScreenState();
}

class _Order {
  const _Order(this.id, this.customer, this.region, this.amount, this.placed);

  final int id;
  final String customer;
  final String region;
  final int amount;
  final DateTime placed;
}

const _regions = <String>['North', 'South', 'East', 'West', 'Central'];

/// Top-level so it can run on another isolate: generating a million rows is
/// itself a second or so of work, and the page should not freeze doing it.
List<_Order> _generate(int count) {
  final random = math.Random(42);
  final start = DateTime(2020);
  return List<_Order>.generate(
    count,
    (i) => _Order(
      i,
      'Customer ${random.nextInt(200000)}',
      _regions[random.nextInt(_regions.length)],
      random.nextInt(500000),
      start.add(Duration(days: random.nextInt(2000))),
    ),
    growable: false,
  );
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _count(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// What the last sort cost, as the UI felt it.
class _SortReport {
  const _SortReport({
    required this.label,
    required this.background,
    required this.longestGap,
    required this.dropped,
    required this.total,
  });

  final String label;
  final bool background;
  final Duration longestGap;
  final int dropped;
  final Duration total;
}

class _SortMillionScreenState extends State<SortMillionScreen>
    with SingleTickerProviderStateMixin {
  static const _frame = Duration(microseconds: 16667);

  late int _size = widget.sizes.last;
  FitGridController<_Order>? _controller;
  bool _background = true;

  /// Ticks every frame the UI thread manages to draw. The gap between two
  /// ticks is how long the screen was frozen.
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _clock = Stopwatch()..start();
  int _lastTick = 0;
  int _longestGap = 0;
  int _dropped = 0;
  bool _measuring = false;

  final ValueNotifier<_SortReport?> _report = ValueNotifier(null);
  final ValueNotifier<bool> _sorting = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller?.dispose();
    _report.dispose();
    _sorting.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final old = _controller;
    setState(() => _controller = null);
    old?.dispose();
    final rows = await compute(_generate, _size);
    if (!mounted) return;
    final controller = FitGridController<_Order>(rows: rows, columns: _columns);
    controller.data.backgroundSortThreshold = _background ? 50000 : null;
    _report.value = null;
    setState(() => _controller = controller);
  }

  static final List<FitGridColumn<_Order>> _columns = <FitGridColumn<_Order>>[
    FitGridColumn<_Order>(
      id: 'id',
      label: 'Order',
      value: (o) => '#${o.id}',
      alignment: FitGridAlignment.end,
      sortable: true,
      sortValue: (o) => o.id,
    ),
    FitGridColumn<_Order>(
      id: 'customer',
      label: 'Customer',
      value: (o) => o.customer,
      sortable: true,
    ),
    FitGridColumn<_Order>(
      id: 'region',
      label: 'Region',
      value: (o) => o.region,
      sortable: true,
    ),
    FitGridColumn<_Order>(
      id: 'amount',
      label: 'Amount',
      value: (o) => (o.amount / 100).toStringAsFixed(2),
      alignment: FitGridAlignment.end,
      sortable: true,
      sortValue: (o) => o.amount,
    ),
    FitGridColumn<_Order>(
      id: 'placed',
      label: 'Placed',
      value: (o) => _date(o.placed),
      sortable: true,
      sortValue: (o) => o.placed,
    ),
  ];

  void _onTick(Duration _) {
    final now = _clock.elapsedMicroseconds;
    final gap = now - _lastTick;
    _lastTick = now;
    if (!_measuring) return;
    if (gap > _longestGap) _longestGap = gap;
    // A gap of n frame times means n - 1 frames that should have been drawn
    // and were not.
    final missed = gap ~/ _frame.inMicroseconds - 1;
    if (missed > 0) _dropped += missed;
  }

  Future<void> _sort(String columnId, String label) async {
    final controller = _controller;
    if (controller == null || _sorting.value) return;
    final current = controller.data.directionOf(columnId);
    final direction = current == FitGridSortDirection.ascending
        ? FitGridSortDirection.descending
        : FitGridSortDirection.ascending;

    _sorting.value = true;
    _longestGap = 0;
    _dropped = 0;
    _measuring = true;
    final start = _clock.elapsedMicroseconds;
    // The UI-thread sort happens right here, inside this call; the background
    // one only starts here and finishes later.
    controller.setSort(<FitGridSortKey>[FitGridSortKey(columnId, direction)]);
    await controller.data.whenSorted();
    // And the frame that shows it.
    await SchedulerBinding.instance.endOfFrame;
    final total = _clock.elapsedMicroseconds - start;
    _measuring = false;
    if (!mounted) return;
    _report.value = _SortReport(
      label:
          '$label ${direction == FitGridSortDirection.ascending ? '↑' : '↓'}',
      background: _background && _size >= 50000,
      longestGap: Duration(microseconds: _longestGap),
      dropped: _dropped,
      total: Duration(microseconds: total),
    );
    _sorting.value = false;
  }

  void _setBackground(bool value) {
    setState(() => _background = value);
    _controller?.data.backgroundSortThreshold = value ? 50000 : null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return DemoPage(
      title: 'Sorting a million rows',
      notes: [
        const DemoNote(
          'Sort by any column and watch the dot. It moves once per frame, so '
          'whenever the UI thread is busy it stops. The meter records the '
          'longest gap between frames during the sort and how many frames '
          'were dropped.',
        ),
        const DemoNote(
          'From 50,000 rows fitgrid sorts on a background isolate: the keys '
          'are read out of the rows in short slices, sorted elsewhere, and '
          'swapped in when ready, while the old order stays on screen. Switch '
          'to "UI thread" to see the same sort done the usual way.',
        ),
        const DemoNote.recommended(
          'Give number and date columns a sortValue. A closure comparator '
          'cannot cross to another isolate, so a column with only a '
          'comparator always sorts on the UI thread.',
          code:
              'FitGridColumn<Order>(\n'
              '  id: \'amount\',\n'
              '  value: (o) => o.amount.toStringAsFixed(2),\n'
              '  sortable: true,\n'
              '  sortValue: (o) => o.amount,\n'
              ')',
        ),
        if (kIsWeb)
          const DemoNote.avoid(
            'On the web there are no isolates, so the sort itself still runs '
            'on the UI thread here; only reading the keys is sliced. Run the '
            'app on a device or desktop to see the full effect.',
          ),
      ],
      controls: _Controls(state: this),
      child: controller == null
          ? const Center(child: CircularProgressIndicator())
          : FitGrid<_Order>(controller: controller),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final _SortMillionScreenState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<int>(
              segments: [
                for (final size in s.widget.sizes)
                  ButtonSegment<int>(
                    value: size,
                    label: Text('${_count(size)} rows'),
                  ),
              ],
              selected: <int>{s._size},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                // ignore: invalid_use_of_protected_member
                s.setState(() => s._size = value.first);
                s._load();
              },
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Background'),
                  icon: Icon(Icons.bolt_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('UI thread'),
                  icon: Icon(Icons.hourglass_bottom),
                ),
              ],
              selected: <bool>{s._background},
              showSelectedIcon: false,
              onSelectionChanged: (value) => s._setBackground(value.first),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: s._sorting,
              builder: (context, sorting, _) => Wrap(
                spacing: 8,
                children: [
                  for (final (id, label) in const [
                    ('customer', 'Customer'),
                    ('amount', 'Amount'),
                    ('placed', 'Date'),
                  ])
                    FilledButton.tonal(
                      onPressed: sorting || s._controller == null
                          ? null
                          : () => s._sort(id, label),
                      child: Text('Sort by $label'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 160, height: 28, child: _Heartbeat()),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<_SortReport?>(
                valueListenable: s._report,
                builder: (context, report, _) => ValueListenableBuilder<bool>(
                  valueListenable: s._sorting,
                  builder: (context, sorting, _) {
                    if (sorting) {
                      return const Text('Sorting…');
                    }
                    if (report == null) {
                      return Text(
                        'Sort a column to measure it.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      );
                    }
                    final frozen = report.longestGap.inMicroseconds > 16667 * 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatChip(
                          label: report.label,
                          value: report.background ? 'background' : 'UI thread',
                        ),
                        StatChip(
                          label: 'UI blocked',
                          value:
                              '${(report.longestGap.inMicroseconds / 1000).toStringAsFixed(0)} ms'
                              '${frozen ? ' — frozen' : ''}',
                        ),
                        StatChip(
                          label: 'Dropped frames',
                          value: '${report.dropped}',
                        ),
                        StatChip(
                          label: 'Sorted in',
                          value:
                              '${(report.total.inMicroseconds / 1000).toStringAsFixed(0)} ms',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _ComparisonCard(),
      ],
    );
  }
}

/// A dot that crosses a track once a second, one step per frame. It stops
/// dead whenever a frame is not drawn, which is the point.
class _Heartbeat extends StatefulWidget {
  const _Heartbeat();

  @override
  State<_Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<_Heartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Frame heartbeat',
      child: CustomPaint(
        painter: _HeartbeatPainter(
          _animation,
          track: scheme.surfaceContainerHighest,
          dot: scheme.primary,
        ),
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  _HeartbeatPainter(this.progress, {required this.track, required this.dot})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color track;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = track,
    );
    final x = radius + (size.width - 2 * radius) * progress.value;
    canvas.drawCircle(Offset(x, radius), radius - 4, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) =>
      old.track != track || old.dot != dot;
}

/// The measured comparison with other Flutter grids, from
/// `benchmark/compare/`. Static data: the other grids are not dependencies of
/// this app.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.leaderboard_outlined, color: scheme.primary),
        title: const Text('How other Flutter grids compare'),
        subtitle: Text(
          'UI blocked while sorting ${_count(sortBenchmarkRows)} rows, measured',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: theme.textTheme.labelLarge,
              columns: [
                const DataColumn(label: Text('')),
                for (final grid in sortBenchmarkGrids)
                  DataColumn(label: Text(grid), numeric: true),
              ],
              rows: [
                for (final (metric, values) in sortBenchmarkRowsTable)
                  DataRow(
                    cells: [
                      DataCell(Text(metric)),
                      for (var i = 0; i < values.length; i++)
                        DataCell(
                          Text(
                            values[i],
                            style: i == 0
                                ? const TextStyle(fontWeight: FontWeight.w700)
                                : null,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sortBenchmarkFootnote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
