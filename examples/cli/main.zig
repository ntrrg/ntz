// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const build_options = @import("build_options");

const builtin = @import("builtin");
const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const io = ntz.io;
const logging = ntz.logging;
const types = ntz.types;
const bytes = types.bytes;
const slices = types.slices;

const unicode = encoding.unicode;
const utf8 = unicode.utf8;

fn run(
    status: *ntz.Status,
    allocator: anytype,
    logger: anytype,
    opts: Options,
) !u8 {
    _ = allocator;

    logger.info("preparing buffer for the standart output");

    const std_out = io.stdOut();
    var bw = io.bufferedWriter(std_out.writer());

    defer {
        logger.info("flushing the standart output buffer");
        bw.flush() catch {};
        logger.info("flushed the standart output buffer");
    }

    const w = bw.writer().stdWriter();

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
        try std.fmt.format(w, "0x{X:<6} [{s}]\n", .{ got.value, buf[0..n] });
    }

    return 0;
}

// ////////////////////////////////////////////////////////////////////////////

var global_status = ntz.Status{};
const debug_logger = logging.init();

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

    // //////////
    // Options //
    // //////////

    const opts = blk: {
        var opts = Options{};

        var arena_ally = std.heap.ArenaAllocator.init(ally);
        defer arena_ally.deinit();
        const arena = arena_ally.allocator();

        const cli = initCli(arena, debug_logger);

        cli.fromEnv(&opts) catch |err| {
            const msg = "cannot read options from environment variables";
            debug_logger.with("error", err).err(msg);
            return err;
        };

        cli.fromArgs(&opts) catch |err| {
            const msg = "cannot read options from arguments";
            debug_logger.with("error", err).err(msg);
            return err;
        };

        break :blk opts.clone(ally) catch |err| {
            const msg = "cannot finish options reading";
            debug_logger.with("error", err).err(msg);
            return err;
        };
    };

    defer opts.deinit(ally);

    // //////////
    // Logging //
    // //////////

    // File //

    const log_file: std.fs.File = blk: {
        if (opts.log.file.len == 0) break :blk io.stdErr();

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

    var log_writer_ln = io.delimitedWriter(log_file.writer(), ally, "\n");

    defer {
        log_writer_ln.deinit();
        log_writer_ln.flush() catch {};
    }

    const log_writer = log_writer_ln.writer().stdWriter();

    // Mutex //

    var log_mutex: std.Thread.Mutex = if (opts.log.file.len > 0)
        std.Thread.Mutex{}
    else
        io.std_err_mux;

    // Encoder //

    const log_encoder = LogEncoder{
        .format = opts.log.format,
        .ctxlog_enc = .{},
        .json_enc = .{},
    };

    // Logger //

    const logger = blk: {
        var logger = logging.initCustom(
            log_writer,
            log_encoder,
            LogContext,
        );

        if (!builtin.single_threaded) logger.mutex = &log_mutex;

        break :blk logger.withSeverity(opts.log.level);
    };

    // /////////////
    // OS Signals //
    // /////////////

    var sa: std.posix.Sigaction = .{
        .handler = .{ .sigaction = signalHandler },
        .mask = std.posix.empty_sigset,
        .flags = std.posix.SA.RESTART,
    };

    std.posix.sigaction(std.posix.SIG.INT, &sa, null);
    std.posix.sigaction(std.posix.SIG.TERM, &sa, null);

    // ////////////////////////////////////////////////////////////////////////

    global_status.allocator = ally;
    defer global_status.deinit();

    const status = global_status.sub() catch |err| {
        const msg = "cannot setup status propagation";
        debug_logger.with("error", err).err(msg);
        return err;
    };

    return run(status, ally, logger, opts);
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
            try std.json.stringify(
                val,
                .{ .emit_null_optional_fields = false },
                writer,
            );
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
) callconv(.C) void {
    switch (sig) {
        std.posix.SIG.INT, std.posix.SIG.TERM => {
            const exit_code: u8 = 128 +| @as(u8, @intCast(sig));

            if (global_status.isDone()) {
                std.process.exit(exit_code);
            } else {
                const msg = "terminating program... try again to force exit";
                debug_logger.err(msg);
                global_status.done();
            }
        },

        else => {},
    }
}

// //////
// CLI //
// //////

const Options = struct {
    const Self = @This();

    first_cp: u21 = 0x20,
    last_cp: u21 = 0x10FFFF,

    log: struct {
        file: []const u8 = "",

        format: LogEncoder.Format = .ctxlog,

        level: logging.Level = switch (builtin.mode) {
            .Debug => .debug,
            .ReleaseSafe => .warn,
            .ReleaseFast, .ReleaseSmall => .@"error",
        },
    } = .{},

    pub fn deinit(opts: Self, allocator: anytype) void {
        allocator.free(opts.log.file);
    }

    pub fn clone(opts: Self, allocator: anytype) !Self {
        var new_opts = opts;
        new_opts.log.file = try allocator.dupe(u8, opts.log.file);
        return new_opts;
    }
};

fn CommandLineInterface(
    comptime ArenaAllocator: type,
    comptime Logger: type,
) type {
    return struct {
        const Self = @This();

        pub const Error = SetError || ArgsError || EnvError;

        arena: ArenaAllocator,
        logger: Logger,

        name: []const u8 = build_options.name,
        version: []const u8 = build_options.version,
        flags_prefix: []const u8 = "",
        env_prefix: []const u8 = "",

        const help_message =
            \\{[name]s} - print Unicode codepoints.
            \\
            \\Usage: {[name]s} [<options>]
            \\       {[name]s} [<options>] <last codepoint>
            \\       {[name]s} [<options>] <first codepoint> <last codepoint>
            \\
            \\Options:
            \\  --env=<file>
            \\    Read environment variables from <file>
            \\  -h, --help
            \\    Show this help message
            \\  --log-file=<file>
            \\    Use <file> as log file
            \\  --log-format=<format> (ctxlog*, json)
            \\    Use <format> as log encoding format
            \\  --log-level=<level> (DEBUG, INFO, WARN, ERROR, FATAL, DISABLED)
            \\    Minimum severity for log records
            \\  --version
            \\    Print version number
            \\
            \\  * = Default value.
            \\
            \\Environment variables:
            \\  - 'LOG_FILE' is a file where log records will be written.
            \\  - 'LOG_FORMAT' is the encoding format for log records.
            \\  - 'LOG_LEVEL' is the minimum severity for log records.
            \\
            \\Copyright (c) 2025 Miguel Angel Rivera Notararigo
            \\Released under the MIT License
        ;

        pub fn fromOS(cli: Self, opts: *Options) !void {
            cli.fromEnv(opts) catch |err| {
                const msg = "cannot read options from environment variables";
                cli.logger.with("error", err).err(msg);
                return err;
            };

            cli.fromArgs(opts) catch |err| {
                const msg = "cannot read options from arguments";
                cli.logger.with("error", err).err(msg);
                return err;
            };
        }

        // //////////
        // Setters //
        // //////////

        pub const SetError = error{
            InvalidValue,
            MissingValue,
        };

        pub fn setFirstCp(
            cli: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                cli.logger.err("no first codepoint given");
                return SetError.MissingValue;
            }

            const fcp = std.fmt.parseInt(u21, value, 0) catch |err| {
                const msg = "invalid first codepoint '{s}'";
                cli.logger.with("error", err).errf(cli.arena, msg, .{value});
                return err;
            };

            if (fcp > opts.last_cp) {
                const msg = "first codepoint cannot be greater than last";
                cli.logger.err(msg);
                return SetError.InvalidValue;
            }

            opts.first_cp = fcp;
        }

        pub fn setLastCp(
            cli: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                cli.logger.err("no last codepoint given");
                return SetError.MissingValue;
            }

            const lcp = std.fmt.parseInt(u21, value, 0) catch |err| {
                const msg = "invalid last codepoint '{s}'";
                cli.logger.with("error", err).errf(cli.arena, msg, .{value});
                return err;
            };

            if (lcp < opts.first_cp) {
                const msg = "last codepoint cannot be lower than first";
                cli.logger.err(msg);
                return SetError.InvalidValue;
            }

            opts.last_cp = lcp + 1;
        }

        // Logging.

        pub fn setLogFile(
            cli: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            opts.log.file = try cli.arena.dupe(u8, value);
        }

        pub fn setLogFormat(
            cli: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                cli.logger.err("no log format given");
                return SetError.MissingValue;
            }

            if (bytes.equal(value, "ctxlog")) {
                opts.log.format = .ctxlog;
            } else if (bytes.equal(value, "json")) {
                opts.log.format = .json;
            } else {
                const msg = "invalid log format '{s}'";
                cli.logger.errf(cli.arena, msg, .{value});
                return SetError.InvalidValue;
            }
        }

        pub fn setLogLevel(
            cli: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                cli.logger.err("no log severity given");
                return SetError.MissingValue;
            }

            opts.log.level = logging.Level.fromKey(value) catch |err| {
                const msg = "invalid log severity '{s}'";
                cli.logger.with("error", err).errf(cli.arena, msg, .{value});
                return err;
            };
        }

        // /////////////////////////
        // Command line arguments //
        // /////////////////////////

        pub const ArgsError = error{
            InvalidArg,
            InvalidFlagValue,
            MissingArgs,
            MissingFlag,
            MissingFlagValue,
            UnknowFlag,
        };

        pub fn fromArgs(cli: Self, opts: *Options) !void {
            const arena = cli.arena;
            const logger = cli.logger;

            const args = std.process.argsAlloc(arena) catch |err| {
                const msg = "cannot get command line arguments";
                logger.with("error", err).err(msg);
                return err;
            };

            defer std.process.argsFree(arena, args);

            try cli.fromArgsSlice(opts, args);
        }

        pub fn fromArgsIterator(cli: Self, opts: *Options, it: anytype) !void {
            const arena = cli.arena;
            const logger = cli.logger;

            var args: slices.Slice([]const u8) = .{};
            defer args.deinit(arena);

            var no_more_flags = false;

            try args.append(arena, try arena.dupe(u8, it.next() orelse ""));

            while (it.next()) |arg| {
                const is_flag = !no_more_flags and bytes.startsWith(arg, "-");

                if (!is_flag) {
                    try args.append(arena, try arena.dupe(u8, arg));
                    continue;
                }

                if (bytes.equal(arg, "--")) {
                    no_more_flags = true;
                    continue;
                }

                cli.fromFlag(opts, it, arg) catch |err| {
                    if (err != ArgsError.UnknowFlag) {
                        const msg = "cannot read flag '{s}'";
                        logger.with("error", err).errf(arena, msg, .{arg});
                        return err;
                    }

                    logger.errf(arena, "unknow flag '{s}'", .{arg});
                    return ArgsError.UnknowFlag;
                };
            }

            cli.fromArgsPos(opts, args.items()) catch |err| {
                const msg = "cannot read positional arguments";
                logger.with("error", err).err(msg);
                return err;
            };
        }

        pub fn fromArgsPos(
            cli: Self,
            opts: *Options,
            args: []const []const u8,
        ) !void {
            switch (args.len) {
                0...1 => {},
                2 => try cli.setLastCp(opts, args[1]),

                else => {
                    try cli.setFirstCp(opts, args[1]);
                    try cli.setLastCp(opts, args[2]);
                },
            }
        }

        pub fn fromArgsSlice(
            cli: Self,
            opts: *Options,
            s: []const []const u8,
        ) !void {
            var it = slices.iterator(s);
            try cli.fromArgsIterator(opts, &it);
        }

        pub fn fromFlag(
            cli: Self,
            opts: *Options,
            it: anytype,
            flag: []const u8,
        ) !void {
            const logger = cli.logger;
            const prefix = cli.flags_prefix;

            if (prefix.len > 0 and !bytes.startsWith(flag, prefix))
                return;

            const j = bytes.findAt(prefix.len, flag, '=');
            const has_value = if (j) |_| true else false;
            const name = flag[prefix.len .. j orelse flag.len];
            var value = if (j) |i| flag[i + 1 ..] else "";

            if (bytes.equalAny(name, &.{"--env"})) {
                if (!has_value) value = it.next() orelse "";

                if (value.len == 0) {
                    logger.err("no env file path given");
                    return ArgsError.MissingFlagValue;
                }

                try cli.fromEnvFile(opts, value);
            } else if (bytes.equalAny(name, &.{"--log-file"})) {
                if (!has_value) value = it.next() orelse "";
                try cli.setLogFile(opts, value);
            } else if (bytes.equalAny(name, &.{"--log-format"})) {
                if (!has_value) value = it.next() orelse "";
                try cli.setLogFormat(opts, value);
            } else if (bytes.equalAny(name, &.{"--log-level"})) {
                if (!has_value) value = it.next() orelse "";
                try cli.setLogLevel(opts, value);
            } else if (bytes.equalAny(name, &.{ "-h", "--help" })) {
                const w = io.stdOut().writer();
                const msg = help_message ++ "\n";
                try std.fmt.format(w, msg, .{ .name = cli.name });
                std.process.exit(0);
            } else if (bytes.equalAny(name, &.{"--version"})) {
                const w = io.stdOut().writer();
                try std.fmt.format(w, "{s}\n", .{cli.version});
                std.process.exit(0);
            } else {
                return ArgsError.UnknowFlag;
            }
        }

        // ////////////////////////
        // Environment variables //
        // ////////////////////////

        pub const EnvError = error{
            MissingEnvVar,
            InvalidValue,
            MissingValue,
        };

        pub fn fromEnv(cli: Self, opts: *Options) !void {
            const arena = cli.arena;
            const logger = cli.logger;

            var env = std.process.getEnvMap(arena) catch |err| {
                const msg = "cannot get environment variables";
                logger.with("error", err).err(msg);
                return err;
            };

            defer env.deinit();

            try cli.fromEnvMap(opts, env);
        }

        pub fn fromEnvFile(cli: Self, opts: *Options, env_file: []const u8) !void {
            const arena = cli.arena;
            const logger = cli.logger;

            const env_buf = std.fs.cwd().readFileAlloc(arena, env_file, 64 * 1024) catch |err| {
                const msg = "cannot read env file '{s}''";
                logger.with("error", err).errf(arena, msg, .{env_file});
                return err;
            };

            defer arena.free(env_buf);

            try cli.fromEnvString(opts, env_buf);
        }

        pub fn fromEnvMap(cli: Self, opts: *Options, env: anytype) !void {
            const prefix = cli.env_prefix;

            if (cli.envVar(env, prefix, "LOG_FILE")) |value|
                try cli.setLogFile(opts, value);

            if (cli.envVar(env, prefix, "LOG_FORMAT")) |value|
                try cli.setLogFormat(opts, value);

            if (cli.envVar(env, prefix, "LOG_LEVEL")) |value|
                try cli.setLogLevel(opts, value);
        }

        pub fn fromEnvString(cli: Self, opts: *Options, s: []const u8) !void {
            const arena = cli.arena;
            const logger = cli.logger;

            var env = std.process.EnvMap.init(arena);
            defer env.deinit();

            var ln: usize = 1;
            var it = std.mem.splitScalar(u8, s, '\n');

            while (it.next()) |line| : (ln += 1) {
                if (line.len == 0) continue;
                if (line[0] == '#') continue;

                const i_opt = bytes.find(line, '=');

                if (i_opt == null or i_opt.? == line.len - 1) {
                    const msg = "missing value for key '{s}' in line {d}";
                    logger.errf(arena, msg, .{ line, ln });
                    return EnvError.MissingValue;
                }

                const i = i_opt.?;
                const key = line[0..i];
                var value = line[i + 1 ..];

                if (value[0] == '"') {
                    if (value.len == 1 or value[value.len - 1] != '"') {
                        const msg = "unclosed quote for '{s}' in line {d}";
                        logger.errf(arena, msg, .{ key, ln });
                        return EnvError.InvalidValue;
                    }

                    value = value[1 .. value.len - 1];
                }

                env.put(key, value) catch |err| {
                    const msg = "cannot store variable '{s}' in line {d}";
                    logger.with("error", err).errf(arena, msg, .{ key, ln });
                    return err;
                };
            }

            try cli.fromEnvMap(opts, env);
        }

        fn envVar(
            cli: Self,
            env: anytype,
            prefix: []const u8,
            key: []const u8,
        ) ?[]const u8 {
            const arena = cli.arena;
            const logger = cli.logger;

            if (prefix.len == 0) return env.get(key);

            const _key = bytes.concat(arena, prefix, key) catch |err| {
                const msg = "cannot prefix environment variable key '{s}'";
                logger.with("error", err).fatalf(arena, 1, msg, .{key});
                return null;
            };

            return env.get(_key);
        }
    };
}

pub fn initCli(
    arena: anytype,
    logger: anytype,
) CommandLineInterface(@TypeOf(arena), @TypeOf(logger)) {
    return .{
        .arena = arena,
        .logger = logger,
    };
}
