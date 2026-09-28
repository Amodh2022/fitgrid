#!/usr/bin/env bash
# Runs every grid at every size, each in its own process, then combines the
# output into one markdown report.
#
#   cd benchmark/compare && tool/run.sh            # 100k and 1M
#   ROWS="20000" GRIDS="fitgrid syncfusion" tool/run.sh
set -u
cd "$(dirname "$0")/.."
ROWS="${ROWS:-100000 1000000}"
GRIDS="${GRIDS:-fitgrid syncfusion trina pluto}"
OUT=build/compare
mkdir -p "$OUT"
for rows in $ROWS; do
  for grid in $GRIDS; do
    echo "== $grid × $rows" >&2
    # Only this combination's previous output is replaced, so a subset run
    # (GRIDS=fitgrid, say) keeps the other grids' results for the combiner.
    rm -f "$OUT/$grid-$rows.txt"
    # Piped rather than redirected: the snap-packaged flutter writes nothing
    # to a redirected file. A grid that runs out of time or memory is
    # recorded, not dropped.
    timeout 1500 flutter test test/compare_benchmark.dart \
        --dart-define=GRID="$grid" --dart-define=ROWS="$rows" 2>&1 \
      | cat > "$OUT/$grid-$rows.txt"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
      printf 'DNF\t%s\t%s\n' "$grid" "$rows" >> "$OUT/$grid-$rows.txt"
    fi
  done
done
dart run tool/combine.dart "$OUT" | cat
