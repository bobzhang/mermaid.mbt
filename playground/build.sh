#!/bin/sh
# Build the playground into a static site: playground/build.sh [out-dir]
# With esbuild on the PATH (as in CI) the module is minified.
set -eu
cd "$(dirname "$0")/.."
out=${1:-_build/playground-site}
moon build --target js --release playground
js=_build/js/release/build/bobzhang/mermaid/playground/playground.js
rm -rf "$out"
mkdir -p "$out"
cp playground/web/* "$out"/
if command -v esbuild >/dev/null 2>&1; then
  esbuild "$js" --minify --format=esm --outfile="$out/mermaid-port.js" --log-level=warning
else
  cp "$js" "$out/mermaid-port.js"
fi
touch "$out/.nojekyll"
echo "built $out ($(du -sh "$out" | cut -f1))"
