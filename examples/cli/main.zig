// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const build_options = @import("build_options");

const builtin = @import("builtin");
const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const io = ntz.io;
const os = ntz.os;
const cli = os.cli;
const logging = ntz.logging;
const types = ntz.types;
const bytes = types.bytes;

var global_status = ntz.Status{};
const debug_logger = logging.init();

const unicode = encoding.unicode;
const utf8 = unicode.utf8;

pub fn main() !u8 {
    // ////////////
    // Allocator //
    // ////////////

    var ally: std.mem.Allocator = undefined;

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

    defer {
        if (debug_allocator.deinit() != .ok)
            debug_logger.warn("memory leaked");
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
        debug_logger.with("error", err).err(msg);
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
    //        debug_logger.with("error", err).err(msg);
    //        return err;
    //    };

    //    //break :blk opts.clone(ally) catch |err| {
    //    //    const msg = "cannot finish options reading";
    //    //    debug_logger.with("error", err).err(msg);
    //    //    return err;
    //    //};

    //    break :blk opts;
    //};

    var opts = Options{ .allocator = ally };
    defer opts.deinit();

    var cmd: Options.Command = .{
        .allocator = ally,
        .logger = debug_logger,

        .id = build_options.name,
        .name = build_options.name,
        .version = build_options.version,
        .description = "print Unicode codepoints",

        .longDescription =
        \\Print a range of Unicode codepoints.
        ,

        .usage = "Usage: " ++ build_options.name ++ " [<options>]\n" ++
            "  or:  " ++ build_options.name ++ " [<options>] <last codepoint>\n" ++
            "  or:  " ++ build_options.name ++ " [<options>] <first codepoint> <last codepoint>\n",

        .copyright =
        \\Copyright (c) 2025 Miguel Angel Rivera Notararigo
        \\Released under the MIT License
        ,

        .action = Options.main,
    };

    defer cmd.deinit();

    try cmd.addOption(.{
        .id = "log_file",
        .flags = &.{"--log-file"},
        .env = "LOG_FILE",
        .config = "log-file",
        .help = "Use given file as log file",
        .placeholder = "file",
        .action = Options.cmdLogFile,
    });

    try cmd.addOption(.{
        .id = "log_format",
        .flags = &.{"--log-format"},
        .env = "LOG_FORMAT",
        .config = "log-format",
        .help = "Use given format as log encoding format",
        .placeholder = "format",
        .default = "ctxlog",
        .valid_values = &.{ "ctxlog", "json" },
        .action = Options.cmdLogFormat,
    });

    try cmd.addOption(.{
        .id = "log_level",
        .flags = &.{"--log-level"},
        .env = "LOG_LEVEL",
        .config = "log-level",
        .help = "Minimum severity for log records",
        .placeholder = "level",
        .valid_values = &.{ "DEBUG", "INFO", "WARN", "ERROR", "FATAL", "DISABLED" },
        .action = Options.cmdLogLevel,
    });

    try cmd.addOption(Options.Command.envFileOption);
    try cmd.addOption(Options.Command.helpOption);
    try cmd.addOption(Options.Command.versionOption);

    // codepoint subcommand //

    var cmdSub = try cmd.addCommand(
        build_options.name ++ ".codepoint",
        "codepoint",
        &.{ "c", "cp" },
        Options.main,
    );

    cmdSub.description = "Sub command example";
    cmdSub.env_prefix = "CODEPOINT_";
    cmdSub.config_prefix = "codepoint.";

    try cmdSub.addOption(.{
        .id = "first_codepoint",
        .flags = &.{ "-f", "--first-cp" },
        .env = "FIRST",
        .config = "first-codepoint",
        .help = "First codepoint",
        .placeholder = "codepoint",
        .action = Options.cmdFirstCp,
    });

    try cmdSub.addOption(.{
        .id = "last_codepoint",
        .flags = &.{ "-l", "--last-cp" },
        .env = "LAST",
        .config = "last-codepoint",
        .help = "Last codepoint",
        .placeholder = "codepoint",
        .action = Options.cmdLastCp,
    });

    try cmdSub.addOption(Options.Command.helpOption);

    // Load options //

    _ = cmd.fromOS(&opts) catch |err| {
        const msg = "cannot load option entries from the OS";
        debug_logger.with("error", err).err(msg);
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
                debug_logger.with("error", err).errf(ally, msg, .{name});
                return err;
            }

            break :file_blk cwd.createFile(name, .{}) catch |create_err| {
                const msg = "cannot create log file '{s}'";
                debug_logger.with("error", create_err).errf(ally, msg, .{name});
                return create_err;
            };
        };

        file.seekFromEnd(0) catch |err| {
            const msg = "cannot go to the end of the log file";
            debug_logger.with("error", err).err(msg);
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

    const log_encoder = LogEncoder{
        .format = opts.log.format,
        .ctxlog_enc = .{},
        .json_enc = .{},
    };

    // Logger //

    const logger = blk: {
        var logger = logging.initWith(log_writer, log_encoder, LogContext);
        if (!builtin.single_threaded) logger.mux = &log_mutex;
        break :blk logger.withSeverity(opts.log.level);
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

    logger.info("preparing buffer for the standart output");

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = io.stdout().writer(&stdout_buf);
    var stdout = &stdout_writer.interface;

    defer {
        logger.info("flushing the standart output buffer");
        stdout.flush() catch {};
        logger.info("flushed the standart output buffer");
    }

    logger.info("buffer for the standart output set");

    const utf8_logger = logger.withScope("utf8");

    for (opts.first_cp..opts.last_cp) |i| {
        if (status.isDone()) break;
        if (unicode.isSurrogateCharacter(i)) continue;

        var buf: [4]u8 = undefined;

        const want = try unicode.Codepoint.init(@intCast(i));
        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        utf8_logger.with("cp", got.value).with("str", buf[0..n]).debug("");
        try stdout.print("0x{X:<6} [{s}]\n", .{ got.value, buf[0..n] });
    }

    return 0;
}

// //////////
// Logging //
// //////////

const LogContext = struct {
    level: []const u8,
    msg: []const u8,
    @"error": ?anyerror,

    utf8: ?struct {
        cp: u21,
        str: []const u8,
    },
};

const LogEncoder = struct {
    const Self = @This();

    pub const Format = enum {
        ctxlog,
        json,
    };

    format: Format = .ctxlog,

    ctxlog_enc: ctxlog.Encoder,

    json_enc: struct {
        pub fn encode(_: @This(), writer: anytype, val: anytype) !void {
            var w = writer.stdWriter(&.{}).interface;

            var enc = std.json.Stringify{
                .writer = &w,
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

// //////////
// Options //
// //////////

const Options = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    first_cp: u21 = 0x20,
    last_cp: u21 = 0x30,
    //last_cp: u21 = 0x10FFFF,

    log: struct {
        file: []const u8 = "",
        format: LogEncoder.Format = .ctxlog,

        level: logging.Level = switch (builtin.mode) {
            .Debug => .debug,
            .ReleaseSafe => .warn,
            .ReleaseFast, .ReleaseSmall => .@"error",
        },
    } = .{},

    pub fn deinit(opts: Self) void {
        if (opts.log.file.len > 0) opts.allocator.free(opts.log.file);
    }

    pub fn clone(
        opts: Self,
        allocator: std.mem.Allocator,
    ) std.mem.Allocator.Error!Self {
        var new_opts = opts;
        new_opts.allocator = allocator;

        new_opts.log.file = if (opts.log.file.len > 0)
            try allocator.dupe(u8, opts.log.file)
        else
            "";

        return new_opts;
    }

    // //////
    // CLI //
    // //////

    pub const Command = cli.Command(logging.BasicLogger, Self);

    pub fn main(
        opts: *Self,
        cmd: Command,
        args: []const []const u8,
    ) !u8 {
        for (args) |arg| cmd.logger.debug(arg);

        switch (args.len) {
            0...1 => {},
            2 => try opts.cmdLastCp(opts.allocator, cmd, args[1]),

            else => {
                try opts.cmdFirstCp(opts.allocator, cmd, args[1]);
                try opts.cmdLastCp(opts.allocator, cmd, args[2]);
            },
        }

        return 0;
    }

    pub fn cmdFirstCp(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.logger.err("no first codepoint given");
            return error.MissingValue;
        }

        const fcp = std.fmt.parseInt(u21, value, 0) catch |err| {
            const msg = "invalid first codepoint '{s}'";
            cmd.logger.with("error", err).errf(arena, msg, .{value});
            return err;
        };

        if (fcp > opts.last_cp) {
            const msg = "first codepoint cannot be greater than last";
            cmd.logger.err(msg);
            return error.InvalidValue;
        }

        opts.first_cp = fcp;
    }

    pub fn cmdLastCp(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.logger.err("no last codepoint given");
            return error.MissingValue;
        }

        const lcp = std.fmt.parseInt(u21, value, 0) catch |err| {
            const msg = "invalid last codepoint '{s}'";
            cmd.logger.with("error", err).errf(arena, msg, .{value});
            return err;
        };

        if (lcp < opts.first_cp) {
            const msg = "last codepoint cannot be lower than first";
            cmd.logger.err(msg);
            return error.InvalidValue;
        }

        opts.last_cp = lcp + 1;
    }

    // Logging.

    pub fn cmdLogFile(
        opts: *Self,
        _: std.mem.Allocator,
        _: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) return;
        if (opts.log.file.len > 0) opts.allocator.free(opts.log.file);
        opts.log.file = try opts.allocator.dupe(u8, value);
    }

    pub fn cmdLogFormat(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.logger.err("no log format given");
            return error.EmptyValue;
        }

        if (bytes.equal(value, "ctxlog")) {
            opts.log.format = .ctxlog;
        } else if (bytes.equal(value, "json")) {
            opts.log.format = .json;
        } else {
            const msg = "invalid log format '{s}'";
            cmd.logger.errf(arena, msg, .{value});
            return error.InvalidValue;
        }
    }

    pub fn cmdLogLevel(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.logger.err("no log severity given");
            return error.EmptyValue;
        }

        opts.log.level = logging.Level.fromKey(value) catch |err| {
            const msg = "invalid log severity '{s}'";
            cmd.logger.with("error", err).errf(arena, msg, .{value});
            return err;
        };
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
                debug_logger.warn(msg);
                global_status.done();
            }
        },

        else => {},
    }
}
