#!/bin/sh
# Build the playground into a static site: playground/build.sh [out-dir]
# With esbuild on the PATH (as in CI) the module is minified.
set -eu
cd "$(dirname "$0")/.."
out=${1:-_build/playground-site}
moon build --target js --release playground
# where moon puts the module depends on its version
js=$(find _build/js/release/build -name playground.js -path '*/playground/*' | head -n 1)
test -n "$js" || { echo "playground.js not built" >&2; exit 1; }
rm -rf "$out"
mkdir -p "$out"
cp playground/web/* "$out"/
if command -v esbuild >/dev/null 2>&1; then
  esbuild "./$js" --minify --format=esm --outfile="$out/mermaid-port.js" --log-level=warning
else
  cp "$js" "$out/mermaid-port.js"
fi
touch "$out/.nojekyll"
echo "built $out ($(du -sh "$out" | cut -f1))"
