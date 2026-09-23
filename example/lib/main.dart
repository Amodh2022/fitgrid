import 'package:flutter/material.dart';

import 'screens/controller_patterns.dart';
import 'screens/formatting.dart';
import 'screens/grouping.dart';
import 'screens/lazy_loading.dart';
import 'screens/pagination.dart';
import 'screens/playground.dart';
import 'screens/sizing.dart';
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
