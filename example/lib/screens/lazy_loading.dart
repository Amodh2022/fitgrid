import 'dart:async';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/order.dart';
import '../shared/demo_page.dart';

/// Rows the app never holds: a quarter of a million orders behind a fake
/// server with real latency, fetched a page at a time as they scroll in.
class LazyLoadingScreen extends StatefulWidget {
  const LazyLoadingScreen({super.key});

  @override
  State<LazyLoadingScreen> createState() => _LazyLoadingScreenState();
}

class _LazyLoadingScreenState extends State<LazyLoadingScreen> {
  final FakeOrderServer _server = FakeOrderServer(rowCount: 250000);
  late FitGridAsyncDataSource<Order> _source = _createSource();
  bool _reportTotal = true;
  int _fetches = 0;
  Timer? _searchDebounce;

  static final List<FitGridColumn<Order>> _columns = [
    FitGridColumn<Order>(
      id: 'id',
      label: 'Order',
      value: (o) => '#${o.id}',
      width: const FitGridColumnWidth.fixed(96),
      // Sortable here means "the server can sort by it". Only offer the
      // columns your backend has an index for.
      sortable: true,
    ),
    FitGridColumn<Order>(
      id: 'customer',
      label: 'Customer',
      value: (o) => o.customer,
      sortable: true,
    ),
    FitGridColumn<Order>(
      id: 'status',
      label: 'Status',
      value: (o) => o.status,
      width: const FitGridColumnWidth.fitHeader(min: 96),
      icon: (o, _) => o.status == 'Shipped'
          ? Icons.local_shipping_outlined
          : o.status == 'Refunded'
          ? Icons.undo
          : Icons.schedule,
    ),
    FitGridColumn<Order>(
      id: 'amount',
      label: 'Amount',
      value: (o) => o.amountText,
      alignment: FitGridAlignment.end,
      sortable: true,
    ),
  ];

  FitGridAsyncDataSource<Order> _createSource() {
    return FitGridAsyncDataSource<Order>(
      pageSize: 100,
      // 24 pages × 100 rows: at most 2,400 orders in memory, however far the
      // user scrolls.
      maxCachedPages: 24,
      fetch: (request) async {
        // A plain counter, not setState: the grid asks for pages while it
        // builds. The readout below repaints when the page lands.
        _fetches++;
        final page = await _server.fetch(request);
        return FitGridPageResult<Order>(
          rows: page.rows,
          // Leave the total out and the scrollbar grows as pages arrive.
          totalCount: _reportTotal ? page.total : null,
        );
      },
    );
  }

  void _setReportTotal(bool value) {
    final old = _source;
    setState(() {
      _reportTotal = value;
      _fetches = 0;
      _source = _createSource();
    });
    // Disposed after the grid has let go of it.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _search(String query) {
    // One request per pause in typing, not one per keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _source.search(query),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Lazy loading (async data source)',
      notes: const [
        DemoNote(
          'The server holds 250,000 orders. The grid asks only for the pages on '
          'screen and keeps at most 24 of them. Scroll fast and watch the '
          'cached-page count stay flat while the fetch count climbs.',
        ),
        DemoNote.recommended(
          'Sort and search on the server. The request carries both, and the '
          'cache is dropped when either changes. Sorting one loaded window '
          'would order page two differently from page three.',
          code:
              'final source = FitGridAsyncDataSource<Order>(\n'
              '  pageSize: 100,\n'
              '  maxCachedPages: 24,\n'
              '  fetch: (r) async {\n'
              '    final page = await api.orders(offset: r.offset, limit: r.limit,\n'
              '        sort: r.sortColumnId, dir: r.sortDirection, q: r.query);\n'
              '    return FitGridPageResult(rows: page.items, totalCount: page.total);\n'
              '  },\n'
              ');\n'
              'FitGrid<Order>(dataSource: source, columns: columns)',
        ),
        DemoNote.recommended(
          'Debounce the search box before calling source.search(query). Each '
          'new query is a new result set and a fresh fetch.',
        ),
        DemoNote.recommended(
          'Return totalCount when the backend knows it, so the scrollbar is '
          'right at once. Without it the grid grows as pages come back full. '
          'Toggle it here to compare.',
        ),
        DemoNote.avoid(
          'Loading everything into a List and passing rows:. That is fine up to '
          'a few hundred thousand local rows. It is not fine for a remote '
          'table, where the first frame would wait on the whole download.',
        ),
        DemoNote.avoid(
          'Combining dataSource with paginated: true. A data source already '
          'pages itself, and the grid asserts against it.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search customers (server)',
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('0 ms')),
              ButtonSegment(value: 150, label: Text('150 ms')),
              ButtonSegment(value: 800, label: Text('800 ms')),
            ],
            selected: {_server.latency.inMilliseconds},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(
              () => _server.latency = Duration(milliseconds: s.first),
            ),
          ),
          FilterChip(
            label: const Text('Server reports total'),
            selected: _reportTotal,
            onSelected: _setReportTotal,
          ),
          OutlinedButton.icon(
            onPressed: _source.refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          // Only this readout listens to the source; the page itself does not
          // rebuild when a page arrives.
          ListenableBuilder(
            listenable: _source,
            builder: (context, _) => Wrap(
              spacing: 8,
              children: [
                StatChip(label: 'Rows known', value: '${_source.rowCount}'),
                StatChip(
                  label: 'Pages cached',
                  value: '${_source.cachedPageCount} / 24',
                ),
                StatChip(label: 'Fetches', value: '$_fetches'),
                if (_source.isLoading)
                  const StatChip(label: 'Status', value: 'loading…'),
              ],
            ),
          ),
        ],
      ),
      child: FitGrid<Order>(
        dataSource: _source,
        columns: _columns,
        rowHeight: const FitGridRowHeight.fixed(40),
        loadingState: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
