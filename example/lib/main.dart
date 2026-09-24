import 'package:flutter/material.dart';

import 'screens/charts.dart';
import 'screens/columns_and_filters.dart';
import 'screens/controller_patterns.dart';
import 'screens/detail_rows.dart';
import 'screens/formatting.dart';
import 'screens/grouping.dart';
import 'screens/infinite_scroll.dart';
import 'screens/lazy_loading.dart';
import 'screens/pagination.dart';
import 'screens/pivot_export.dart';
import 'screens/playground.dart';
import 'screens/reorderable_rows.dart';
import 'screens/sizing.dart';
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

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('fitgrid examples'),
        actions: const [ThemeModeButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Each example shows one idea. Open "How this works" at the '
                'top of a page for what to copy and what to avoid.',
                style: theme.textTheme.bodyLarge,
              ),
              for (final (heading, examples) in exampleSections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    heading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final example in examples)
                  Card.outlined(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(example.icon),
                      title: Text(example.title),
                      subtitle: Text(example.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: example.builder)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
