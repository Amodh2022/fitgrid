import '../model/enums.dart';
import '../model/fitgrid_column.dart';

/// The visible columns in the order they are laid out, with pinned columns
/// pulled to the edges.
///
/// Freezing reorders: a column pinned to the leading edge is drawn there
/// whatever position it was declared in, because that is what pinning means and
/// because the alternative — pinning only the columns that already happen to be
/// at an edge — is a rule nobody can remember. Within each band the declared
/// order is preserved, so a stable partition rather than a sort.
///
/// Every consumer goes through this: the sizer, the render layer, the header,
/// the selection and the keyboard all index into the same list, and a column
/// order computed twice is a column order that will eventually disagree with
/// itself.
List<FitGridColumn<T>> fitGridVisibleColumns<T>(
  List<FitGridColumn<T>> columns,
) {
  var pinned = false;
  final none = <FitGridColumn<T>>[];
  for (final column in columns) {
    if (!column.visible) continue;
    if (column.freeze != FitGridFreeze.none) pinned = true;
    none.add(column);
  }
  // The overwhelmingly common case has nothing pinned, and it should not pay
  // for two extra list allocations to discover that.
  if (!pinned) return none;

  final start = <FitGridColumn<T>>[];
  final middle = <FitGridColumn<T>>[];
  final end = <FitGridColumn<T>>[];
  for (final column in none) {
    switch (column.freeze) {
      case FitGridFreeze.start:
        start.add(column);
      case FitGridFreeze.none:
        middle.add(column);
      case FitGridFreeze.end:
        end.add(column);
    }
  }
  return <FitGridColumn<T>>[...start, ...middle, ...end];
}
