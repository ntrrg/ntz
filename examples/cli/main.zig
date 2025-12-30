// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const builtin = @import("builtin");
const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const io = ntz.io;
const logging = ntz.logging;
const ui = ntz.ui;
const cli = ui.cli;

const unicode = encoding.unicode;
const utf8 = unicode.utf8;

const Options = @import("Options.zig");

pub var global_status = ntz.Status{};
pub const debug_log = logging.init();

pub fn main() !u8 {
    // ////////////
    // Allocator //
    // ////////////

    var ally: std.mem.Allocator = undefined;

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

    defer {
        if (debug_allocator.deinit() != .ok)
            debug_log.warn("memory leaked");
    }

    ally = switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };

    if (builtin.os.tag == .wasi) ally = std.heap.wasm_allocator;

    // ////////////////////
    // State propagation //
    // ////////////////////

    const status = global_status.sub(ally) catch |err| {
        const msg = "cannot setup status propagation";
        debug_log.with("error", err).err(msg);
        return err;
    };

    defer global_status.deinit(ally);

    // //////////
    // Options //
    // //////////

    //const opts = blk: {
    //    var opts = Options{ .allocator = ally };

    //    var cmd = try opts.command(ally);
    //    defer ally.destroy(cmd);
    //    defer cmd.deinit();

    //    _ = cmd.fromOS(&opts) catch |err| {
    //        const msg = "cannot load option entries from the OS";
    //        debug_log.with("error", err).err(msg);
    //        return err;
    //    };

    //    //break :blk opts.clone(ally) catch |err| {
    //    //    const msg = "cannot finish options reading";
    //    //    debug_log.with("error", err).err(msg);
    //    //    return err;
    //    //};

    //    break :blk opts;
    //};

    var opts = Options{};
    defer opts.deinit(ally);

    const cmd = try Options.command(ally, debug_log);
    defer ally.destroy(cmd);
    defer cmd.deinit();

    // Load options //

    //_ = cmd.fromOS(&opts) catch |err| {
    //    const msg = "cannot load option entries from the OS";
    //    debug_log.with("error", err).err(msg);
    //    return err;
    //};

    var arena_ally = std.heap.ArenaAllocator.init(cmd.allocator);
    defer arena_ally.deinit();
    const arena = arena_ally.allocator();

    var entries: cli.Entries = .{};

    //var field_name_buf: [32]u8 = undefined;
    //const encoder = ctxlog.Encoder.init(&field_name_buf);

    const encoder: struct {
        pub fn encode(_: @This(), writer: anytype, val: anytype) !void {
            var std_writer = writer.stdWriter(&.{});
            var w: *std.Io.Writer = &std_writer.interface;
            _ = &w;

            var enc = std.json.Stringify{
                .writer = w,
                .options = .{ .emit_null_optional_fields = false },
            };

            try enc.write(val);
        }
    } = .{};

    cmd.fromStruct(arena, &entries, encoder, .{
        .log_format = "json",
        .codepoint = .{
            .first_codepoint = 37,
        },
    }) catch |err| {
        const msg = "cannot read option entries from struct";
        cmd.log.with("error", err).err(msg);
        return err;
    };

    cmd.fromEnv(arena, &entries) catch |err| {
        const msg = "cannot read option entries from environment variables";
        cmd.log.with("error", err).err(msg);
        return err;
    };

    cmd.fromArgs(arena, &opts, &entries) catch |err| {
        const msg = "cannot read option entries from arguments";
        cmd.log.with("error", err).err(msg);
        return err;
    };

    for (entries.items()) |entry|
        cmd.log.debugf(arena, "from='{s}', command='{s}', key='{s}', value='{s}'", .{ @tagName(entry.from), entry.command, entry.key, entry.value });

    _ = cmd.load(&arena_ally, &opts, entries.items()) catch |err| {
        const msg = "cannot load option entries";
        debug_log.with("error", err).err(msg);
        return err;
    };

    // //////////
    // Logging //
    // //////////

    // File //

    const log_file: std.fs.File = blk: {
        if (opts.log.file.len == 0) break :blk io.stderr();

        const name = opts.log.file;
        const cwd = std.fs.cwd();

        const file = cwd.openFile(name, .{ .mode = .write_only }) catch |err| file_blk: {
            if (err != std.fs.File.OpenError.FileNotFound) {
                const msg = "cannot open log file '{s}'";
                debug_log.with("error", err).errf(ally, msg, .{name});
                return err;
            }

            break :file_blk cwd.createFile(name, .{}) catch |create_err| {
                const msg = "cannot create log file '{s}'";
                debug_log.with("error", create_err).errf(ally, msg, .{name});
                return create_err;
            };
        };

        file.seekFromEnd(0) catch |err| {
            const msg = "cannot go to the end of the log file";
            debug_log.with("error", err).err(msg);
            return err;
        };

        break :blk file;
    };

    defer log_file.close();

    // Writer //

    const log_file_writer = io.writer(
        log_file,
        std.fs.File.WriteError,
        std.fs.File.write,
    );

    var log_writer_ln = io.delimitedWriter(log_file_writer, ally, "\n");
    defer log_writer_ln.deinit();
    defer log_writer_ln.flush() catch {};

    const log_writer = log_writer_ln.writer();

    // Mutex //

    var log_mutex: std.Thread.Mutex = if (opts.log.file.len > 0)
        std.Thread.Mutex{}
    else
        io.stderr_mux;

    // Encoder //

    var log_field_name_buf: [32]u8 = undefined;

    const log_encoder = LogEncoder{
        .format = opts.log.format,
        .ctxlog_enc = .init(&log_field_name_buf),
        .json_enc = .{},
    };

    // Logger //

    const log = blk: {
        var log = logging.initWith(log_writer, log_encoder, LogContext);
        if (!builtin.single_threaded) log.mux = &log_mutex;
        break :blk log.withSeverity(opts.log.level);
    };

    // /////////////
    // OS Signals //
    // /////////////

    var sa: std.posix.Sigaction = .{
        .handler = .{ .sigaction = signalHandler },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.RESTART,
    };

    std.posix.sigaction(std.posix.SIG.INT, &sa, null);
    std.posix.sigaction(std.posix.SIG.TERM, &sa, null);

    // ////////////////////////////////////////////////////////////////////////

    log.info("preparing buffer for the standart output");

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = io.stdout().writer(&stdout_buf);
    var stdout = &stdout_writer.interface;

    defer {
        log.info("flushing the standart output buffer");
        stdout.flush() catch {};
        log.info("flushed the standart output buffer");
    }

    log.info("buffer for the standart output set");

    const utf8_log = log.withScope("utf8");

    for (opts.first_cp..opts.last_cp) |i| {
        if (status.isDone()) break;
        if (unicode.isSurrogateCharacter(i)) continue;

        var buf: [4]u8 = undefined;

        const want = try unicode.Codepoint.init(@intCast(i));
        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        utf8_log.with("cp", got.value).with("str", buf[0..n]).debug("");
        try stdout.print("0x{X:<6} [{s}]\n", .{ got.value, buf[0..n] });
    }

    return 0;
}

// //////////
// Logging //
// //////////

pub const LogContext = struct {
    level: []const u8,
    msg: []const u8,
    @"error": ?anyerror,

    utf8: ?struct {
        cp: u21,
        str: []const u8,
    },
};

pub const LogEncoder = struct {
    const Self = @This();

    pub const Format = enum {
        ctxlog,
        json,
    };

    format: Format = .ctxlog,

    ctxlog_enc: ctxlog.Encoder,

    json_enc: struct {
        pub fn encode(_: @This(), writer: anytype, val: anytype) !void {
            var std_writer = writer.stdWriter(&.{});
            var w: *std.Io.Writer = &std_writer.interface;
            _ = &w;

            var enc = std.json.Stringify{
                .writer = w,
                .options = .{ .emit_null_optional_fields = false },
            };

            try enc.write(val);
        }
    },

    pub fn encode(e: Self, writer: anytype, val: anytype) !void {
        switch (e.format) {
            .ctxlog => try e.ctxlog_enc.encode(writer, val),
            .json => try e.json_enc.encode(writer, val),
        }
    }
};

// /////////////
// OS Signals //
// /////////////

fn signalHandler(
    sig: i32,
    _: *const std.posix.siginfo_t,
    _: ?*anyopaque,
) callconv(.c) void {
    switch (sig) {
        std.posix.SIG.INT, std.posix.SIG.TERM => {
            const exit_code: u8 = 128 +| @as(u8, @intCast(sig));

            if (global_status.isDone()) {
                std.process.exit(exit_code);
            } else {
                const msg = "terminating program... try again to force exit";
                debug_log.warn(msg);
                global_status.done();
            }
        },

        else => {},
    }
}
