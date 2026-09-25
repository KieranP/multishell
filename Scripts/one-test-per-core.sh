#!/bin/bash
# Runs the command with swift-testing held to one test per core, failing where it
# cannot cap itself rather than freezing CI. Why: Docs/develop/tests.md.
set -euo pipefail

testing="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/Library/Frameworks/Testing.framework/Testing"
if ! grep -q SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH "$testing" 2>/dev/null; then
  echo "error: $testing cannot cap how many tests run at once" >&2
  exit 1
fi

SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH="$(sysctl -n hw.ncpu)"
export SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH
exec "$@"
