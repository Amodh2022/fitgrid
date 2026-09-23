import 'dart:async';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// A host that appends a batch of rows per load, from a completer the test
/// controls, so the in-between state can be looked at.
class _Feed extends StatefulWidget {
  const _Feed({required this.total, this.batch = 30, this.fail = false});

  final int total;
  final int batch;
  final bool fail;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  List<Employee> rows = const <Employee>[];
  int calls = 0;
  Completer<void>? pending;

  Future<void> load() {
    calls++;
    final completer = pending = Completer<void>();
    return completer.future.then((_) {
      if (widget.fail) throw StateError('offline');
      setState(() {
        final start = rows.length;
        rows = <Employee>[
          ...rows,
          for (var i = start; i < start + widget.batch && i < widget.total; i++)
            Employee('Person $i', 'Engineer', i),
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) => FitGrid<Employee>(
    rows: rows,
    columns: columns(),
    onLoadMore: load,
    hasMoreRows: rows.length < widget.total,
  );
}

void main() {
  _FeedState feed(WidgetTester tester) =>
      tester.state<_FeedState>(find.byType(_Feed));

  Future<void> finishLoad(WidgetTester tester) async {
    feed(tester).pending!.complete();
    await tester.pumpAndSettle();
  }

  testWidgets('an empty grid asks for its first batch, with skeletons', (
    tester,
  ) async {
    await tester.pumpWidget(host(const _Feed(total: 100)));
    await tester.pump();
    expect(feed(tester).calls, 1);
    // Skeleton rows while the first batch is out.
    expect(fitGridRowCount(), 3);
    expect(fitGridCellSpec(row: 0, column: 0).placeholder, isTrue);

    await finishLoad(tester);
    expect(fitGridCellText(row: 0, column: 0), 'Person 0');
    expect(fitGridCellSpec(row: 0, column: 0).placeholder, isFalse);
  });

  testWidgets('a batch too short to fill the screen loads the next', (
    tester,
  ) async {
    await tester.pumpWidget(host(const _Feed(total: 100, batch: 5)));
    await tester.pump();
    await finishLoad(tester);
    // Five rows fill nothing, so a second call follows without any scroll.
    expect(feed(tester).calls, 2);
  });

  testWidgets('scrolling near the end loads more, once at a time', (
    tester,
  ) async {
    await tester.pumpWidget(host(const _Feed(total: 200)));
    await tester.pump();
    await finishLoad(tester);
    final before = feed(tester).calls;

    await tester.drag(find.byType(FitGridSection), const Offset(0, -2000));
    await tester.pump();
    expect(feed(tester).calls, before + 1);
    // More scrolling while the load is out does not start another.
    await tester.drag(find.byType(FitGridSection), const Offset(0, -200));
    await tester.pump();
    expect(feed(tester).calls, before + 1);
    // The skeleton rows sit after the last real row.
    final loaded = feed(tester).rows.length;
    expect(fitGridRowCount(), loaded + 3);

    await finishLoad(tester);
    expect(fitGridRowCount(), greaterThan(loaded));
  });

  testWidgets('no calls once hasMoreRows is false', (tester) async {
    await tester.pumpWidget(host(const _Feed(total: 30)));
    await tester.pump();
    await finishLoad(tester);
    final calls = feed(tester).calls;
    await tester.drag(find.byType(FitGridSection), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(feed(tester).calls, calls);
    expect(fitGridRowCount(), 30);
  });

  testWidgets('a failure waits for the next scroll before retrying', (
    tester,
  ) async {
    await tester.pumpWidget(host(const _Feed(total: 100, fail: true)));
    await tester.pump();
    feed(tester).pending!.complete();
    await tester.pumpAndSettle();
    expect(feed(tester).calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(feed(tester).calls, 1);
  });

  testWidgets('rows a data source has not delivered paint as skeletons', (
    tester,
  ) async {
    final source = FitGridAsyncDataSource<Employee>(
      fetch: (_) => Completer<FitGridPageResult<Employee>>().future,
      initialRowCount: 50,
    );
    addTearDown(source.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(dataSource: source, columns: columns())),
    );
    await tester.pump();
    expect(fitGridCellSpec(row: 0, column: 0).placeholder, isTrue);
  });
}
