#!/usr/bin/env bash
# Sets up the optional browser test for the web export.
#
#   bash tools/setup_browser_test.sh
#
# Installs Playwright (Chromium) into tools/ and creates the .gdignore files
# that keep the Godot editor from trying to import the Node modules and the
# exported build.  Without the .gdignore the editor tries to import the
# Playwright dashboard SVGs, one of which is 51500x51500 pixels and will run
# the editor out of memory.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> creating .gdignore files"
mkdir -p tools/node_modules build
touch tools/node_modules/.gdignore build/.gdignore
echo "    tools/node_modules/.gdignore"
echo "    build/.gdignore"

if [ ! -d tools/node_modules/playwright ]; then
	echo "==> installing playwright (this downloads Chromium, ~150 MB)"
	cd tools
	npm install playwright
	npx playwright install --with-deps chromium
	cd ..
else
	echo "==> playwright is already installed"
fi

echo
echo "Done.  Now you can:"
echo "  1. export:  godot --headless --path . --export-release \"Web\" build/web/index.html"
echo "  2. serve:   python3 tools/serve_web.py 8080 build/web"
echo "  3. test:    node tools/browser_test.js http://127.0.0.1:8080"
