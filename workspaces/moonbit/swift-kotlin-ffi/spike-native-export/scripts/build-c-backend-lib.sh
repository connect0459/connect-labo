#!/usr/bin/env bash
#
# Counterpart to build-native-lib.sh for moon's OTHER native-target codegen
# strategy: `moon build --target native --release` (equivalent to
# `MOONBIT_NEW_NATIVE=0`) emits a portable C99 source file instead of a
# machine object. Unlike the "new native" strategy that build-native-lib.sh
# wraps, moonc's involvement here ends at emitting C text — the actual
# target-specific compilation is delegated to whatever C compiler the caller
# points at (host cc, an Android NDK clang, an Xcode clang for iOS), so
# moonc's own limited native `-target` triple list (macOS/Linux-glibc/Windows
# only) is irrelevant. Verified 2026-08-01 to work unmodified on iOS
# Simulator (ran under `xcrun simctl spawn`) and Android (NDK
# aarch64-linux-android24-clang), see ../research.md, "訂正：moonc の
#『Cバックエンド』経由でAndroid/iOSともに実機で動作した".
set -euo pipefail

# Toolchain versions this recipe was last verified against. A mismatch is a
# warning, not a hard failure, so a future build failure can be attributed to
# a toolchain upgrade instead of investigated as a mystery from scratch.
EXPECTED_MOON_VERSION="0.1.20260729"
EXPECTED_MOONC_VERSION="v0.10.5+5e7afb0c0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MOON_LIB_DIR="${MOON_HOME:-$HOME/.moon}/lib"
MOON_INCLUDE_DIR="${MOON_HOME:-$HOME/.moon}/include"

usage() {
  cat <<'EOF'
Usage: build-c-backend-lib.sh -o <output> [-c <cc>] [-p] [-- extra cc args/sources]

Builds this package via moon's C-backend strategy (portable C99 source, no
target-triple dependency in moonc) and compiles it, together with moon's
portable runtime.c and any extra arguments (target/-isysroot flags, JNI shim
sources, etc.), into a single shared library.

  -o <path>   output shared library path (required)
  -c <cc>     C compiler to invoke (default: cc; point this at an NDK or
              Xcode clang to cross-compile for Android/iOS)
  -p          do NOT define MOONBIT_NATIVE_NO_SYS_HEADER (opt out of the
              portable-runtime fallback; only meaningful for a host build
              that needs the POSIX filesystem/random APIs runtime.c
              otherwise stubs out — see ../research.md for the tradeoff)
  -h          show this help

Examples:
  # Host macOS build (same MoonBit code, other codegen strategy than
  # build-native-lib.sh; useful to sanity-check the C backend on its own)
  scripts/build-c-backend-lib.sh -o /tmp/libexportspike_c_backend.dylib

  # iOS Simulator
  SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
  scripts/build-c-backend-lib.sh -o ios-test/lib/libexportspike_ios_sim.dylib -- \
    -target arm64-apple-ios17.0-simulator -isysroot "$SDK"

  # Android NDK
  NDK=/opt/homebrew/Caskroom/android-ndk/29/AndroidNDK*.app/Contents/NDK
  scripts/build-c-backend-lib.sh \
    -c "$NDK"/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android24-clang \
    -o android-test/libexportspike_android.so -- -fPIC
EOF
}

output=""
cc_bin="cc"
no_sys_header=1
while getopts "o:c:ph" opt; do
  case "$opt" in
    o) output="$OPTARG" ;;
    c) cc_bin="$OPTARG" ;;
    p) no_sys_header=0 ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "$output" ]]; then
  echo "error: -o <output> is required" >&2
  usage >&2
  exit 1
fi

check_version() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" != *"$expected"* ]]; then
    echo "warning: $label version drifted from the last-verified one." >&2
    echo "         expected to contain: $expected" >&2
    echo "         actual:              $actual" >&2
    echo "         a build failure below may be caused by this, not by this script." >&2
  fi
}

check_version "moon" "$(moon version 2>&1)" "$EXPECTED_MOON_VERSION"
check_version "moonc" "$(moonc -v 2>&1)" "$EXPECTED_MOONC_VERSION"

echo "== moon build --target native --release (a link error here is expected; only the .c file is used) ==" >&2
(cd "$PROJECT_ROOT" && moon build --target native --release) || true

generated_c="$PROJECT_ROOT/_build/native/release/build/export_spike.c"
runtime_c="$MOON_LIB_DIR/runtime.c"

for f in "$generated_c" "$runtime_c"; do
  if [[ ! -e "$f" ]]; then
    echo "error: expected build artifact not found: $f" >&2
    echo "       moon's internal build/lib layout may have changed (see research.md)." >&2
    exit 1
  fi
done

cc_flags=(-I "$MOON_INCLUDE_DIR")
if [[ "$no_sys_header" -eq 1 ]]; then
  cc_flags+=(-DMOONBIT_NATIVE_NO_SYS_HEADER)
fi

echo "== compiling $output with $cc_bin ==" >&2
mkdir -p "$(dirname "$output")"
"$cc_bin" -shared "${cc_flags[@]}" -o "$output" "$generated_c" "$runtime_c" "$@"
echo "done: $output" >&2
