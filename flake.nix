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
          pkgs.apple-sdk_26
        ];

        shellHook = ''
          # Verify system Swift is available and >= 6.2.
          # Swift is not provided by Nix — it must come from Apple's Command Line
          # Tools or Xcode. The Swift compiler requires an SDK whose .swiftinterface
          # files match its exact version. Nix's apple-sdk_26 (SDK 26.0) was built
          # with Swift 6.2.0 and is incompatible with the system's Swift 6.2.4 which
          # ships SDK 26.2. Therefore, the Swift build step must use the system SDK.
          # Zig only needs C headers + framework stubs, so Nix's SDK 26 is fine for it.

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

          echo "Environment OK:"
          echo "  Zig:        $(zig version)"
          echo "  Nix SDK:    $SDKROOT (for Zig C compilation)"
          echo "  Swift:      $swift_version (system, uses system SDK)"
          echo ""
          echo "Run ./build.sh to build, or ./build.sh run to build and run."
        '';
      };
    };
}
