# Apple Intelligence (Zig)

Apple has released a Python SDK for their Foundation Model framework, which includes official C bindings.

The C bindings provide a good opportunity to integrate the framework with Zig. This repo demonstrates how to use Zig to call the on-device Apple Intelligence language model.

## Prerequisites

- macOS 26 or later, with Apple Intelligence enabled in System Settings.
- Xcode Command Line Tools installed.
- Zig 0.15.2 or later installed.

Clone with submodules, then run the build script:

```bash
git clone --recursive https://github.com/whexy/apple-intelligence-zig
./build.sh      # builds the Swift dylib and the Zig binary
```

To build and run in one step:

```bash
echo "What is the capital of France?" | ./build.sh run
```

Or ask the model to explain its own source code:

```bash
cat <(echo "explain the code:") src/main.zig | ./build.sh run
```
