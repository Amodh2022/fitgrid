// The rows every grid is given: the same generator and seed as
// ../../workload_benchmark.dart, so the numbers line up with it.

import 'dart:math' as math;

class Order {
  const Order(
    this.id,
    this.customer,
    this.region,
    this.status,
    this.amount,
    this.placed,
    this.note,
  );

  final int id;
  final String customer;
  final String region;
  final String status;
  final int amount;
  final DateTime placed;
  final String note;
}

const regions = <String>['North', 'South', 'East', 'West', 'Central'];
const statuses = <String>['Open', 'Shipped', 'Delivered', 'Returned'];
const _words = <String>[
  'priority',
  'fragile',
  'gift',
  'wrap',
  'call',
  'before',
  'delivery',
  'leave',
  'at',
  'door',
  'backorder',
  'partial',
  'refund',
  'review',
];

List<Order> makeOrders(int count) {
  final random = math.Random(42);
  final start = DateTime(2020);
  return List<Order>.generate(count, (i) {
    final words = random.nextInt(12);
    return Order(
      i,
      'Customer ${random.nextInt(200000)}',
      regions[random.nextInt(regions.length)],
      statuses[random.nextInt(statuses.length)],
      random.nextInt(500000),
      start.add(Duration(days: random.nextInt(2000))),
      <String>[
        for (var w = 0; w < words; w++) _words[random.nextInt(_words.length)],
      ].join(' '),
    );
  }, growable: false);
}

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String formatAmount(int cents) => (cents / 100).toStringAsFixed(2);

/// The three sorts every grid is asked for, by the column's field name.
const sorts = <(String label, String field, bool ascending)>[
  ('text (customer) asc', 'customer', true),
  ('number (amount) asc', 'amount', true),
  ('date (placed) desc', 'placed', false),
];
