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

var global_status = ntz.Status{};
const debug_logger = logging.init();

pub fn main() !void {
    defer global_status.done();

    // ////////////
    // Allocator //
    // ////////////

    var ally: std.mem.Allocator = undefined;

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

    defer {
        if (debug_allocator.deinit() != .ok)
            debug_logger.err("memory leaked");
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

        const opr = initOptionsReader(arena, debug_logger);

        opr.fromEnv(&opts) catch |err| {
            const msg = "cannot read options from environment variables: {}";
            debug_logger.errf(arena, msg, .{err});
            return err;
        };

        opr.fromArgs(&opts) catch |err| {
            const msg = "cannot read options from arguments: {}";
            debug_logger.errf(arena, msg, .{err});
            return err;
        };

        break :blk try opts.clone(ally);
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
                const msg = "cannot open log file '{s}': {}";
                debug_logger.errf(ally, msg, .{ name, err });
                return err;
            }

            break :file_blk cwd.createFile(name, .{}) catch |create_err| {
                const msg = "cannot create log file '{s}': {}";
                debug_logger.errf(ally, msg, .{ name, create_err });
                return create_err;
            };
        };

        file.seekFromEnd(0) catch |err| {
            const msg = "cannot go to the end of the log file: {}";
            debug_logger.errf(ally, msg, .{err});
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

    // Context //

    const LogContext = struct {
        level: []const u8,
        msg: []const u8,

        utf8: ?struct {
            cp: u21,
            str: []const u8,
        },
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

    //return app(try global_status.sub(), logger, opts.first_cp, opts.last_cp);

    if (comptime builtin.single_threaded)
        return app(try global_status.sub(), logger, opts.first_cp, opts.last_cp);

    //var wg = std.Thread.WaitGroup{};

    //(try std.Thread.spawn(.{}, runWg, .{
    //    &wg,
    //    try global_status.sub(),
    //    ally,
    //    logger,
    //    opts.first_cp,
    //    opts.last_cp,
    //})).detach();

    //wg.wait();

    var pool: std.Thread.Pool = undefined;

    try pool.init(.{
        .allocator = ally,
        .n_jobs = null,
    });

    defer pool.deinit();

    var wg = std.Thread.WaitGroup{};

    pool.spawnWg(&wg, run, .{
        try global_status.sub(),
        ally,
        logger,
        opts.first_cp,
        opts.last_cp,
    });

    pool.waitAndWork(&wg);
}

fn run(
    status: *ntz.Status,
    allocator: anytype,
    logger: anytype,
    first_cp: u21,
    last_cp: u21,
) void {
    app(status, logger, first_cp, last_cp) catch |err| {
        logger.errf(allocator, "app finished with errors: {}", .{err});
    };
}

fn runWg(
    wg: *std.Thread.WaitGroup,
    status: *ntz.Status,
    allocator: anytype,
    logger: anytype,
    first_cp: u21,
    last_cp: u21,
) void {
    wg.start();
    defer wg.finish();
    run(status, allocator, logger, first_cp, last_cp);
}

// //////////
// Logging //
// //////////

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

// //////////
// Options //
// //////////

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

    pub fn init(allocator: anytype, logger: anytype) !Self {
        var arena_ally = std.heap.ArenaAllocator.init(allocator);
        defer arena_ally.deinit();
        const arena = arena_ally.allocator();

        const opts_reader = initOptionsReader(arena, logger);
        var opts = Self{};
        try opts_reader.fromOS(&opts);

        return opts.clone(allocator);
    }

    pub fn deinit(opts: Self, allocator: anytype) void {
        allocator.free(opts.log.file);
    }

    pub fn clone(opts: Self, allocator: anytype) !Self {
        var new_opts = opts;

        new_opts.log.file = try allocator.dupe(u8, opts.log.file);

        return new_opts;
    }
};

fn OptionsReader(
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
            \\      --env=<file>            Read environment variables from <file>
            \\  -h, --help                  Show this help message
            \\      --log-file=<file>       Use <file> as log file
            \\      --log-format=<format>   Use <format> as log encoding format (ctxlog*, json)
            \\      --log-level=<level>     Minimum severity for log records
            \\      --version               Print version number
            \\
            \\  * = Default value.
            \\
            \\Environment variables:
            \\  - 'LOG_FILE' determines where log records will be written.
            \\  - 'LOG_FORMAT' determines the encoding format for log records.
            \\  - 'LOG_LEVEL' determines the minimum severity for log records.
            \\
            \\Copyright (c) 2025 Miguel Angel Rivera Notararigo
            \\Released under the MIT License
        ;

        pub fn fromOS(opr: Self, opts: *Options) !void {
            opr.fromEnv(opts) catch |err| {
                const msg = "cannot read options from environment variables: {}";
                opr.logger.errf(opr.arena, msg, .{err});
                return err;
            };

            opr.fromArgs(opts) catch |err| {
                const msg = "cannot read options from arguments: {}";
                opr.logger.errf(opr.arena, msg, .{err});
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
            opr: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                opr.logger.err("no first codepoint given");
                return SetError.MissingValue;
            }

            const fcp = std.fmt.parseInt(u21, value, 0) catch |err| {
                const msg = "invalid first codepoint '{s}': {}";
                opr.logger.errf(opr.arena, msg, .{ value, err });
                return SetError.InvalidValue;
            };

            if (fcp > opts.last_cp) {
                const msg = "first codepoint cannot be greater than last codepoint";
                opr.logger.err(msg);
                return SetError.InvalidValue;
            }

            opts.first_cp = fcp;
        }

        pub fn setLastCp(
            opr: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                opr.logger.err("no last codepoint given");
                return SetError.MissingValue;
            }

            const lcp = std.fmt.parseInt(u21, value, 0) catch |err| {
                const msg = "invalid first codepoint '{s}': {}";
                opr.logger.errf(opr.arena, msg, .{ value, err });
                return SetError.InvalidValue;
            };

            if (lcp < opts.first_cp) {
                const msg = "last codepoint cannot be lower than first codepoint";
                opr.logger.err(msg);
                return SetError.InvalidValue;
            }

            opts.last_cp = lcp + 1;
        }

        pub fn setLogFile(
            opr: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                opr.logger.err("no log file path given");
                return SetError.MissingValue;
            }

            opts.log.file = try opr.arena.dupe(u8, value);
        }

        pub fn setLogFormat(
            opr: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                opr.logger.err("no log format given");
                return SetError.MissingValue;
            }

            if (bytes.equal(value, "ctxlog")) {
                opts.log.format = .ctxlog;
            } else if (bytes.equal(value, "json")) {
                opts.log.format = .json;
            } else {
                const msg = "invalid log format given: '{s}'";
                opr.logger.errf(opr.arena, msg, .{value});
                return SetError.InvalidValue;
            }
        }

        pub fn setLogLevel(
            opr: Self,
            opts: *Options,
            value: []const u8,
        ) !void {
            if (value.len == 0) {
                opr.logger.err("no log severity given");
                return SetError.MissingValue;
            }

            opts.log.level = logging.Level.fromKey(value) catch |err| {
                const msg = "invalid log severity given: '{s}'";
                opr.logger.errf(opr.arena, msg, .{value});
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

        pub fn fromArgs(opr: Self, opts: *Options) !void {
            const arena = opr.arena;
            const logger = opr.logger;

            const args = std.process.argsAlloc(arena) catch |err| {
                const msg = "cannot read command line arguments: {}";
                logger.errf(arena, msg, .{err});
                return err;
            };

            defer std.process.argsFree(arena, args);

            try opr.fromArgsSlice(opts, args);
        }

        pub fn fromArgsIterator(opr: Self, opts: *Options, it: anytype) !void {
            const arena = opr.arena;
            const logger = opr.logger;

            var args: slices.Slice([]const u8) = .{};
            defer args.deinit(arena);

            var no_more_flags = false;

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

                opr.fromFlag(opts, arg) catch |err| {
                    if (err != ArgsError.UnknowFlag) return err;
                    logger.errf(arena, "unknow flag '{s}'", .{arg});
                    return ArgsError.UnknowFlag;
                };
            }

            try opr.fromArgsPos(opts, args.items());
        }

        pub fn fromArgsPos(
            opr: Self,
            opts: *Options,
            args: []const []const u8,
        ) !void {
            switch (args.len) {
                0 => {},
                1 => try opr.setLastCp(opts, args[0]),

                else => {
                    try opr.setFirstCp(opts, args[0]);
                    try opr.setLastCp(opts, args[1]);
                },
            }
        }

        pub fn fromArgsSlice(
            opr: Self,
            opts: *Options,
            s: []const []const u8,
        ) !void {
            var it = slices.iterator(s);
            try opr.fromArgsIterator(opts, &it);
        }

        pub fn fromFlag(
            opr: Self,
            opts: *Options,
            arg: []const u8,
        ) !void {
            const logger = opr.logger;
            const prefix = opr.flags_prefix;

            if (prefix.len > 0 and !bytes.startsWith(arg, prefix))
                return;

            const name, const value = bytes.split(arg[prefix.len..], '=');

            if (matchFlag(.{ name, "--env" })) {
                if (value.len == 0) {
                    logger.err("no env file path given");
                    return ArgsError.MissingFlagValue;
                }

                try opr.fromEnvFile(opts, value);
            } else if (matchFlag(.{ name, "--log-file" })) {
                try opr.setLogFile(opts, value);
            } else if (matchFlag(.{ name, "--log-format" })) {
                try opr.setLogFormat(opts, value);
            } else if (matchFlag(.{ name, "--log-level" })) {
                try opr.setLogLevel(opts, value);
            } else if (matchFlag(.{ name, "-h", "--help" })) {
                const w = io.stdOut().writer();
                const msg = help_message ++ "\n";
                try std.fmt.format(w, msg, .{ .name = opr.name });
                std.process.exit(0);
            } else if (matchFlag(.{ name, "--version" })) {
                const w = io.stdOut().writer();
                try std.fmt.format(w, "{s}\n", .{opr.version});
                std.process.exit(0);
            } else {
                return ArgsError.UnknowFlag;
            }
        }

        fn matchFlag(values: anytype) bool {
            inline for (1..values.len) |i|
                if (bytes.equal(values[0], values[i]))
                    return true;

            return false;
        }

        // ////////////////////////
        // Environment variables //
        // ////////////////////////

        pub const EnvError = error{
            MissingEnvVar,
            InvalidValue,
            MissingValue,
        };

        pub fn fromEnv(opr: Self, opts: *Options) !void {
            const arena = opr.arena;
            const logger = opr.logger;

            var env = std.process.getEnvMap(arena) catch |err| {
                const msg = "cannot get environment variables: {}";
                logger.errf(arena, msg, .{err});
                return err;
            };

            defer env.deinit();

            try opr.fromEnvMap(opts, env);
        }

        pub fn fromEnvFile(opr: Self, opts: *Options, env_file: []const u8) !void {
            const arena = opr.arena;
            const logger = opr.logger;

            const env_buf = std.fs.cwd().readFileAlloc(arena, env_file, 64 * 1024) catch |err| {
                const msg = "cannot read env file '{s}': {}'";
                logger.errf(arena, msg, .{ env_file, err });
                return err;
            };

            defer arena.free(env_buf);

            try opr.fromEnvString(opts, env_buf);
        }

        pub fn fromEnvMap(opr: Self, opts: *Options, env: anytype) !void {
            const prefix = opr.env_prefix;

            if (opr.envVar(env, prefix, "LOG_FILE")) |value|
                try opr.setLogFile(opts, value);

            if (opr.envVar(env, prefix, "LOG_FORMAT")) |value|
                try opr.setLogFormat(opts, value);

            if (opr.envVar(env, prefix, "LOG_LEVEL")) |value|
                try opr.setLogLevel(opts, value);
        }

        pub fn fromEnvString(opr: Self, opts: *Options, s: []const u8) !void {
            const arena = opr.arena;
            const logger = opr.logger;

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
                    logger.errf(arena, msg, .{ key, ln });
                    return err;
                };
            }

            try opr.fromEnvMap(opts, env);
        }

        fn envVar(
            opr: Self,
            env: anytype,
            prefix: []const u8,
            key: []const u8,
        ) ?[]const u8 {
            const arena = opr.arena;
            const logger = opr.logger;

            if (prefix.len == 0) return env.get(key);

            const _key = bytes.concat(arena, prefix, key) catch |err| {
                const msg = "cannot prefix environment variable key '{s}': {}";
                logger.fatalf(arena, 1, msg, .{ key, err });
                return null;
            };

            return env.get(_key);
        }
    };
}

pub fn initOptionsReader(
    arena: anytype,
    logger: anytype,
) OptionsReader(@TypeOf(arena), @TypeOf(logger)) {
    return .{
        .arena = arena,
        .logger = logger,
    };
}

// //////
// App //
// //////

//const std = @import("std");

//const ntz = @import("ntz");
//const encoding = ntz.encoding;
const unicode = encoding.unicode;
const utf8 = unicode.utf8;
//const io = ntz.io;
//const status = ntz.status;

pub fn app(
    status: *ntz.Status,
    logger: anytype,
    first_cp: u21,
    last_cp: u21,
) !void {
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

    for (first_cp..last_cp) |i| {
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
}
