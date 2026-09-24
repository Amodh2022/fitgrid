import 'dart:math';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../shared/demo_page.dart';

class Ticker {
  const Ticker({
    required this.symbol,
    required this.closes,
    required this.low52,
    required this.high52,
  });

  final String symbol;

  /// Thirty days of closing prices, oldest first.
  final List<double> closes;
  final double low52;
  final double high52;

  double get price => closes.last;
  double get changePct => (closes.last / closes[closes.length - 2] - 1) * 100;

  /// Where today's price sits in its 52-week range, 0 to 1.
  double get rangePosition => (price - low52) / (high52 - low52);
}

/// Deterministic random walks, so the page looks the same every time.
List<Ticker> generateTickers(int count) {
  final random = Random(7);
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  return <Ticker>[
    for (var i = 0; i < count; i++)
      () {
        var price = 20 + random.nextDouble() * 280;
        final closes = <double>[
          for (var d = 0; d < 30; d++)
            price = max(1, price * (1 + (random.nextDouble() - 0.49) * 0.06)),
        ];
        final low = closes.reduce(min) * (0.7 + random.nextDouble() * 0.2);
        final high = closes.reduce(max) * (1.05 + random.nextDouble() * 0.3);
        return Ticker(
          symbol: String.fromCharCodes([
            for (var k = 0; k < 3 + i % 2; k++)
              letters.codeUnitAt(random.nextInt(26)),
          ]),
          closes: closes,
          low52: low,
          high52: high,
        );
      }(),
  ];
}

/// Data bars, progress tracks and sparklines, painted into cells.
class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  static final List<Ticker> _rows = generateTickers(5000);

  static final List<FitGridColumn<Ticker>> _columns = [
    FitGridColumn<Ticker>(
      id: 'symbol',
      label: 'Symbol',
      value: (t) => t.symbol,
      sortable: true,
      freeze: FitGridFreeze.start,
    ),
    FitGridColumn<Ticker>(
      id: 'price',
      label: 'Price',
      value: (t) => t.price.toStringAsFixed(2),
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.price.compareTo(b.price),
    ),
    FitGridColumn<Ticker>(
      id: 'change',
      label: 'Change',
      value: (t) =>
          '${t.changePct >= 0 ? '+' : ''}${t.changePct.toStringAsFixed(2)}%',
      alignment: FitGridAlignment.end,
      width: const FitGridColumnWidth.fixed(130),
      sortable: true,
      comparator: (a, b) => a.changePct.compareTo(b.changePct),
      // From the zero line: gains one way, losses the other, in red.
      visual: FitGridCellVisual<Ticker>.bar((t) => t.changePct),
    ),
    FitGridColumn<Ticker>(
      id: 'range',
      label: '52-week range',
      value: (t) => '${(t.rangePosition * 100).round()}%',
      width: const FitGridColumnWidth.fixed(150),
      sortable: true,
      comparator: (a, b) => a.rangePosition.compareTo(b.rangePosition),
      visual: FitGridCellVisual<Ticker>.progress((t) => t.rangePosition),
    ),
    FitGridColumn<Ticker>(
      id: 'trend',
      label: '30 days',
      // Not painted — the chart takes the cell — but still what the cell
      // copies as, exports as, and what a screen reader says.
      value: (t) => t.closes.map((c) => c.toStringAsFixed(2)).join(', '),
      width: const FitGridColumnWidth.fixed(160),
      visual: FitGridCellVisual<Ticker>.sparkline(
        (t) => t.closes,
        filled: true,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Charts in cells',
      notes: const [
        DemoNote(
          '5,000 rows, each with a data bar, a progress track and a 30-point '
          'sparkline — and not one widget per cell. The charts are drawn by '
          'the same paint pass as the text, so a column of them costs what a '
          'column of words does. Scroll fast and watch.',
        ),
        DemoNote.recommended(
          'Keep value meaningful. It is still what the cell sorts, copies, '
          'exports and announces as, even when a sparkline hides it.',
          code:
              'FitGridColumn<Ticker>(\n'
              '  id: "trend", label: "30 days",\n'
              '  value: (t) => t.closes.join(", "),\n'
              '  width: const FitGridColumnWidth.fixed(160),\n'
              '  visual: FitGridCellVisual.sparkline((t) => t.closes, filled: true),\n'
              ')',
        ),
        DemoNote(
          'A bar with no min or max takes its range from the column\'s data, '
          'always including zero. Give min and max for a fixed scale.',
        ),
        DemoNote.avoid(
          'Auto-width on a chart column. A chart has no text width to '
          'measure; give it a fixed width.',
        ),
      ],
      child: FitGrid<Ticker>(
        rows: _rows,
        columns: _columns,
        rowHeight: const FitGridRowHeight.fixed(40),
      ),
    );
  }
}
