#!/bin/sh
# Run `flutter test` with the macOS toolchain shims on PATH.
# See tool/README.md for why this is needed and when it is not.
set -e
shim="$(cd "$(dirname "$0")/mac-toolchain-shim" && pwd)"
cd "$(dirname "$0")/.."
PATH="$shim:$PATH" DEVELOPER_DIR=/Library/Developer/CommandLineTools \
  exec flutter test "$@"
