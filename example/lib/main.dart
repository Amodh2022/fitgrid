import 'package:flutter/material.dart';

import 'screens/charts.dart';
import 'screens/columns_and_filters.dart';
import 'screens/controller_patterns.dart';
import 'screens/detail_rows.dart';
import 'screens/formatting.dart';
import 'screens/grouping.dart';
import 'screens/infinite_scroll.dart';
import 'screens/lazy_loading.dart';
import 'screens/live_updates.dart';
import 'screens/pagination.dart';
import 'screens/pivot_export.dart';
import 'screens/playground.dart';
import 'screens/reorderable_rows.dart';
import 'screens/sizing.dart';
import 'screens/sort_million.dart';
import 'screens/spreadsheet.dart';
import 'screens/two_designs.dart';
import 'screens/widget_cells.dart';
import 'shared/demo_page.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'fitgrid examples',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF3B6EA5),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF3B6EA5),
        ),
        home: const GalleryPage(),
      ),
    );
  }
}

/// One entry in the gallery.
class Example {
  const Example({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

/// The examples, in the order a newcomer should read them.
final List<(String, List<Example>)> exampleSections = [
  (
    'Customising the look',
    [
      Example(
        title: 'Two designs, same data',
        subtitle:
            'An admin console and a trading terminal. Same rows and grid; '
            'only the theme, pager and cell callbacks differ.',
        icon: Icons.palette_outlined,
        builder: (_) => const TwoDesignsScreen(),
      ),
      Example(
        title: 'Pagination',
        subtitle:
            'The built-in pager, the same pager reworded, and a numbered '
            'pager written from scratch.',
        icon: Icons.last_page,
        builder: (_) => const PaginationScreen(),
      ),
      Example(
        title: 'Widget cells',
        subtitle:
            'Avatars, pills, switches and action buttons as real widgets in '
            'cells, built only for the rows on screen.',
        icon: Icons.widgets_outlined,
        builder: (_) => const WidgetCellsScreen(),
      ),
      Example(
        title: 'Conditional formatting',
        subtitle:
            'Row colours, cell styles and status glyphs, all painted rather '
            'than built.',
        icon: Icons.format_color_fill,
        builder: (_) => const FormattingScreen(),
      ),
    ],
  ),
  (
    'Performance patterns',
    [
      Example(
        title: 'Live updates',
        subtitle:
            '100,000 rows × 30 columns, two frozen, a filter on, and records '
            'replaced while you scroll, select and sort. Frame timings and '
            'memory measured live.',
        icon: Icons.bolt_outlined,
        builder: (_) => const LiveUpdatesScreen(),
      ),
      Example(
        title: 'Sorting a million rows',
        subtitle:
            'Sort 1,000,000 rows while an animation keeps running: the sort '
            'runs on a background isolate. Switch to the UI thread to see the '
            'freeze, and compare with Syncfusion and PlutoGrid.',
        icon: Icons.sort,
        builder: (_) => const SortMillionScreen(),
      ),
      Example(
        title: 'Column widths & row heights',
        subtitle:
            'Every sizing policy side by side, with the time each change costs '
            'measured live.',
        icon: Icons.straighten,
        builder: (_) => const SizingScreen(),
      ),
      Example(
        title: 'Lazy loading',
        subtitle:
            '250,000 rows behind a fake server with latency. Pages are fetched '
            'as they scroll in, and the cache stays bounded.',
        icon: Icons.cloud_download_outlined,
        builder: (_) => const LazyLoadingScreen(),
      ),
      Example(
        title: 'Controller patterns',
        subtitle:
            'Search, filter, sort and select through the controller. A counter '
            'proves the page does not rebuild.',
        icon: Icons.tune,
        builder: (_) => const ControllerPatternsScreen(),
      ),
    ],
  ),
  (
    'Working like a spreadsheet',
    [
      Example(
        title: 'Spreadsheet editing',
        subtitle:
            'Select a block of cells, copy, paste, drag the fill handle, and '
            'undo any of it. Shift+click headers to sort by several columns.',
        icon: Icons.grid_on,
        builder: (_) => const SpreadsheetScreen(),
      ),
      Example(
        title: 'Columns, filters & layouts',
        subtitle:
            'The column menu, typed filters and checklists, the column chooser, '
            'header bands, and the whole layout saved as JSON.',
        icon: Icons.filter_alt_outlined,
        builder: (_) => const ColumnsAndFiltersScreen(),
      ),
      Example(
        title: 'Pivot & export',
        subtitle:
            'Summarise 20,000 rows by department and year, then copy CSV or '
            'build an Excel workbook.',
        icon: Icons.pivot_table_chart_outlined,
        builder: (_) => const PivotExportScreen(),
      ),
    ],
  ),
  (
    'Rows that do more',
    [
      Example(
        title: 'Detail rows',
        subtitle:
            'Open a panel under any row — here, a nested grid of pay reviews '
            'that follows its row through a sort.',
        icon: Icons.unfold_more,
        builder: (_) => const DetailRowsScreen(),
      ),
      Example(
        title: 'Infinite scroll',
        subtitle:
            'A slow, occasionally failing feed that loads as you near the end, '
            'with skeleton rows while it works.',
        icon: Icons.all_inclusive,
        builder: (_) => const InfiniteScrollScreen(),
      ),
      Example(
        title: 'Reorderable rows',
        subtitle:
            'A backlog you rank by dragging rows by their handles, or with '
            'Alt+arrow keys.',
        icon: Icons.drag_indicator,
        builder: (_) => const ReorderableRowsScreen(),
      ),
      Example(
        title: 'Charts in cells',
        subtitle:
            'Data bars, progress tracks and sparklines over 5,000 rows, '
            'painted rather than built.',
        icon: Icons.show_chart,
        builder: (_) => const ChartsScreen(),
      ),
    ],
  ),
  (
    'Structure',
    [
      Example(
        title: 'Grouping & tree rows',
        subtitle:
            'One or two levels of grouping over a flat list, and an org chart '
            'as tree rows.',
        icon: Icons.account_tree_outlined,
        builder: (_) => const GroupingScreen(),
      ),
      Example(
        title: 'Playground',
        subtitle:
            'Every switch at once: 100k rows, editing, freezing, RTL, export, '
            'density.',
        icon: Icons.science_outlined,
        builder: (_) => const PlaygroundScreen(),
      ),
    ],
  ),
];

/// The front page: what the package is, the numbers behind it, and every
/// example as a card, searchable.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String _query = '';

  List<(String, List<Example>)> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return exampleSections;
    return [
      for (final (heading, examples) in exampleSections)
        if (examples.where((e) => _matches(e, query)).toList() case final hits
            when hits.isNotEmpty)
          (heading, hits),
    ];
  }

  static bool _matches(Example example, String query) =>
      example.title.toLowerCase().contains(query) ||
      example.subtitle.toLowerCase().contains(query);

  void _open(Example example) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: example.builder));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _visible;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('fitgrid'),
            actions: const [ThemeModeButton(), SizedBox(width: 8)],
          ),
          SliverToBoxAdapter(
            child: _Constrained(
              child: _Hero(
                onLive: () => _open(
                  exampleSections
                      .expand((s) => s.$2)
                      .firstWhere((e) => e.title == 'Live updates'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                child: SearchBar(
                  hintText: 'Search examples',
                  constraints: const BoxConstraints(minHeight: 56),
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    theme.colorScheme.surfaceContainerHigh,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
          ),
          if (sections.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Text(
                  'No example matches "$_query".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          for (final (heading, examples) in sections)
            SliverToBoxAdapter(
              child: _Constrained(
                child: _Section(
                  heading: heading,
                  examples: examples,
                  onOpen: _open,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Centres the content at a readable width, with the page gutter.
class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLive});

  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? scheme.onPrimaryContainer : Colors.white;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [scheme.primaryContainer, scheme.tertiaryContainer]
              : [
                  scheme.primary,
                  Color.lerp(scheme.primary, scheme.tertiary, .7)!,
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'Flutter data grid · examples',
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Measures your content.\nPaints your cells.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Each example shows one idea. Open "How this works" at the top '
              'of a page for what to copy and what to avoid.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: foreground.withValues(alpha: .85),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in const [
                ('1M', 'rows scrolled'),
                ('30', 'columns, live updates'),
                ('0', 'dependencies'),
              ])
                _Metric(value: value, label: label, color: foreground),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: foreground,
              foregroundColor: dark ? scheme.primaryContainer : scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onPressed: onLive,
            icon: const Icon(Icons.bolt),
            label: const Text('Run the live stress test'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .25)),
        color: color.withValues(alpha: .08),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: text.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: label,
              style: text.bodyMedium?.copyWith(
                color: color.withValues(alpha: .85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.heading,
    required this.examples,
    required this.onOpen,
  });

  final String heading;
  final List<Example> examples;
  final ValueChanged<Example> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  heading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${examples.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return Column(
              children: [
                for (var i = 0; i < examples.length; i += perRow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = i; j < i + perRow; j++) ...[
                            if (j > i) const SizedBox(width: 12),
                            Expanded(
                              child: j < examples.length
                                  ? _ExampleCard(
                                      example: examples[j],
                                      onTap: () => onOpen(examples[j]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ExampleCard extends StatefulWidget {
  const _ExampleCard({required this.example, required this.onTap});

  final Example example;
  final VoidCallback onTap;

  @override
  State<_ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<_ExampleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: _hovered
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? scheme.primary.withValues(alpha: .5)
                : scheme.outlineVariant,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.example.icon,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const Spacer(),
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 160),
                        offset: Offset(_hovered ? .2 : 0, 0),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: _hovered
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.example.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.example.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
