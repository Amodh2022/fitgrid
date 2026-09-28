# Benchmarks

Four of them, because they answer different questions.

**`measurement_benchmark.dart`** is a plain Dart benchmark of the sizing
passes — column measurement and row measurement — over datasets from 1,000 to
1,000,000 rows. It runs on the Dart VM with `dart run`, needs no device, and is
the one to run while changing the sizer.

**`frame_benchmark.dart`** is a widget benchmark of build, layout and paint over
a scroll, run with `flutter test benchmark/frame_benchmark.dart`. It reports
microseconds per frame and the number of laid-out cells, which together are the
claim this package makes: cost tracks the viewport, not the dataset.

**`workload_benchmark.dart`** is the million-row workload, with each operation
timed on its own so a smooth scroll cannot hide a slow sort: scrolling and
jumping, sorting by text, number, date and several keys, filtering by search,
checklist, number and combinations, search-as-you-type per keystroke, and CSV
and xlsx export of all rows, a filtered set and a selection. Sorts and filters
are split into the data work (applying it and building the view) and the frame
that shows the result. It prints resident and peak memory and the machine it
ran on.

**`stress_benchmark.dart`** is the live-update case: 100,000 rows by 30 columns
of mixed text lengths, two frozen columns, a filter active, and records replaced
at 1, 100 and 1,000 per tick. It reports update-to-frame time, the latency of a
scroll, an arrow key or a selection with an update landing in the same frame
(against the same interaction idle), sorting while updating, and whether the
selection and an open editor stay on the same record — printed as PASS or FAIL.
The assertions for that last check live in `test/record_identity_test.dart`.

Both print markdown tables ready to paste; `results/` keeps dated runs. For
numbers from a real device in profile mode, run the example app's *Live
updates* page with `flutter run --profile` and copy its report.

None of them is run in CI as a gate. A timing assertion on a shared runner fails for
reasons that have nothing to do with the code, and a benchmark that cries wolf
gets ignored. They print numbers; read them.

```
dart run benchmark/measurement_benchmark.dart
flutter test benchmark/frame_benchmark.dart
flutter test benchmark/workload_benchmark.dart
flutter test benchmark/stress_benchmark.dart
```

## What to look for

- **Measurement should be sub-linear in rows** for a sampled `auto` column: the
  character-count prefilter is arithmetic and only the survivors are laid out.
  `measureAllRows` is linear by definition — that is what it buys.
- **Painted cell count must not grow with the dataset.** A 1,000-row grid and a
  1,000,000-row grid in the same viewport should report the same number.
- **Frame time must not grow with the dataset either.** If it does, something
  has started walking the rows once per frame.
- **Sort and filter cost is linear in rows, and the frame after it should not
  be.** A frame that costs far more than a scroll frame after a sort means the
  columns were re-measured, which a reorder never needs.
- **Update cost should track the rows that changed**, not the dataset. If 1 and
  1,000 changed rows per tick cost the same, each update is re-deriving the
  whole view.
