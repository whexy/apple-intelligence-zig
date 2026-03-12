#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure Swift uses the system SDK, not any Nix-provided one.
# Nix's mkShell sets SDKROOT to its macOS 14.4 SDK which is incompatible
# with the Swift 6.2 compiler needed for this project.
unset SDKROOT
unset DEVELOPER_DIR
unset MACOSX_DEPLOYMENT_TARGET
unset NIX_CFLAGS_COMPILE
unset NIX_LDFLAGS

# Step 1: Build the Swift C bindings dylib
echo "==> Building Swift C bindings (libFoundationModels.dylib)..."
swift build -c release \
	--package-path python-apple-fm-sdk/foundation-models-c \
	--product FoundationModels

# Step 2: Build the Zig project
echo "==> Building Zig binary..."
if [[ "${1:-}" == "run" ]]; then
	zig build run
else
	zig build "$@"
fi
