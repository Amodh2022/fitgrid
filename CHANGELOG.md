# Changelog

## 0.0.1-dev

Foundation release. Not published.

- `FitGrid` with content-measured column widths (`auto`, `fixed`, `flex`,
  `fitHeader`, each with min/max clamps)
- Painted text cells via `RenderFitGridSection`, with pruned `TextPainter`
  caching and batched rule drawing
- Row windowing driven by the viewport, so layout cost tracks the screen rather
  than the dataset
- `FitGridController` — data, column and selection state as separate
  `ChangeNotifier`s
- `FitGridThemeData`, derivable from `ThemeData`, with three densities
- Right-to-left support in measurement, layout and paint
- `package:fitgrid/testing.dart` for asserting on painted cells
