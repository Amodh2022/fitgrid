// Large sorts run on a background isolate. These use plain `test` rather than
// `testWidgets` so the isolate and the sliced key reading run on real time.

import 'dart:math' as math;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  const _Item(this.id, this.name, this.amount, this.when, this.flag);

  final int id;
  final String name;
  final double? amount;
  final DateTime when;
  final bool flag;
}

List<_Item> _items(int count, {int seed = 1}) {
  final random = math.Random(seed);
  return List<_Item>.generate(
    count,
    (i) => _Item(
      i,
      // Few distinct names, so ties are common and stability shows.
      'Name ${random.nextInt(40)}',
      random.nextInt(10) == 0 ? null : random.nextInt(1000) / 10,
      DateTime(2020).add(Duration(hours: random.nextInt(10000))),
      random.nextBool(),
    ),
    growable: false,
  );
}

final _columns = <FitGridColumn<_Item>>[
  FitGridColumn<_Item>(
    id: 'name',
    label: 'Name',
    value: (r) => r.name,
    sortable: true,
  ),
  FitGridColumn<_Item>(
    id: 'amount',
    label: 'Amount',
    value: (r) => r.amount?.toStringAsFixed(1) ?? '',
    sortable: true,
    sortValue: (r) => r.amount,
  ),
  FitGridColumn<_Item>(
    id: 'when',
    label: 'When',
    value: (r) => r.when.toIso8601String(),
    sortable: true,
    sortValue: (r) => r.when,
  ),
  FitGridColumn<_Item>(
    id: 'flag',
    label: 'Flag',
    value: (r) => r.flag ? 'yes' : 'no',
    sortable: true,
    sortValue: (r) => r.flag,
  ),
  FitGridColumn<_Item>(
    id: 'legacy',
    label: 'Legacy',
    value: (r) => r.id.toString(),
    sortable: true,
    // A closure comparator only: cannot cross an isolate.
    comparator: (a, b) => a.id.compareTo(b.id),
  ),
];

FitGridController<_Item> _controller(List<_Item> rows, {int? threshold = 1}) {
  final controller = FitGridController<_Item>(rows: rows, columns: _columns);
  controller.data.backgroundSortThreshold = threshold;
  return controller;
}

List<int> _ids(FitGridController<_Item> controller) => <int>[
  for (final row in controller.data.view) row.id,
];

/// The same sort on the UI thread, for comparison.
Future<List<int>> _foreground(
  List<_Item> rows,
  List<FitGridSortKey> keys,
) async {
  final controller = _controller(rows, threshold: null)..setSort(keys);
  addTearDown(controller.dispose);
  return _ids(controller);
}

void main() {
  for (final (label, keys) in <(String, List<FitGridSortKey>)>[
    ('text', [const FitGridSortKey('name', FitGridSortDirection.ascending)]),
    (
      'text, descending',
      [const FitGridSortKey('name', FitGridSortDirection.descending)],
    ),
    (
      'numbers with empties',
      [const FitGridSortKey('amount', FitGridSortDirection.ascending)],
    ),
    (
      'numbers descending',
      [const FitGridSortKey('amount', FitGridSortDirection.descending)],
    ),
    ('dates', [const FitGridSortKey('when', FitGridSortDirection.ascending)]),
    (
      'several keys',
      [
        const FitGridSortKey('flag', FitGridSortDirection.descending),
        const FitGridSortKey('name', FitGridSortDirection.ascending),
        const FitGridSortKey('amount', FitGridSortDirection.descending),
      ],
    ),
  ]) {
    test('a background sort by $label matches the foreground one', () async {
      final rows = _items(3000);
      final controller = _controller(rows);
      addTearDown(controller.dispose);

      controller.setSort(keys);
      controller.data.view;
      expect(controller.data.isSorting, isTrue);
      await controller.data.whenSorted();

      expect(controller.data.isSorting, isFalse);
      expect(_ids(controller), await _foreground(rows, keys));
    });
  }

  test('the previous order stays on screen until the sort lands', () async {
    final rows = _items(2000);
    final controller = _controller(rows);
    addTearDown(controller.dispose);
    controller.setSort(const [
      FitGridSortKey('name', FitGridSortDirection.ascending),
    ]);
    // Unsorted until the first result: the rows as supplied.
    expect(_ids(controller), <int>[for (final row in rows) row.id]);
    await controller.data.whenSorted();
    final byName = _ids(controller);
    final shown = controller.data.view;

    controller.setSort(const [
      FitGridSortKey('amount', FitGridSortDirection.ascending),
    ]);
    expect(_ids(controller), byName, reason: 'kept while sorting');
    // The very list on screen, not a rebuilt copy of it: on a million rows
    // the copy alone would cost a frame.
    expect(identical(controller.data.view, shown), isTrue);
    expect(controller.data.isSorting, isTrue);
    await controller.data.whenSorted();
    expect(
      _ids(controller),
      await _foreground(rows, const [
        FitGridSortKey('amount', FitGridSortDirection.ascending),
      ]),
    );
  });

  test('changing the filter on a sorted grid does not sort again', () async {
    final rows = _items(2000);
    final controller = _controller(rows);
    addTearDown(controller.dispose);
    controller.setSort(const [
      FitGridSortKey('amount', FitGridSortDirection.descending),
    ]);
    await controller.data.whenSorted();
    final sorted = _ids(controller);

    controller.filter.query = 'Name 1';
    final filtered = _ids(controller);

    expect(controller.data.isSorting, isFalse);
    final kept = <int>{for (final row in controller.data.view) row.id};
    expect(filtered, <int>[
      for (final id in sorted)
        if (kept.contains(id)) id,
    ]);
    expect(
      controller.data.view.every((row) => row.name.contains('Name 1')),
      isTrue,
    );
  });

  test('rows replaced mid-sort end up sorted by their new values', () async {
    var rows = _items(4000);
    final controller = _controller(rows);
    addTearDown(controller.dispose);
    controller.setSort(const [
      FitGridSortKey('amount', FitGridSortDirection.ascending),
    ]);
    controller.data.view;

    // A live feed: several rounds of replaced records while sorting.
    final random = math.Random(5);
    for (var tick = 0; tick < 5; tick++) {
      rows = List<_Item>.of(rows);
      for (var i = 0; i < 50; i++) {
        final at = random.nextInt(rows.length);
        final old = rows[at];
        rows[at] = _Item(
          old.id,
          old.name,
          random.nextInt(1000) / 10,
          old.when,
          old.flag,
        );
      }
      controller.data.rows = rows;
      expect(controller.data.view, hasLength(rows.length));
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await controller.data.whenSorted();

    expect(
      _ids(controller),
      await _foreground(rows, const [
        FitGridSortKey('amount', FitGridSortDirection.ascending),
      ]),
    );
  });

  test('rows added mid-sort are shown, then sorted in', () async {
    final rows = _items(3000);
    final controller = _controller(rows);
    addTearDown(controller.dispose);
    controller.setSort(const [
      FitGridSortKey('name', FitGridSortDirection.ascending),
    ]);
    await controller.data.whenSorted();

    final more = <_Item>[
      ...rows,
      ..._items(
        500,
        seed: 9,
      ).map((r) => _Item(r.id + 3000, r.name, r.amount, r.when, r.flag)),
    ];
    controller.data.rows = more;
    // The old order with the new rows on the end, until the sort catches up.
    expect(controller.data.view, hasLength(3500));
    expect(_ids(controller).toSet(), <int>{for (var i = 0; i < 3500; i++) i});
    await controller.data.whenSorted();

    expect(
      _ids(controller),
      await _foreground(more, const [
        FitGridSortKey('name', FitGridSortDirection.ascending),
      ]),
    );
  });

  test('a column with only a comparator sorts on the UI thread', () {
    final rows = _items(2000).reversed.toList();
    final controller = _controller(rows);
    addTearDown(controller.dispose);

    controller.toggleSort('legacy');

    expect(controller.data.isSorting, isFalse);
    expect(_ids(controller), <int>[for (var i = 0; i < 2000; i++) i]);
  });

  test('below the threshold the sort is immediate', () {
    final rows = _items(500);
    final controller = _controller(rows, threshold: 50000);
    addTearDown(controller.dispose);

    controller.toggleSort('name');

    expect(controller.data.isSorting, isFalse);
    expect(controller.data.view.first.name, 'Name 0');
  });

  test('the selection follows its records through a background sort', () async {
    final rows = _items(3000);
    final controller = _controller(rows);
    addTearDown(controller.dispose);
    controller.selection.mode = FitGridSelectionMode.multiple;
    controller.selection.select(<int>[10, 20, 30]);

    controller.setSort(const [
      FitGridSortKey('amount', FitGridSortDirection.descending),
    ]);
    controller.data.view;
    await controller.data.whenSorted();

    expect(
      <int>{
        for (final i in controller.selection.selected)
          controller.data.view[i].id,
      },
      <int>{10, 20, 30},
    );
  });

  test('disposing mid-sort is quiet', () async {
    final controller = _controller(_items(20000));
    controller.toggleSort('name');
    controller.data.view;
    final done = controller.data.whenSorted();
    controller.dispose();
    await done;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
}
