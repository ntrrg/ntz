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
const status = ntz.status;
const types = ntz.types;
const bytes = types.bytes;

var global_state = status.State{};

pub fn main() !void {
    const debug_logger = logging.debug();

    // ////////////
    // Allocator //
    // ////////////

    var allocator: std.mem.Allocator = undefined;

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    allocator = switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };

    if (builtin.os.tag == .wasi) allocator = std.heap.wasm_allocator;

    // //////////
    // Options //
    // //////////

    //var opts_arena = std.heap.ArenaAllocator.init(allocator);
    //defer opts_arena.deinit();

    const opts = Options{
        .log = .{
            .file = "",
            .format = .ctxlog,
            .level = .debug,
        },
    };

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
                debug_logger.errf(allocator, msg, .{ name, err });
                return err;
            }

            break :file_blk cwd.createFile(name, .{}) catch |create_err| {
                const msg = "cannot create log file '{s}': {}";
                debug_logger.errf(allocator, msg, .{ name, create_err });
                return create_err;
            };
        };

        file.seekFromEnd(0) catch |err| {
            const msg = "cannot go to the end of the log file: {}";
            debug_logger.errf(allocator, msg, .{err});
            return err;
        };

        break :blk file;
    };

    defer log_file.close();

    // Writer //

    var log_writer_ln = io.delimitedWriter(log_file.writer(), allocator, "\n");

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
        var logger = logging.initWithWriter(
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

    if (comptime builtin.single_threaded)
        return run(global_state.sub(), logger);

    try run(global_state.sub(), logger);

    if (global_state.isDone()) {
        logger.err("terminating program... try again to force exit");
    }
}

// //////////
// Options //
// //////////

const Options = struct {
    log: LogOptions = .{},
};

//pub fn initOptions(allocator: anytype) Options {
//    var arena = std.heap.ArenaAllocator.init(allocator);
//    defer arena.deinit();
//
//    const logger = logging.init(ctxlog.Encoder{}, struct { msg: []const u8 });
//
//    var opts_reader: OptionsReader(@TypeOf(arena), @TypeOf(logger)) = .{
//        .arena = arena,
//        .logger = logger,
//    };
//
//    return .{ .arena = arena, .logger = logger };
//}
//
//fn OptionsReader(
//    comptime ArenaAllocator: type,
//    comptime Logger: type,
//) type {
//    return struct {
//        const Self = @This();
//
//        pub const Error = ArgsError;
//
//        arena: ArenaAllocator,
//        logger: Logger,
//
//        name: []const u8 = build_options.name,
//        version: []const u8 = build_options.version,
//        args_prefix: []const u8 = "",
//        env_prefix: []const u8 = "",
//
//        const help_message =
//            \\{[name]s} - print Unicode codepoints.
//            \\
//            \\Usage: {[name]s} [OPTIONS] DESTINATION SOURCE...
//            \\
//            \\Options:
//            \\  -c, --config=FILE     Use FILE as configuration file
//            \\      --env=FILE        Read environment variables from FILE
//            \\  -h, --help            Show this help message
//            \\      --log-file=FILE   Use FILE as log file
//            \\      --log-level=LVL   Minimum severity for log records
//            \\      --version         Print version number
//            \\
//            \\  * = Default value.
//            \\
//            \\Environment variables:
//            \\  - 'ENV_PREFIX' adds a prefix to every environmet variable name.
//            \\  - 'LOG_FILE' determines where log records will be written.
//            \\  - 'LOG_LEVEL' determines the minimum severity for log records.
//            \\
//            \\Configuration file:
//            \\  - log.file: file where log records will be written
//            \\  - log.level: minimum severity for log records
//            \\
//            \\Copyright (c) 2025 Miguel Angel Rivera Notararigo
//            \\Released under the MIT License
//        ;
//
//        pub const ArgsError = error{
//            MissingFlagValue,
//            UnknowFlag,
//        };
//
//        pub fn fromArgs(opts: *Self) !Options {
//            const arena = &opts.arena;
//            const log = &opts.logger;
//
//            var args_it = std.process.argsWithAllocator(arena) catch |err| {
//                log.errf(arena, "cannot read command line arguments: {}", .{err});
//                return err;
//            };
//
//            defer args_it.deinit();
//
//            _ = args_it.next() orelse unreachable;
//            return opts.fromArgsIterator(&args_it);
//        }
//
//        pub fn fromArgsIterator(opts: *Self, it: anytype) !void {
//            const arena = &opts.arena;
//            const log = &opts.logger;
//            const prefix = opts.args_prefix;
//
//            var no_more_flags = false;
//
//            while (it.next()) |raw_arg| {
//                const arg: []const u8 = std.mem.trim(u8, raw_arg, " \n\t");
//                //if (arg.len == 0) continue;
//
//                const is_flag = !no_more_flags and bytes.startsWith(arg, "-");
//
//                if (!is_flag) {
//                    // Use arguments here.
//                    continue;
//                }
//
//                if (bytes.equal(arg, "--")) {
//                    no_more_flags = true;
//                    continue;
//                }
//
//                if (prefix.len > 0 and !bytes.startsWith(arg, prefix))
//                    continue;
//
//                const arg_name, const arg_val = bytes.split(
//                    arg[prefix.len..],
//                    '=',
//                );
//
//                if (bytes.equalAny(arg_name, &.{ "-c", "--config" })) {
//                    const config_file = if (arg_val.len > 0)
//                        arg_val
//                    else
//                        it.next() orelse "";
//
//                    if (config_file.len == 0) {
//                        log.err("no file path given to config flag");
//                        return ArgsError.MissingFlagValue;
//                    }
//
//                    //try opts.fromConfigFile(config_file);
//                } else if (bytes.equal(arg_name, "--env")) {
//                    const env_file = if (arg_val.len > 0)
//                        arg_val
//                    else
//                        it.next() orelse "";
//
//                    if (env_file.len == 0) {
//                        log.err("no file path given to env flag");
//                        return ArgsError.MissingFlagValue;
//                    }
//
//                    try opts.fromEnvFile(env_file);
//                } else if (bytes.equalAny(arg_name, &.{ "-h", "--help" })) {
//                    const w = io.stdOut().writer();
//                    const msg = help_message ++ "\n";
//                    try std.fmt.format(w, msg, .{ .name = opts.name });
//                    std.process.exit(0);
//                } else if (bytes.equal(arg_name, "--version")) {
//                    const w = io.stdOut().writer();
//                    try std.fmt.format(w, "{s}\n", .{opts.version});
//                    std.process.exit(0);
//                } else {
//                    log.errf(arena, "unknow flag '{s}'", .{arg});
//                    return ArgsError.UnknowFlag;
//                }
//            }
//        }
//
//        pub fn fromEnv(opts: *Self) !void {
//            const arena = &opts.arena;
//            const log = &opts.logger;
//
//            var env = std.process.getEnvMap(arena) catch |err| {
//                log.errf(arena, "cannot get environment variables: {}", .{err});
//                return err;
//            };
//
//            defer env.deinit();
//
//            try opts.fromEnvMap(env);
//        }
//
//        pub fn fromEnvFile(opts: *Self, env_file: []const u8) !void {
//            const arena = &opts.arena;
//            const log = &opts.logger;
//
//            const env_buf = std.fs.cwd().readFileAlloc(arena, env_file, 64 * 1024) catch |err| {
//                log.errf(arena, "cannot read env file '{s}': {}'", .{ env_file, err });
//                return err;
//            };
//
//            defer ally.free(env_buf);
//
//            try self.fromEnvString(ally, env_buf);
//        }
//
//        pub fn fromEnvMap(self: *Self, ally: mem.Allocator, env: anytype) !void {
//            const prefix = self.env_prefix;
//
//            // Destination:
//
//            var destination: []const u8 = "";
//
//            const dest_key = try envKey(ally, prefix, "DESTINATION");
//            defer if (prefix.len > 0) ally.free(dest_key);
//            destination = env.get(dest_key) orelse "";
//
//            // Sources:
//
//            var sources: [1][]const u8 = .{""};
//            var source: []const u8 = "";
//
//            const src_key = try envKey(ally, prefix, "SOURCE");
//            defer if (prefix.len > 0) ally.free(src_key);
//            source = env.get(src_key) orelse "";
//            if (source.len > 0) sources[0] = source;
//
//            // Set new values:
//
//            try self.fromValues(ally, .{
//                .destination = if (destination.len > 0) destination else null,
//                .sources = if (source.len > 0) sources[0..] else null,
//            });
//        }
//
//        pub fn fromEnvString(self: *Self, ally: mem.Allocator, s: []const u8) !void {
//            var env = process.EnvMap.init(ally);
//            defer env.deinit();
//
//            var ln: usize = 1;
//            var it = mem.splitScalar(u8, s, '\n');
//
//            while (it.next()) |line| : (ln += 1) {
//                if (line.len == 0) continue;
//                if (line[0] == '#') continue;
//
//                const i_opt = mem.indexOfScalar(u8, line, '=');
//
//                if (i_opt == null or i_opt.? == line.len - 1) {
//                    log.err("missing value for key '{s}' in line {d}", .{ line, ln });
//                    return Error.MissingEnvValue;
//                }
//
//                const i = i_opt.?;
//                const key = line[0..i];
//                var val = line[i + 1 ..];
//
//                if (val[0] == '"') {
//                    if (val.len == 1 or val[val.len - 1] != '"') {
//                        log.err("unclosed quote for '{s}' in line {d}", .{ key, ln });
//                        return Error.UnclosedQuote;
//                    }
//
//                    val = val[1 .. val.len - 1];
//                }
//
//                env.put(key, val) catch |err| {
//                    log.err("cannot store variable '{s}' in line {d}", .{ key, ln });
//                    return err;
//                };
//            }
//
//            try self.fromEnvMap(ally, env);
//        }
//
//        pub fn fromOS(self: *Self, ally: mem.Allocator) !void {
//            self.fromEnv(ally) catch |err| {
//                log.err("cannot get options from environment variables: {}", .{err});
//                return err;
//            };
//
//            self.fromArgs(ally) catch |err| {
//                log.err("cannot get options from arguments: {}", .{err});
//                return err;
//            };
//        }
//    };
//}

// //////////
// Logging //
// //////////

const LogOptions = struct {
    file: []const u8 = "",

    format: LogEncoder.Format = .ctxlog,

    level: logging.Level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .warn,
        .ReleaseFast, .ReleaseSmall => .@"error",
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

            if (global_state.isDone()) {
                std.process.exit(exit_code);
            } else {
                global_state.done();
            }
        },

        else => {},
    }
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

pub fn run(
    state: status.State,
    logger: anytype,
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

    const utf8_log = logger.withScope("utf8");

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
}
