// Large filters run in slices across frames. These use plain `test` rather
// than `testWidgets` so the slices run on real time.

import 'dart:math' as math;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  const _Item(this.id, this.name, this.city, this.amount);

  final int id;
  final String name;
  final String city;
  final double amount;
}

const _cities = <String>['Berlin', 'MÜNCHEN', 'Straße', 'Oslo', 'İzmir'];

List<_Item> _items(int count, {int seed = 1}) {
  final random = math.Random(seed);
  return List<_Item>.generate(
    count,
    (i) => _Item(
      i,
      'Customer ${random.nextInt(5000)}',
      _cities[random.nextInt(_cities.length)],
      random.nextInt(10000) / 10,
    ),
    growable: false,
  );
}

final _columns = <FitGridColumn<_Item>>[
  FitGridColumn<_Item>(id: 'name', label: 'Name', value: (r) => r.name),
  FitGridColumn<_Item>(id: 'city', label: 'City', value: (r) => r.city),
  FitGridColumn<_Item>(
    id: 'amount',
    label: 'Amount',
    value: (r) => r.amount.toStringAsFixed(1),
    sortable: true,
    sortValue: (r) => r.amount,
    filter: FitGridFilterSpec<_Item>.number((r) => r.amount),
  ),
];

FitGridController<_Item> _controller(List<_Item> rows, {int? threshold = 1}) {
  final controller = FitGridController<_Item>(rows: rows, columns: _columns);
  controller.data
    ..backgroundFilterThreshold = threshold
    ..backgroundSortThreshold = threshold;
  addTearDown(controller.dispose);
  return controller;
}

List<int> _ids(FitGridController<_Item> controller) => <int>[
  for (final row in controller.data.view) row.id,
];

/// The same search on the UI thread, for comparison.
List<int> _foreground(
  List<_Item> rows,
  String query, {
  List<FitGridSortKey> sort = const [],
  bool caseSensitive = false,
}) {
  final controller = _controller(rows, threshold: null)
    ..filter.caseSensitive = caseSensitive
    ..filter.query = query
    ..setSort(sort);
  return _ids(controller);
}

void main() {
  test('a background filter matches the foreground one', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    controller.filter.query = 'customer 12';
    controller.data.view;
    expect(controller.data.isFiltering, isTrue);
    await controller.data.whenSorted();

    expect(controller.data.isFiltering, isFalse);
    expect(_ids(controller), _foreground(rows, 'customer 12'));
    expect(_ids(controller), isNotEmpty);
  });

  test('the previous rows stay on screen until the filter lands', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    final shown = controller.data.view;

    controller.filter.query = 'Oslo';
    expect(identical(controller.data.view, shown), isTrue);
    await controller.data.whenSorted();
    expect(controller.data.view.every((r) => r.city == 'Oslo'), isTrue);
  });

  test('typing, backspacing and retyping stay exact', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    for (final query in <String>[
      'c',
      'cu',
      'CUS',
      'cust',
      'customer 1',
      'customer 12',
      'customer 1',
      'customer 3',
      '',
      'oslo',
    ]) {
      controller.filter.query = query;
      await controller.data.whenSorted();
      expect(_ids(controller), _foreground(rows, query), reason: query);
    }
  });

  test('keystrokes typed while a pass runs settle on the last', () async {
    final rows = _items(60000);
    final controller = _controller(rows);
    controller.data.view;

    const typed = 'customer 1234';
    for (var i = 1; i <= typed.length; i++) {
      controller.filter.query = typed.substring(0, i);
      controller.data.view;
    }
    await controller.data.whenSorted();

    expect(_ids(controller), _foreground(rows, typed));
  });

  test('a column filter change is never treated as narrowing', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    controller.filter
      ..query = 'customer'
      ..setFilter(
        'amount',
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.greaterThan,
          value: 900,
        ),
      );
    await controller.data.whenSorted();
    expect(controller.data.view.every((r) => r.amount > 900), isTrue);

    // Widening the column filter while the search grows: the result must
    // not be taken from the narrower previous one.
    controller.filter
      ..query = 'customer 1'
      ..setFilter(
        'amount',
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.greaterThan,
          value: 100,
        ),
      );
    await controller.data.whenSorted();
    expect(_ids(controller), <int>[
      for (final row in rows)
        if (row.amount > 100 && row.name.contains('Customer 1')) row.id,
    ]);
  });

  test('switching case sensitivity re-filters every row', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    controller.filter
      ..caseSensitive = true
      ..query = 'BERLIN';
    await controller.data.whenSorted();
    expect(controller.data.view, isEmpty);

    controller.filter.caseSensitive = false;
    await controller.data.whenSorted();
    expect(_ids(controller), _foreground(rows, 'BERLIN'));
    expect(_ids(controller), isNotEmpty);
  });

  test('case folding beyond ASCII matches the foreground search', () async {
    final rows = _items(20000);
    for (final query in <String>['münchen', 'STRASSE', 'straße', 'izmir']) {
      final controller = _controller(rows);
      controller.data.view;
      controller.filter.query = query;
      await controller.data.whenSorted();
      final expected = <int>[
        for (final row in rows)
          if (row.name.toLowerCase().contains(query.toLowerCase()) ||
              row.city.toLowerCase().contains(query.toLowerCase()))
            row.id,
      ];
      expect(_ids(controller), expected, reason: query);
    }
  });

  test('a filter over a background sort lands in sorted order', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;
    const sort = [FitGridSortKey('amount', FitGridSortDirection.descending)];

    controller
      ..filter.query = 'customer 4'
      ..setSort(sort);
    await controller.data.whenSorted();

    expect(_ids(controller), _foreground(rows, 'customer 4', sort: sort));
  });

  test('rows replaced while filtering are filtered as they are now', () async {
    var rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;
    controller.filter.query = 'oslo';
    controller.data.view;

    rows = _items(20000, seed: 7);
    controller.data.rows = rows;
    await controller.data.whenSorted();

    expect(_ids(controller), _foreground(rows, 'oslo'));
  });

  test('below the threshold the filter is immediate', () {
    final rows = _items(2000);
    final controller = _controller(rows, threshold: 50000);

    controller.filter.query = 'oslo';

    expect(controller.data.isFiltering, isFalse);
    expect(_ids(controller), _foreground(rows, 'oslo'));
  });

  test('disposing mid-filter is quiet', () async {
    final controller = FitGridController<_Item>(
      rows: _items(60000),
      columns: _columns,
    )..data.backgroundFilterThreshold = 1;
    controller.data.view;
    controller.filter.query = 'customer';
    controller.data.view;
    final done = controller.data.whenSorted();
    controller.dispose();
    await done;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('a hidden column is not searched, and showing it again is', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    controller.filter.query = 'oslo';
    await controller.data.whenSorted();
    expect(controller.data.view, isNotEmpty);

    controller.columns.setVisible('city', false);
    await controller.data.whenSorted();
    expect(controller.data.view, isEmpty);

    controller.columns.setVisible('city', true);
    await controller.data.whenSorted();
    expect(_ids(controller), _foreground(rows, 'oslo'));
  });

  test('a live feed of replaced rows is searched as it is now', () async {
    var rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;
    controller.filter.query = 'customer 7';
    await controller.data.whenSorted();

    final random = math.Random(3);
    for (var tick = 0; tick < 6; tick++) {
      rows = List<_Item>.of(rows);
      for (var i = 0; i < 200; i++) {
        final at = random.nextInt(rows.length);
        final old = rows[at];
        rows[at] = _Item(
          old.id,
          'Customer ${random.nextInt(5000)}',
          old.city,
          old.amount,
        );
      }
      controller.data.rows = rows;
      await controller.data.whenSorted();
      expect(
        _ids(controller),
        _foreground(rows, 'customer 7'),
        reason: '$tick',
      );
    }
  });

  test('a search that spans two cells matches nothing', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    // The last characters of a name and the first of a city: in neither cell.
    controller.filter.query = '1berlin';
    await controller.data.whenSorted();
    expect(controller.data.view, isEmpty);

    controller.filter.query = '\u0000';
    await controller.data.whenSorted();
    expect(controller.data.view, isEmpty);
  });

  test('the search combines with a column filter', () async {
    final rows = _items(20000);
    final controller = _controller(rows);
    controller.data.view;

    controller.filter
      ..setFilter(
        'amount',
        const FitGridColumnFilter(
          operator: FitGridFilterOperator.lessThan,
          value: 300,
        ),
      )
      ..query = 'customer 2';
    await controller.data.whenSorted();

    expect(_ids(controller), <int>[
      for (final row in rows)
        if (row.amount < 300 && row.name.contains('Customer 2')) row.id,
    ]);
  });

  test('after the first search, a keystroke reads no cells', () async {
    final rows = _items(20000);
    var reads = 0;
    final controller = FitGridController<_Item>(
      rows: rows,
      columns: <FitGridColumn<_Item>>[
        FitGridColumn<_Item>(
          id: 'name',
          label: 'Name',
          value: (r) {
            reads++;
            return r.name;
          },
        ),
      ],
    )..data.backgroundFilterThreshold = 1;
    addTearDown(controller.dispose);
    controller.data.view;

    controller.filter.query = 'customer 1';
    await controller.data.whenSorted();
    expect(reads, rows.length, reason: 'the index reads each row once');

    reads = 0;
    controller.filter.query = 'customer 12';
    await controller.data.whenSorted();
    controller.filter.query = 'customer 3';
    await controller.data.whenSorted();
    expect(reads, 0);
    expect(_ids(controller), <int>[
      for (final row in rows)
        if (row.name.toLowerCase().contains('customer 3')) row.id,
    ]);
  });
}
