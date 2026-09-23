# Benchmarks

Two kinds, because they answer different questions.

**`measurement_benchmark.dart`** is a plain Dart benchmark of the sizing
passes — column measurement and row measurement — over datasets from 1,000 to
1,000,000 rows. It runs on the Dart VM with `dart run`, needs no device, and is
the one to run while changing the sizer.

**`frame_benchmark.dart`** is a widget benchmark of build, layout and paint over
a scroll, run with `flutter test benchmark/frame_benchmark.dart`. It reports
microseconds per frame and the number of laid-out cells, which together are the
claim this package makes: cost tracks the viewport, not the dataset.

Neither is run in CI as a gate. A timing assertion on a shared runner fails for
reasons that have nothing to do with the code, and a benchmark that cries wolf
gets ignored. They print numbers; read them.

```
dart run benchmark/measurement_benchmark.dart
flutter test benchmark/frame_benchmark.dart
```

## What to look for

- **Measurement should be sub-linear in rows** for a sampled `auto` column: the
  character-count prefilter is arithmetic and only the survivors are laid out.
  `measureAllRows` is linear by definition — that is what it buys.
- **Painted cell count must not grow with the dataset.** A 1,000-row grid and a
  1,000,000-row grid in the same viewport should report the same number.
- **Frame time must not grow with the dataset either.** If it does, something
  has started walking the rows once per frame.
