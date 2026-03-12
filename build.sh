#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Step 1: Build the Swift C bindings dylib.
echo "==> Building Swift C bindings (libFoundationModels.dylib)..."
swift build -c release \
  --package-path python-apple-fm-sdk/foundation-models-c \
  --product FoundationModels

# Step 2: Build the Zig project.
echo "==> Building Zig binary..."
if [[ "${1:-}" == "run" ]]; then
  zig build run
else
  zig build "$@"
fi
