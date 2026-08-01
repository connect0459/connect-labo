#!/usr/bin/env bash
#
# `moon build --target native` cannot link this package into a shared library
# on its own: `pkgtype(kind: "foreign_library")` is not yet wired into the
# native target's link step (see ../research.md, "経路A" section, and moon's
# own FIXME in NativeLinkConfig). moonc's code generation is correct though,
# so this script performs the missing link step by hand: build the native
# object files, locate moon's bundled runtime support objects, and link them
# with cc -shared. This is the same recipe used ad hoc during the spikes,
# now made reproducible and version-checked.
set -euo pipefail

# Toolchain versions this recipe was last verified against. A mismatch is a
# warning, not a hard failure, so a future link error can be attributed to a
# toolchain upgrade instead of investigated as a mystery from scratch.
EXPECTED_MOON_VERSION="0.1.20260729"
EXPECTED_MOONC_VERSION="v0.10.5+5e7afb0c0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MOON_LIB_DIR="${MOON_HOME:-$HOME/.moon}/lib"

usage() {
  cat <<'EOF'
Usage: build-native-lib.sh -o <output.dylib> [-- extra cc args/sources]

Builds this package's MoonBit native-target objects and links them, plus
moon's bundled runtime support objects and any extra arguments (JNI shim
sources, -I include paths, etc.), into a single shared library via
`cc -shared`.

  -o <path>   output shared library path (required)
  -h          show this help

Examples:
  scripts/build-native-lib.sh -o swift-test/lib/libexportspike_swift.dylib

  scripts/build-native-lib.sh -o jni-test/libexportspike_jni.dylib -- \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" jni-test/jni_shim.c
EOF
}

output=""
while getopts "o:h" opt; do
  case "$opt" in
    o) output="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "$output" ]]; then
  echo "error: -o <output.dylib> is required" >&2
  usage >&2
  exit 1
fi

check_version() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" != *"$expected"* ]]; then
    echo "warning: $label version drifted from the last-verified one." >&2
    echo "         expected to contain: $expected" >&2
    echo "         actual:              $actual" >&2
    echo "         a link failure below may be caused by this, not by this script." >&2
  fi
}

check_version "moon" "$(moon version 2>&1)" "$EXPECTED_MOON_VERSION"
check_version "moonc" "$(moonc -v 2>&1)" "$EXPECTED_MOONC_VERSION"

echo "== moon build --target native (a link error here is expected; only the .o files are used) ==" >&2
(cd "$PROJECT_ROOT" && moon build --target native) || true

core_obj="$PROJECT_ROOT/_build/native/debug/build/__moonbit_link_core__/export_spike.o"
runtime_obj="$PROJECT_ROOT/_build/native/debug/build/runtime.o"
moon_support_objs=(
  "$MOON_LIB_DIR/moonbit_simdutf.o"
  "$MOON_LIB_DIR/simdutf.o"
  "$MOON_LIB_DIR/libbacktrace.a"
)

for f in "$core_obj" "$runtime_obj" "${moon_support_objs[@]}"; do
  if [[ ! -e "$f" ]]; then
    echo "error: expected build artifact not found: $f" >&2
    echo "       moon's internal build/lib layout may have changed (see research.md, '手動リンクの再現性')." >&2
    exit 1
  fi
done

echo "== linking $output ==" >&2
mkdir -p "$(dirname "$output")"
cc -shared -o "$output" "$core_obj" "$runtime_obj" "${moon_support_objs[@]}" "$@"
echo "done: $output" >&2
