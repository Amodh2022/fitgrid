import 'package:flutter/material.dart';

import '../controller/fitgrid_controller.dart';
import '../model/fitgrid_column.dart';
import '../theme/fitgrid_strings.dart';

/// A button that opens a checklist of the grid's columns, for showing and
/// hiding them.
///
/// It talks to the controller and nothing else, so it can sit anywhere — in a
/// toolbar above the grid, in an app bar, in a settings sheet — rather than
/// being welded to the header. The grid's own column menu opens the same list.
///
/// The menu stays open while boxes are ticked, because choosing columns is
/// something people do several of at once, and a menu that closed after each
/// one would make them reopen it for every column.
class FitGridColumnChooser<T> extends StatelessWidget {
  const FitGridColumnChooser({
    required this.controller,
    this.icon = const Icon(Icons.view_column_outlined),
    this.tooltip,
    this.showAllLabel,
    super.key,
  });

  final FitGridController<T> controller;
  final Widget icon;

  /// Null uses [FitGridStrings.columns].
  final String? tooltip;

  /// Null uses [FitGridStrings.showAll].
  final String? showAllLabel;

  @override
  Widget build(BuildContext context) {
    final strings = FitGridLocalizations.of(context);
    return MenuAnchor(
      menuChildren: fitGridColumnChooserItems<T>(
        controller,
        showAllLabel: showAllLabel ?? strings.showAll,
      ),
      builder: (context, menu, _) => IconButton(
        icon: icon,
        tooltip: tooltip ?? strings.columns,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// The checklist itself, as menu items, for hosts that want it inside a menu
/// of their own. A null [showAllLabel] uses [FitGridStrings.showAll].
List<Widget> fitGridColumnChooserItems<T>(
  FitGridController<T> controller, {
  String? showAllLabel,
}) {
  return <Widget>[
    ListenableBuilder(
      listenable: controller.columns,
      builder: (context, _) {
        final all = <FitGridColumn<T>>[
          for (final column in controller.columns.columns)
            // Columns the grid synthesizes are controls, not data.
            if (!column.id.startsWith('__fitgrid')) column,
        ];
        final visibleCount = all.where((column) => column.visible).length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final column in all)
              CheckboxMenuButton(
                value: column.visible,
                closeOnActivate: false,
                // The last visible column cannot be hidden from here: a grid
                // with no columns has no header left to bring them back with.
                onChanged:
                    !column.hideable || (column.visible && visibleCount == 1)
                    ? null
                    : (value) => controller.columns.setVisible(
                        column.id,
                        value ?? false,
                      ),
                child: Text(column.label.isEmpty ? column.id : column.label),
              ),
            if (visibleCount < all.length) ...<Widget>[
              const Divider(height: 1),
              MenuItemButton(
                closeOnActivate: false,
                onPressed: controller.columns.showAll,
                child: Text(
                  showAllLabel ?? FitGridLocalizations.of(context).showAll,
                ),
              ),
            ],
          ],
        );
      },
    ),
  ];
}

/// Shows the column checklist in a dialog. What the column menu's "Columns…"
/// item opens, and usable on its own where a menu anchor is awkward — on a
/// phone, say, where a dialog is the more natural surface.
///
/// Null labels come from [strings], or from [FitGridLocalizations.of] the
/// [context] when that is null too.
Future<void> showFitGridColumnDialog<T>(
  BuildContext context,
  FitGridController<T> controller, {
  String? title,
  String? showAllLabel,
  String? closeLabel,
  FitGridStrings? strings,
}) {
  final resolved = strings ?? FitGridLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? resolved.columns),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fitGridColumnChooserItems<T>(
              controller,
              showAllLabel: showAllLabel ?? resolved.showAll,
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(closeLabel ?? resolved.done),
        ),
      ],
    ),
  );
}
