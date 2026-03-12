const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "fm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add the C header include path so @cImport can find FoundationModels.h
    exe.root_module.addIncludePath(b.path(
        "python-apple-fm-sdk/foundation-models-c/Sources/FoundationModelsCBindings/include",
    ));

    // Link against the prebuilt dylib from the Swift package build
    exe.root_module.addLibraryPath(.{
        .cwd_relative = "python-apple-fm-sdk/foundation-models-c/.build/arm64-apple-macosx/release",
    });
    exe.root_module.linkSystemLibrary("FoundationModels", .{});

    // Add rpath so the binary can find the dylib at runtime
    exe.root_module.addRPath(.{
        .cwd_relative = "python-apple-fm-sdk/foundation-models-c/.build/arm64-apple-macosx/release",
    });

    // Need libc for the C header types (stdbool.h, stdint.h, stddef.h)
    exe.root_module.link_libc = true;

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Apple FM inference");
    run_step.dependOn(&run_cmd.step);
}
