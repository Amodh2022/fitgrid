import 'dart:math';

import 'package:fitgrid_table/fitgrid_table.dart';

/// A row the app never owns: it lives on the fake server below and arrives a
/// page at a time.
class Order {
  const Order({
    required this.id,
    required this.customer,
    required this.status,
    required this.amountCents,
  });

  final int id;
  final String customer;
  final String status;
  final int amountCents;

  String get amountText =>
      '\$${(amountCents ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}'
      '.${(amountCents % 100).toString().padLeft(2, '0')}';
}

/// One page of a response, the way a REST endpoint would shape it.
class OrderPage {
  const OrderPage(this.rows, this.total);

  final List<Order> rows;
  final int total;
}

/// Stands in for a backend: it owns the rows, sorts and searches them itself,
/// and answers after a configurable delay.
///
/// Everything here is what *your server* does. The app side of the demo only
/// ever sees [fetch].
class FakeOrderServer {
  FakeOrderServer({required this.rowCount});

  final int rowCount;
  Duration latency = const Duration(milliseconds: 150);

  late final List<Order> _table = _generate(rowCount);

  // The last result set, keyed by sort and query, the way a database would
  // keep a cursor. Without it every page would re-sort the whole table.
  String? _viewKey;
  List<Order> _view = const [];

  Future<OrderPage> fetch(FitGridPageRequest request) async {
    await Future<void>.delayed(latency);
    final view = _resolveView(request);
    final end = min(request.offset + request.limit, view.length);
    final rows = request.offset >= end
        ? const <Order>[]
        : view.sublist(request.offset, end);
    return OrderPage(rows, view.length);
  }

  List<Order> _resolveView(FitGridPageRequest request) {
    final key =
        '${request.sortColumnId}|${request.sortDirection}|${request.query}';
    if (key == _viewKey) return _view;

    final query = request.query.trim().toLowerCase();
    var view = query.isEmpty
        ? _table
        : _table
              .where((o) => o.customer.toLowerCase().contains(query))
              .toList();

    final Comparator<Order>? compare = switch (request.sortColumnId) {
      'id' => (a, b) => a.id.compareTo(b.id),
      'customer' => (a, b) => a.customer.compareTo(b.customer),
      'amount' => (a, b) => a.amountCents.compareTo(b.amountCents),
      _ => null,
    };
    if (compare != null && request.sortDirection != FitGridSortDirection.none) {
      final sign = request.sortDirection == FitGridSortDirection.descending
          ? -1
          : 1;
      view = List<Order>.of(view)..sort((a, b) => sign * compare(a, b));
    }

    _viewKey = key;
    return _view = view;
  }

  static const _companies = [
    'Acme Corp',
    'Globex',
    'Initech',
    'Umbrella Logistics',
    'Hooli',
    'Stark Industries',
    'Wayne Enterprises',
    'Soylent',
    'Tyrell',
    'Cyberdyne Systems',
    'Wonka Industries',
    'Vandelay Industries',
  ];
  static const _statuses = ['Pending', 'Shipped', 'Shipped', 'Refunded'];

  static List<Order> _generate(int count) {
    final random = Random(42);
    return List<Order>.generate(
      count,
      (i) => Order(
        id: 100000 + i,
        customer: _companies[random.nextInt(_companies.length)],
        status: _statuses[random.nextInt(_statuses.length)],
        amountCents: 500 + random.nextInt(2500000),
      ),
      growable: false,
    );
  }
}
