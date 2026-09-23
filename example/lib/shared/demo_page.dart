import 'package:flutter/material.dart';

/// The app-wide brightness, so every demo page can offer the same toggle
/// without threading a callback through each route.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

/// How a [DemoNote] should read: a plain explanation, the pattern to copy, or
/// the pattern to avoid.
enum DemoNoteKind { info, recommended, avoid }

/// One point in a demo's "How this works" panel, optionally with code.
class DemoNote {
  const DemoNote(this.text, {this.code, this.kind = DemoNoteKind.info});

  const DemoNote.recommended(this.text, {this.code})
    : kind = DemoNoteKind.recommended;

  const DemoNote.avoid(this.text, {this.code}) : kind = DemoNoteKind.avoid;

  final String text;
  final String? code;
  final DemoNoteKind kind;
}

/// The frame every example shares: a title, a collapsible panel explaining
/// what the example demonstrates and why it is fast, a row of controls, and
/// the grid filling the rest.
class DemoPage extends StatelessWidget {
  const DemoPage({
    required this.title,
    required this.notes,
    required this.child,
    this.controls,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final List<DemoNote> notes;
  final Widget? controls;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [...actions, const ThemeModeButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotesPanel(notes: notes),
          if (controls != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: controls,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flips the app between light and dark.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => IconButton(
        tooltip: 'Toggle brightness',
        icon: Icon(
          mode == ThemeMode.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
        onPressed: () => appThemeMode.value = mode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark,
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.notes});

  final List<DemoNote> notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(Icons.lightbulb_outline, color: scheme.primary),
          title: const Text('How this works'),
          childrenPadding: EdgeInsets.zero,
          children: [
            ConstrainedBox(
              // The grid is the point of every page; the notes must never
              // push it off a small screen.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.32,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [for (final note in notes) _NoteTile(note: note)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final DemoNote note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, prefix) = switch (note.kind) {
      DemoNoteKind.info => (Icons.info_outline, scheme.onSurfaceVariant, ''),
      DemoNoteKind.recommended => (
        Icons.check_circle_outline,
        Colors.green.shade600,
        'Do: ',
      ),
      DemoNoteKind.avoid => (
        Icons.do_not_disturb_on_outlined,
        scheme.error,
        'Avoid: ',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (prefix.isNotEmpty)
                        TextSpan(
                          text: prefix,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      TextSpan(text: note.text),
                    ],
                  ),
                ),
                if (note.code != null) ...[
                  const SizedBox(height: 6),
                  CodeBlock(note.code!, accent: color),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A monospace snippet that scrolls sideways rather than wrapping, because
/// wrapped code stops looking like code.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {this.accent, super.key});

  final String code;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accent ?? scheme.outline, width: 3),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// A small live readout — rebuilds, fetches, timings — that a demo shows next
/// to its controls.
class StatChip extends StatelessWidget {
  const StatChip({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
