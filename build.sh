#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Step 1: Build the Swift C bindings dylib.
#
# Swift requires its SDK's .swiftinterface files to match the compiler version
# exactly. Nixpkgs only packages Swift 5.10.1; the system Swift 6.2 compiler
# must be used instead. We clear all Nix SDK/toolchain env vars so Swift PM
# discovers the system SDK (macOS 26.x) via the standard xcrun lookup.
echo "==> Building Swift C bindings (libFoundationModels.dylib)..."
env -u SDKROOT -u DEVELOPER_DIR -u MACOSX_DEPLOYMENT_TARGET \
	-u NIX_CFLAGS_COMPILE -u NIX_LDFLAGS -u NIX_APPLE_SDK_VERSION \
	swift build -c release \
	--package-path python-apple-fm-sdk/foundation-models-c \
	--product FoundationModels

# Step 2: Build the Zig project.
# Zig has its own C toolchain and doesn't use Nix's cc-wrapper. We clear
# NIX_CFLAGS_COMPILE and NIX_LDFLAGS to avoid warnings from flags Zig
# doesn't understand (e.g. -fmacro-prefix-map). SDKROOT is kept so Zig
# can find apple-sdk_26 headers via @cImport.
echo "==> Building Zig binary..."
if [[ "${1:-}" == "run" ]]; then
	env -u NIX_CFLAGS_COMPILE -u NIX_LDFLAGS zig build run
else
	env -u NIX_CFLAGS_COMPILE -u NIX_LDFLAGS zig build "$@"
fi
