{
  description = "Zig program that calls Apple's on-device LLM via the FoundationModels C bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.zig
        ];

        shellHook = ''
          # Nix's mkShell injects its own macOS SDK (14.4) and compiler flags
          # into the environment. These are incompatible with:
          #   - Swift 6.2 (requires macOS 26 SDK)
          #   - Zig's own C compilation (doesn't understand Nix's -fmacro-prefix-map flags)
          # We clear them so both tools use the system toolchain/SDK.
          unset SDKROOT
          unset DEVELOPER_DIR
          unset MACOSX_DEPLOYMENT_TARGET
          unset NIX_CFLAGS_COMPILE
          unset NIX_LDFLAGS

          # Verify system Swift is available and >= 6.2
          if ! command -v swift &> /dev/null; then
            echo "ERROR: swift not found on PATH."
            echo "Install Xcode or Command Line Tools: xcode-select --install"
            return 1
          fi

          swift_version=$(swift --version 2>&1 | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+')
          swift_major=''${swift_version%%.*}
          swift_minor=''${swift_version#*.}

          if [ "$swift_major" -lt 6 ] || { [ "$swift_major" -eq 6 ] && [ "$swift_minor" -lt 2 ]; }; then
            echo "ERROR: Swift >= 6.2 required (found $swift_version)"
            echo "Update Xcode or Command Line Tools to get Swift 6.2+"
            return 1
          fi

          # Verify macOS 26 SDK is available (use /usr/bin/xcrun to bypass Nix wrappers)
          sdk_path=$(/usr/bin/xcrun --show-sdk-path 2>/dev/null)
          sdk_version=$(/usr/bin/xcrun --show-sdk-version 2>/dev/null)
          sdk_major=''${sdk_version%%.*}

          if [ -z "$sdk_major" ] || [ "$sdk_major" -lt 26 ]; then
            echo "ERROR: macOS 26 SDK required (found SDK version ''${sdk_version:-unknown} at ''${sdk_path:-unknown})"
            echo "Update Xcode or Command Line Tools to get the macOS 26 SDK"
            return 1
          fi

          echo "Environment OK:"
          echo "  Swift:    $swift_version"
          echo "  SDK:      $sdk_version ($sdk_path)"
          echo "  Zig:      $(zig version)"
          echo ""
          echo "Run ./build.sh to build, or ./build.sh run to build and run."
        '';
      };
    };
}
