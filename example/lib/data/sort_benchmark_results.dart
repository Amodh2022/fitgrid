// Measured by benchmark/compare/ (tool/run.sh) and copied here as data: the
// other grids are not dependencies of this app. Re-run the benchmark and
// update these when any of the packages changes.

/// Row count the table below was measured at.
const int sortBenchmarkRows = 1000000;

/// Column headings, fitgrid first.
const List<String> sortBenchmarkGrids = <String>[
  'fitgrid 0.1.4',
  'Syncfusion 34.2.9',
  'TrinaGrid 2.3.0',
  'PlutoGrid 8.1.0',
];

/// Median of 3 runs. "UI blocked" is the longest the UI thread went without
/// drawing a frame during the sort; over 16 ms is a dropped frame at 60 Hz.
/// From benchmark/results/2026-09-28-compare-linux-i7-14700.md.
const List<(String, List<String>)> sortBenchmarkRowsTable =
    <(String, List<String>)>[
      (
        'Sort text: UI blocked',
        <String>['29 ms', '3,076 ms', '2,935 ms', '2,811 ms'],
      ),
      (
        'Sort number: UI blocked',
        <String>['11 ms', '2,859 ms', '2,102 ms', '14,727 ms'],
      ),
      (
        'Sort date: UI blocked',
        <String>['11 ms', '2,856 ms', '9,862 ms', '8,466 ms'],
      ),
      (
        'Sort number: sorted in',
        <String>['315 ms', '2,860 ms', '2,197 ms', '14,728 ms'],
      ),
      (
        'Scroll one screen',
        <String>['6.2 ms', '14.2 ms', '36.4 ms', '36.8 ms'],
      ),
      (
        'Mount + first frame',
        <String>['220 ms', '105 ms', '10,521 ms', '11,414 ms'],
      ),
      (
        'Memory for the row model',
        <String>['8 MB', '342 MB', '1,451 MB', '950 MB'],
      ),
    ];

const String sortBenchmarkFootnote =
    'Same 1,000,000 rows, viewport and harness for every grid, each set up '
    'with typed values and its own column types as its docs show. Debug-mode '
    '`flutter test` on an Intel i7-14700, no GPU: absolute times are higher '
    'than a release build on a device; the comparison between grids is the '
    'point. Source: benchmark/compare in the fitgrid repository.';
