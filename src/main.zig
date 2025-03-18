// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const builtin = @import("builtin");
const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const unicode = encoding.unicode;
const utf8 = unicode.utf8;
const io = ntz.io;
const logging = ntz.logging;
const status = ntz.status;

var state = status.State{};

pub fn main() !void {
    // Allocator //

    var ally: std.mem.Allocator = undefined;

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    ally = switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };

    if (builtin.os.tag == .wasi) ally = std.heap.wasm_allocator;

    // Logger //

    const std_err = io.stdErr();
    var log_writer = io.delimitedWriter(std_err.writer(), "\n", ally);

    defer {
        log_writer.deinit();
        log_writer.flush() catch {};
    }

    const log_encoder = ctxlog.Encoder{};

    const log = logging.initWithWriter(
        &io.std_err_mux,
        &log_writer,
        log_encoder,

        struct {
            level: logging.Level,
            msg: []const u8,

            utf8: ?struct {
                cp: u21,
                str: []const u8,
            },
        },
    ).withSeverity(.debug);

    // OS Signals //

    var sa: std.posix.Sigaction = .{
        .handler = .{ .sigaction = signalHandler },
        .mask = std.posix.empty_sigset,
        .flags = std.posix.SA.RESTART,
    };

    std.posix.sigaction(std.posix.SIG.INT, &sa, null);
    std.posix.sigaction(std.posix.SIG.TERM, &sa, null);

    // /////////////////////////////////////////////////////////////////////////

    log.info("preparing buffer for the standart output");

    const std_out = io.stdOut();
    var bw = io.bufferedWriter(std_out.writer());

    defer {
        log.info("flushing the standart output buffer");
        bw.flush() catch {};
        log.info("flushed the standart output buffer");
    }

    const w = bw.writer().stdWriter();

    log.info("buffer for the standart output set");

    const utf8_log = log.withScope("utf8");

    for (0x20..0xFFFF) |i| {
        if (state.isDone()) break;
        if (unicode.isSurrogateCharacter(i)) continue;

        var buf: [4]u8 = undefined;

        const want = try unicode.Codepoint.init(@intCast(i));
        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        utf8_log.with("cp", got.value).with("str", buf[0..n]).debug("");
        try std.fmt.format(w, "{x}   {s}\n", .{ got.value, buf[0..n] });
    }

    // /////////////////////////////////////////////////////////////////////////

    if (state.isDone()) {
        log.err("terminating program...");
    }
}

pub fn signalHandler(
    sig: i32,
    _: *const std.posix.siginfo_t,
    _: ?*anyopaque,
) callconv(.C) void {
    switch (sig) {
        std.posix.SIG.INT, std.posix.SIG.TERM => {
            state.done();
        },

        else => {},
    }
}
