import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/column_filter.dart';

/// Every piece of text the grid shows or announces, in English.
///
/// Translate by extending it and overriding what you need; anything left alone
/// stays English, so a translation can be done a screen at a time rather than
/// all at once. This is the shape [WidgetsLocalizations] and Material's own
/// localizations take, for the same reason:
///
/// ```dart
/// class FitGridStringsDe extends FitGridStrings {
///   const FitGridStringsDe();
///
///   @override
///   String get sortAscending => 'Aufsteigend sortieren';
///
///   @override
///   String pageRange(int first, int last, int total) =>
///       '$first–$last von $total';
/// }
/// ```
///
/// Hand it to one grid with `FitGrid.strings`, to a subtree with
/// [FitGridLocalizations], or to the whole app, per locale, with
/// [FitGridStringsDelegate] in `localizationsDelegates`.
///
/// Column labels, cell text and footer labels are yours already and are not
/// here.
@immutable
class FitGridStrings {
  const FitGridStrings();

  // ---------------------------------------------------------- column menu

  String get sortAscending => 'Sort ascending';
  String get sortDescending => 'Sort descending';
  String get clearSort => 'Clear sort';
  String get filterMenuItem => 'Filter…';
  String get clearFilter => 'Clear filter';
  String get pinToStart => 'Pin to start';
  String get pinToEnd => 'Pin to end';
  String get unpin => 'Unpin';
  String get sizeToFit => 'Size to fit';
  String get sizeAllColumnsToFit => 'Size all columns to fit';
  String get hideColumn => 'Hide column';
  String get columnsMenuItem => 'Columns…';

  // --------------------------------------------------------------- header

  /// The screen-reader label of a header's menu button.
  String columnMenuLabel(String column) => '$column column menu';

  String get sortedAscending => 'sorted ascending';
  String get sortedDescending => 'sorted descending';
  String get notSorted => 'not sorted';

  /// Appended to a sorted header's hint when more than one column is sorted.
  String sortPriority(int priority) => ', sort priority $priority';

  // ----------------------------------------------------------------- rows

  /// What a screen reader hears for a group header.
  String groupHeader(String label, {required bool expanded}) =>
      '$label, ${expanded ? 'expanded' : 'collapsed'}';

  String get dragHandleHint => 'Drag to move, or press Alt and an arrow key';
  String get rowOrderFixed => 'Row order is fixed while sorted or grouped';
  String get detailsShown => 'Details shown';
  String get detailsHidden => 'Details hidden';
  String get selected => 'Selected';
  String get notSelected => 'Not selected';
  String get selectAll => 'Select all';
  String get clearSelection => 'Clear selection';
  String get loading => 'Loading';
  String get copy => 'Copy';
  String get noRows => 'No rows';
  String get couldNotLoadRows => 'Could not load rows';

  // ---------------------------------------------------------------- pager

  /// The pager's range readout, `1–25 of 1,000`. [total] is zero when there
  /// is nothing to page through.
  String pageRange(int first, int last, int total) =>
      total == 0 ? noRows : '$first–$last of $total';

  String get rowsPerPage => 'Rows';
  String get firstPage => 'First page';
  String get previousPage => 'Previous page';
  String get nextPage => 'Next page';
  String get lastPage => 'Last page';

  // ------------------------------------------------------- filter dialog

  String filterDialogTitle(String column) => 'Filter $column';

  /// The operator picker's label for [operator].
  String filterOperator(FitGridFilterOperator operator) => operator.label;

  String get condition => 'Condition';
  String get value => 'Value';
  String get from => 'From';
  String get to => 'To';
  String get dateHint => 'YYYY-MM-DD';
  String get pickDate => 'Pick a date';
  String get enterNumber => 'Enter a number';
  String get enterDate => 'Enter a date as YYYY-MM-DD';
  String get enterValue => 'Enter a value';
  String get searchValues => 'Search values';
  String get selectAllValues => '(Select all)';
  String get selectAllShownValues => '(Select all shown)';
  String get blankValue => '(Blank)';
  String get clear => 'Clear';
  String get cancel => 'Cancel';
  String get apply => 'Apply';

  // ----------------------------------------------------------- filter row

  /// The hint in an empty filter-row field.
  String get filterRowHint => 'Filter';

  /// The filter-row button of a checklist column with nothing unticked.
  String get filterRowAll => 'All';

  /// The filter-row button of a checklist column narrowed to [count] values.
  String filterRowSelected(int count) => '$count selected';

  /// The screen-reader label of a column's filter-row field.
  String filterRowLabel(String column) => 'Filter $column';

  // ------------------------------------------------------- column chooser

  String get columns => 'Columns';
  String get showAll => 'Show all';
  String get done => 'Done';
}

/// Hands [strings] to every grid below it.
///
/// `FitGrid.strings` wins over this for one grid; this wins over a
/// [FitGridStringsDelegate].
class FitGridLocalizations extends InheritedWidget {
  const FitGridLocalizations({
    required this.strings,
    required super.child,
    super.key,
  });

  final FitGridStrings strings;

  /// The nearest strings: a [FitGridLocalizations] in scope, then a
  /// [FitGridStringsDelegate]'s for the current locale, then English.
  static FitGridStrings of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<FitGridLocalizations>();
    return inherited?.strings ??
        Localizations.of<FitGridStrings>(context, FitGridStrings) ??
        const FitGridStrings();
  }

  @override
  bool updateShouldNotify(FitGridLocalizations oldWidget) =>
      strings != oldWidget.strings;
}

/// Picks the grid's strings by locale, alongside the app's other delegates:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: [
///     ...GlobalMaterialLocalizations.delegates,
///     FitGridStringsDelegate((locale) => switch (locale.languageCode) {
///       'de' => const FitGridStringsDe(),
///       _ => const FitGridStrings(),
///     }),
///   ],
/// )
/// ```
class FitGridStringsDelegate extends LocalizationsDelegate<FitGridStrings> {
  const FitGridStringsDelegate(this.resolve);

  /// The strings for a locale. Return [FitGridStrings] itself for English.
  final FitGridStrings Function(Locale locale) resolve;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FitGridStrings> load(Locale locale) =>
      SynchronousFuture<FitGridStrings>(resolve(locale));

  @override
  bool shouldReload(FitGridStringsDelegate old) => resolve != old.resolve;
}
