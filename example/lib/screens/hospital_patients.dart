import 'dart:math';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/demo_page.dart';

/// The colours of a hospital app's design system, light and dark — the
/// tokens its own table reads, reproduced here value for value.
class HospitalPalette {
  const HospitalPalette({
    required this.brightness,
    required this.shell,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.tableHeaderBg,
    required this.tableWash,
    required this.cardBg,
    required this.subtleBorder,
    required this.border,
    required this.columnDivider,
    required this.cellDivider,
    required this.rowDivider,
    required this.paginationInactiveBg,
    required this.menuBg,
    required this.ink70,
    required this.grey400,
  });

  static const Color brandBlue = Color(0xFF4B60AB);
  static const Color brandTeal = Color(0xFF199894);
  static const Color pagerArrowBorder = Color(0xFFDAD5D5);
  static const LinearGradient brand = LinearGradient(
    colors: [brandBlue, brandTeal],
  );

  static const HospitalPalette light = HospitalPalette(
    brightness: Brightness.light,
    shell: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xDD000000),
    textHint: Color(0x73000000),
    tableHeaderBg: Color(0x26000000),
    tableWash: Color(0xFFF5F5F5),
    cardBg: Color(0xFFF5F5F5),
    subtleBorder: Color(0xFFE5E7EB),
    border: Color(0xFFA4A3A3),
    columnDivider: Color(0xFF000000),
    cellDivider: Color(0xB3000000),
    rowDivider: Color(0x33000000),
    paginationInactiveBg: Color(0xFFE8E8E8),
    menuBg: Color(0xFFFFFFFF),
    ink70: Color(0xB3000000),
    grey400: Color(0xFF9E9E9E),
  );

  static const HospitalPalette dark = HospitalPalette(
    brightness: Brightness.dark,
    shell: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xCCFFFFFF),
    textHint: Color(0x73FFFFFF),
    tableHeaderBg: Color(0x33E6E9EC),
    tableWash: Color(0x0DFFFFFF),
    cardBg: Color(0x1AFAF9FF),
    subtleBorder: Color(0x1AFFFFFF),
    border: Color(0x1AFFFFFF),
    columnDivider: Color(0xFFFFFFFF),
    cellDivider: Color(0xB3FFFFFF),
    rowDivider: Color(0x33FFFFFF),
    paginationInactiveBg: Color(0xFF1A1A1A),
    menuBg: Color(0xFF1A3535),
    ink70: Color(0xB3FFFFFF),
    grey400: Color(0xFFBDBDBD),
  );

  final Brightness brightness;
  final Color shell;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color tableHeaderBg;
  final Color tableWash;
  final Color cardBg;
  final Color subtleBorder;
  final Color border;
  final Color columnDivider;
  final Color cellDivider;
  final Color rowDivider;
  final Color paginationInactiveBg;
  final Color menuBg;
  final Color ink70;
  final Color grey400;

  static HospitalPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The app's Material theme: Poppins, brand teal, its shell colour.
  ThemeData materialTheme(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: shell,
    colorScheme: base.colorScheme.copyWith(
      primary: brandTeal,
      secondary: brandBlue,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Poppins',
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
  );

  /// Everything the grid needs to look like the app's own table.
  FitGridThemeData gridTheme(ThemeData material) {
    const poppins = 'Poppins';
    return FitGridThemeData.fromTheme(material).copyWith(
      headerBackground: tableHeaderBg,
      headerForeground: textPrimary,
      headerTextStyle: TextStyle(
        fontFamily: poppins,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      cellTextStyle: TextStyle(
        fontFamily: poppins,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      rowBackground: tableWash,
      alternateRowBackground: tableWash,
      hoverBackground: const Color(0x00000000),
      selectedBackground: brandTeal.withValues(alpha: 0.12),
      focusOutline: brandTeal,
      border: subtleBorder,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      rowDivider: rowDivider,
      columnDivider: cellDivider,
      // The three that make it this table rather than a table: dashed rules
      // between rows, short ticks between cells, short header dividers.
      rowDividerDash: const [3, 2],
      columnDividerExtent: 12,
      headerDividerExtent: 34,
      sortAscendingIcon: Icons.arrow_drop_up,
      sortDescendingIcon: Icons.arrow_drop_down,
      sortUnsortedIcon: Icons.arrow_drop_up,
      sortIconColor: textPrimary,
      sortIconSize: 20,
      headerHeight: 50,
      rowHeight: 48,
      headerPadding: const EdgeInsets.symmetric(horizontal: 16),
      // The app's cell margin and padding together.
      cellPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}

class Patient {
  const Patient({
    required this.id,
    required this.first,
    required this.last,
    required this.male,
    required this.dob,
    required this.mobile,
    required this.email,
    required this.city,
  });

  final int id;
  final String first;
  final String last;
  final bool male;
  final DateTime dob;
  final String mobile;
  final String? email;
  final String? city;

  int get age {
    final now = DateTime(2026, 9, 24);
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  String get displayName => '$first $last (${male ? 'M' : 'F'}/${age}y)';

  String get dobText =>
      '${dob.day.toString().padLeft(2, '0')}/'
      '${dob.month.toString().padLeft(2, '0')}/${dob.year}';
}

List<Patient> generatePatients(int count) {
  const firsts = [
    'Aarav',
    'Diya',
    'Rohan',
    'Ananya',
    'Vikram',
    'Sneha',
    'Arjun',
    'Kavya',
    'Ishaan',
    'Meera',
    'Kabir',
    'Priya',
    'Aditya',
    'Lakshmi',
    'Nikhil',
    'Zara',
  ];
  const lasts = [
    'Sharma',
    'Iyer',
    'Reddy',
    'Nair',
    'Patel',
    'Gupta',
    'Rao',
    'Menon',
    'Kulkarni',
    'Das',
    'Joshi',
    'Pillai',
  ];
  const cities = [
    'Bengaluru',
    'Chennai',
    'Hyderabad',
    'Mumbai',
    'Pune',
    'Kochi',
    null,
  ];
  final random = Random(4242);
  return <Patient>[
    for (var i = 0; i < count; i++)
      () {
        final first = firsts[random.nextInt(firsts.length)];
        final last = lasts[random.nextInt(lasts.length)];
        return Patient(
          id: 1 + i,
          first: first,
          last: last,
          male: random.nextBool(),
          dob: DateTime(
            1945 + random.nextInt(75),
            1 + random.nextInt(12),
            1 + random.nextInt(28),
          ),
          mobile: '+91 9${random.nextInt(900000000) + 100000000}',
          email: random.nextInt(6) == 0
              ? null
              : '${first.toLowerCase()}.${last.toLowerCase()}@example.com',
          city: cities[random.nextInt(cities.length)],
        );
      }(),
  ];
}

/// A hospital app's patient list, rebuilt with fitgrid: the same colours,
/// type, header, dashed rules, cell ticks, action button and pager.
class HospitalPatientsScreen extends StatefulWidget {
  const HospitalPatientsScreen({super.key});

  @override
  State<HospitalPatientsScreen> createState() => _HospitalPatientsScreenState();
}

class _HospitalPatientsScreenState extends State<HospitalPatientsScreen> {
  static final List<Patient> _patients = generatePatients(1200);

  late final FitGridController<Patient> _controller =
      FitGridController<Patient>(
        rows: _patients,
        columns: _columns(),
        selectionMode: FitGridSelectionMode.none,
      );

  /// null for both genders.
  bool? _male;

  /// Each row's position in the current view, rebuilt when the view changes —
  /// a lookup per cell rather than a scan per cell.
  Map<Patient, int> _positions = const {};
  List<Patient>? _positionsOf;

  int _serial(Patient p) {
    final view = _controller.data.view;
    if (!identical(view, _positionsOf)) {
      _positionsOf = view;
      _positions = <Patient, int>{
        for (var i = 0; i < view.length; i++) view[i]: i + 1,
      };
    }
    return _positions[p] ?? 0;
  }

  List<FitGridColumn<Patient>> _columns() {
    // The app's auto-fit, clamped the way its own column sizer clamps.
    const fit = FitGridColumnWidth.auto(min: 130, max: 360);
    FitGridColumn<Patient> text(
      String id,
      String label,
      String Function(Patient) value, {
      bool sortable = true,
      bool searchable = true,
      Comparator<Patient>? comparator,
    }) => FitGridColumn<Patient>(
      id: id,
      label: label,
      value: value,
      width: fit,
      alignment: FitGridAlignment.center,
      headerAlignment: FitGridAlignment.center,
      sortable: sortable,
      searchable: searchable,
      comparator: comparator,
    );

    return [
      // The serial number is the row's place on screen, so it renumbers with
      // the sort and the page. Not searchable: the search is what decides the
      // view, so a column read from the view cannot take part in it.
      text(
        'sno',
        'S.No',
        (p) => '${_serial(p)}',
        sortable: false,
        searchable: false,
      ),
      text('name', 'Patient Name', (p) => p.displayName),
      text('mobile', 'Mobile Number', (p) => p.mobile),
      text(
        'dob',
        'DOB',
        (p) => p.dobText,
        comparator: (a, b) => a.dob.compareTo(b.dob),
      ),
      text('email', 'Email ID', (p) => p.email ?? '-'),
      text('city', 'City', (p) => p.city ?? 'N/A'),
      FitGridColumn<Patient>(
        id: 'actions',
        label: 'Actions',
        value: (p) => 'Open ${p.displayName}',
        width: const FitGridColumnWidth.fixed(120),
        alignment: FitGridAlignment.start,
        sortable: false,
        searchable: false,
        cellBuilder: (context, p, _) => _OpenButton(
          onTap: () => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Open patient #${p.id}'))),
        ),
      ),
    ];
  }

  void _setGender(bool? male) {
    setState(() => _male = male);
    // Keyed to the name column, which carries the gender in its text.
    _controller.filter.setColumnFilter(
      'name',
      male == null ? null : (p) => p.male == male,
    );
  }

  Future<void> _bulkExport() async {
    await Clipboard.setData(
      ClipboardData(text: fitGridToCsv(_controller.export())),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('CSV of every row copied')));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HospitalPalette.of(context);
    final material = palette.materialTheme(Theme.of(context));

    return Theme(
      data: material,
      child: DemoPage(
        title: 'Hospital patient list',
        notes: const [
          DemoNote(
            'A hospital app\'s own patient table, rebuilt with fitgrid. Every '
            'colour is the app\'s token for light or dark — flip the brightness '
            'to compare — the type is its Poppins, and the pager sits inside '
            'the table\'s border as the app\'s does.',
          ),
          DemoNote.recommended(
            'The whole look is a theme. The dashed rules and short dividers are '
            'three theme options; nothing is drawn by a custom widget per cell.',
            code:
                'FitGridThemeData.fromTheme(theme).copyWith(\n'
                '  headerBackground: tableHeaderBg,\n'
                '  rowBackground: tableWash,\n'
                '  rowDividerDash: const [3, 2],   // dashed row rules\n'
                '  columnDividerExtent: 12,       // ticks between cells\n'
                '  headerDividerExtent: 34,       // short header dividers\n'
                '  borderRadius: BorderRadius.circular(6),\n'
                ')',
          ),
          DemoNote.recommended(
            'The footer is a pagerBuilder over controller.pagination: '
            '"Showing X–Y of Z", gradient page chips and the items-per-page '
            'pill are a few dozen lines of ordinary widgets.',
          ),
          DemoNote(
            'Only the Actions column is widgets — one button per visible row. '
            'Every other cell is painted.',
          ),
        ],
        controls: _TopBar(
          palette: palette,
          onSearch: (v) => _controller.filter.query = v,
          male: _male,
          onGender: _setGender,
          onExport: _bulkExport,
        ),
        child: FitGrid<Patient>(
          controller: _controller,
          theme: palette.gridTheme(material),
          striped: false,
          hoverHighlight: false,
          // The app's table has no resize handles on its header dividers.
          resizableColumns: false,
          paginated: true,
          pageSize: 10,
          emptyState: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No records found',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          pagerBuilder: (context, pagination) =>
              HospitalPager(pagination: pagination, palette: palette),
        ),
      ),
    );
  }
}

/// The outlined arrow button of the Actions column.
class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HospitalPalette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.grey400),
          ),
          child: Icon(
            Icons.arrow_forward,
            size: 12,
            color: palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.palette,
    required this.onSearch,
    required this.male,
    required this.onGender,
    required this.onExport,
  });

  final HospitalPalette palette;
  final ValueChanged<String> onSearch;
  final bool? male;
  final ValueChanged<bool?> onGender;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final inputStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      color: palette.textPrimary,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 350,
          height: 45,
          child: TextField(
            onChanged: onSearch,
            style: inputStyle,
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.cardBg,
              hintText: 'Search by patient name',
              hintStyle: inputStyle.copyWith(color: palette.textHint),
              prefixIcon: Icon(Icons.search, color: palette.textPrimary),
              contentPadding: const EdgeInsets.all(5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        PopupMenuButton<bool?>(
          tooltip: 'Filter',
          color: palette.menuBg,
          onSelected: onGender,
          itemBuilder: (context) => [
            for (final (value, label) in const [
              (null, 'All genders'),
              (true, 'Male'),
              (false, 'Female'),
            ])
              CheckedPopupMenuItem<bool?>(
                value: value,
                checked: male == value,
                child: Text(label, style: inputStyle),
              ),
          ],
          child: Container(
            width: 50,
            height: 45,
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.filter_list,
              size: 20,
              color: palette.textPrimary,
            ),
          ),
        ),
        if (male != null)
          InkWell(
            onTap: () => onGender(null),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Clear Filter (1)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ),
        _GradientButton(label: 'Bulk Export', onTap: onExport),
        _GradientButton(
          label: 'Bulk Upload',
          onTap: () =>
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Bulk Upload'))),
        ),
        _GradientButton(
          label: 'Create Patient',
          onTap: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Create Patient'))),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: HospitalPalette.brand,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          // Sized to its label: an aligned Container would take all the width
          // a Wrap offers it.
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's table footer: "Showing X–Y of Z items", page chips with the
/// current one in the brand gradient, and an items-per-page pill — built on
/// fitgrid's pagination state and nothing else.
class HospitalPager extends StatelessWidget {
  const HospitalPager({
    required this.pagination,
    required this.palette,
    super.key,
  });

  final FitGridPaginationState pagination;
  final HospitalPalette palette;

  static const List<int> perPageOptions = [5, 10, 15, 20];

  /// The pages to show: the first, the last, and the neighbours of the
  /// current one, with null where the run breaks.
  List<int?> _pages() {
    final count = pagination.pageCount;
    final current = pagination.pageIndex;
    final wanted = <int>{
      0,
      count - 1,
      for (var p = current - 1; p <= current + 1; p++)
        if (p >= 0 && p < count) p,
    }.toList()..sort();
    final out = <int?>[];
    for (var i = 0; i < wanted.length; i++) {
      if (i > 0 && wanted[i] - wanted[i - 1] > 1) out.add(null);
      out.add(wanted[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final total = pagination.rowCount;
    if (total == 0) return const SizedBox.shrink();
    final text = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      color: palette.ink70,
    );
    final label = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: palette.ink70,
    );

    return ColoredBox(
      color: palette.tableWash,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Showing ${pagination.firstRowIndex + 1}–'
                  '${pagination.endRowIndex} of $total items',
                  style: text,
                ),
                const SizedBox(width: 16),
                _arrow(
                  Icons.arrow_back_ios_new_sharp,
                  pagination.hasPrevious ? pagination.previous : null,
                ),
                for (final page in _pages())
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: page == null
                        ? Text(
                            '....',
                            style: text.copyWith(color: palette.textSecondary),
                          )
                        : _chip(page),
                  ),
                _arrow(
                  Icons.arrow_forward_ios_sharp,
                  pagination.hasNext ? pagination.next : null,
                ),
                const SizedBox(width: 16),
                Text('Items per page', style: label),
                const SizedBox(width: 8),
                _perPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(int page) {
    final current = page == pagination.pageIndex;
    return InkWell(
      onTap: current ? null : () => pagination.pageIndex = page,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: current ? HospitalPalette.brand : null,
          color: current ? null : palette.paginationInactiveBg,
          border: current ? null : Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: current ? Colors.white : palette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HospitalPalette.pagerArrowBorder),
          ),
          child: Icon(
            icon,
            size: 10,
            color: onTap == null ? palette.textHint : palette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _perPage() {
    return PopupMenuButton<int>(
      tooltip: 'Items per page',
      color: palette.menuBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: HospitalPalette.brandTeal),
      ),
      onSelected: (size) => pagination.pageSize = size,
      itemBuilder: (context) => [
        for (final size in perPageOptions)
          PopupMenuItem<int>(
            value: size,
            child: Row(
              children: [
                Text(
                  '$size',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: size == pagination.pageSize
                        ? HospitalPalette.brandTeal
                        : palette.textPrimary,
                  ),
                ),
                const Spacer(),
                if (size == pagination.pageSize)
                  const Icon(
                    Icons.check,
                    size: 16,
                    color: HospitalPalette.brandTeal,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 110,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: HospitalPalette.brand,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              '${pagination.pageSize}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
