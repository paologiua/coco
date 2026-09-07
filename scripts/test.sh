#!/usr/bin/env bash
# Run the test suite.
#
# XCTest ships with Xcode, which is not installed here, so the tests use
# swift-testing — which the Command Line Tools DO provide, just not on any search
# path SwiftPM knows about. Hence the framework path, and two rpaths: one for
# Testing.framework itself and one for the interop dylib it loads in turn.
set -euo pipefail
cd "$(dirname "$0")/.."
FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
INTEROP=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
[ -d "$FW/Testing.framework" ] || { echo "FATAL: swift-testing missing from the CLT"; exit 1; }
exec swift test \
  -Xswiftc -F -Xswiftc "$FW" \
  -Xlinker -rpath -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker "$INTEROP" "$@"
