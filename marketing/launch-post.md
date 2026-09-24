# Launch material for fitgrid_table 0.1.0

Drafts to adapt and post. Replace the links if the site moves. Post the long
version first (dev.to or Medium), then share it with the short versions.

---

## Long post (dev.to / Medium / your blog)

**Title:** A Flutter data table that scrolls a million rows — and sizes its own columns

**Tags:** flutter, dart, opensource, performance

Every Flutter app eventually needs a table, and every table asks the same two
questions: *how wide is each column?* and *what happens when there are a lot of
rows?*

The usual answers are "you tell me, in pixels" and "it gets slow". I built
**fitgrid** to give different ones.

**Columns measure their content.** You don't pick widths. A column looks at its
text and sizes itself — with a min and max when you want them, flex columns to
share leftover space, or a fixed width where it matters. It samples the longest
candidates rather than measuring every row, so it stays fast on huge datasets.

**Cells are painted, not built.** A widget-per-cell table with 40 rows and 8
columns is 320 widgets, elements and render objects. In fitgrid it's one render
object and a handful of cached text painters. The work per frame follows the
viewport, not the data:

| Rows | Median scroll frame | Rows laid out |
|---|---|---|
| 1,000 | 5.1 ms | 20 |
| 1,000,000 | 2.9 ms | 20 |

Painting doesn't mean giving things up. fitgrid builds a real accessibility tree
over its cells, and you can still put real widgets — buttons, switches, avatars
— in the columns that need them.

**And it's a full data grid:** multi-column sort, typed filters with a UI, a
column menu and chooser, frozen columns, inline editing, cell ranges with copy,
paste, a fill handle and undo, grouping with sticky headers, tree and detail
rows, header bands, row reordering, infinite scroll, server-backed rows, data
bars and sparklines in cells, pivot tables, and CSV/TSV/**xlsx** export written
in pure Dart. MIT licensed, with no dependencies beyond Flutter.

```dart
FitGrid<Employee>(
  rows: employees,
  columns: [
    FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name, sortable: true),
    FitGridColumn(id: 'salary', label: 'Salary', value: (e) => money(e.salary),
        alignment: FitGridAlignment.end, sortable: true,
        comparator: (a, b) => a.salary.compareTo(b.salary)),
  ],
)
```

Try it:

- Live demo: https://amodh2022.github.io/fitgrid/demo/
- pub.dev: https://pub.dev/packages/fitgrid_table
- GitHub: https://github.com/Amodh2022/fitgrid

I'd love feedback — especially from anyone with a table that's been too slow or
too fiddly to size. Issues and PRs welcome.

---

## r/FlutterDev

**Title:** I made fitgrid, an MIT Flutter data grid that sizes columns to their content and scrolls 1M rows (painted cells, no deps)

Body: two or three sentences from the long post, the benchmark table, the demo
link, and a question inviting feedback ("What does your table need that this
doesn't do?"). Reply to comments — early discussion is what makes a post last.

---

## X / Bluesky / LinkedIn

> fitgrid 0.1.0 is out: a Flutter data table that measures its own columns and
> paints cells, so a million rows scroll like a hundred. Sorting, filters,
> editing, grouping, pivots, xlsx export — MIT, no dependencies.
> Demo: https://amodh2022.github.io/fitgrid/demo/
> #Flutter #FlutterDev #Dart

Attach `screenshots/overview.png` or a short screen recording of the demo.

---

## Listings to submit (one-time)

- Flutter Gems — https://fluttergems.dev (suggest it under Data Tables / Grids)
- awesome-flutter — open a PR adding it under the UI / tables section
- Google Search Console — add https://amodh2022.github.io/fitgrid/ and submit
  `sitemap.xml`
- pub.dev — once published, ask early users to like the package; likes feed
  pub.dev search ranking
