#!/usr/bin/env bash
# Builds the website for Vercel: the static pages in site/, the screenshots,
# and the example gallery for the web under /demo/, all into _site/.
#
# Vercel's build machines have no Flutter, so it is fetched here when missing.
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

(
  cd example
  flutter pub get
  flutter build web --release --base-href /demo/
)

rm -rf _site
mkdir _site
cp -r site/. _site/
cp -r screenshots _site/screenshots
cp -r example/build/web _site/demo
echo "Site assembled in _site/"
