const std = @import("std");
const fm = @cImport({
    @cInclude("FoundationModels.h");
});

const GenerationContext = struct {
    last_length: usize = 0,
    is_responding: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
    failed: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn responseCallback(status: c_int, content: [*c]const u8, length: usize, user_info: ?*anyopaque) callconv(.c) void {
    const ctx: *GenerationContext = @ptrCast(@alignCast(user_info.?));

    if (status != 0) {
        std.debug.print("Failed to respond (error: {})\n", .{status});
        ctx.failed.store(true, .release);
        ctx.is_responding.store(false, .release);
        return;
    }

    if (content != null) {
        // content is cumulative; print only the new portion
        const new_bytes = content[ctx.last_length..length];
        const out = std.fs.File.stdout();
        _ = out.write(new_bytes) catch 0;
        ctx.last_length = length;
    } else {
        // content == null signals completion
        const out = std.fs.File.stdout();
        _ = out.write("\n") catch 0;
        ctx.is_responding.store(false, .release);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    // Get the default on-device model
    const model = fm.FMSystemLanguageModelGetDefault();
    defer fm.FMRelease(model);

    // Check availability
    var unavailable_reason: fm.FMSystemLanguageModelUnavailableReason = fm.FMSystemLanguageModelUnavailableReasonUnknown;
    const is_available = fm.FMSystemLanguageModelIsAvailable(model, &unavailable_reason);

    if (is_available) {
        try stdout.print("Model is available\n", .{});
        try stdout.flush();
    } else {
        try stdout.print("Model is unavailable (reason: {})\n", .{unavailable_reason});
        try stdout.flush();
        return;
    }

    // Create a session with a system instruction
    const session = fm.FMLanguageModelSessionCreateFromSystemLanguageModel(
        model,
        "You are a helpful assistant. Keep your responses concise.",
        null,
        0,
    );
    defer fm.FMRelease(session);

    // Read prompt from stdin
    const raw_prompt = try stdin.allocRemaining(allocator, .unlimited);
    defer allocator.free(raw_prompt);
    const trimmed = std.mem.trimRight(u8, raw_prompt, &std.ascii.whitespace);

    if (trimmed.len == 0) {
        try stdout.print("No prompt provided. Pipe text into stdin.\n", .{});
        try stdout.flush();
        return;
    }

    // Create a null-terminated copy for the C API
    const prompt = try allocator.dupeZ(u8, trimmed);
    defer allocator.free(prompt);

    // Stream a response
    try stdout.print("> {s}\n\n", .{prompt});
    try stdout.flush();

    const stream = fm.FMLanguageModelSessionStreamResponse(session, prompt.ptr, null);
    defer fm.FMRelease(stream);

    var ctx = GenerationContext{};
    fm.FMLanguageModelSessionResponseStreamIterate(stream, @ptrCast(&ctx), responseCallback);

    // Spin until the callback signals completion
    while (ctx.is_responding.load(.acquire)) {
        std.atomic.spinLoopHint();
    }

    if (ctx.failed.load(.acquire)) {
        return error.GenerationFailed;
    }
}
