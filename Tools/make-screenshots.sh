#!/usr/bin/env bash
# Renders the App Store screenshots into Design/screenshots (or $1).
#
# The generator renders the app's own SwiftUI views, so it has to be compiled
# together with Sources/. That rules out running it as a plain `swift
# Tools/make-screenshots.swift` script: multi-file compilation requires the
# entry point to be named main.swift, so we stage a copy under that name.
set -euo pipefail

cd "$(dirname "$0")/.."
out="${1:-Design/screenshots}"

build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

cp Tools/make-screenshots.swift "$build/main.swift"
swiftc -O "$build/main.swift" \
  Sources/Model/*.swift Sources/Support/*.swift Sources/Views/*.swift \
  -o "$build/make-screenshots"

"$build/make-screenshots" "$out"
