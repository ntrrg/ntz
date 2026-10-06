// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const Self = @This();

const build_options = @import("build_options");

const builtin = @import("builtin");
const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const logging = ntz.logging;
const types = ntz.types;
const bytes = types.bytes;
const ui = ntz.ui;
const cli = ui.cli;

const codepoints = @import("codepoints.zig");

subcommand: enum { main, codepoint } = .main,

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

pub fn deinit(opts: Self, allocator: std.mem.Allocator) void {
    if (opts.log.file.len > 0) allocator.free(opts.log.file);
}

pub fn clone(
    opts: Self,
    allocator: std.mem.Allocator,
) std.mem.Allocator.Error!Self {
    var new_opts = opts;

    if (opts.log.file.len > 0)
        new_opts.log.file = try allocator.dupe(u8, opts.log.file);

    return new_opts;
}

// //////
// CLI //
// //////

pub const Command = cli.Command(Self);

pub fn command(
    io: std.Io,
    allocator: std.mem.Allocator,
    status: *ntz.Status,
    log: ntz.logging.DefaultLogger,
) !*Command {
    const cmd = try allocator.create(Command);

    cmd.* = .{
        .io = io,
        .allocator = allocator,
        .status = status,
        .log = log,

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

        .action = Self.cliMain,
    };

    try cmd.addOption(.{
        .id = "log_file",
        .flags = &.{"--log-file"},
        .env = "LOG_FILE",
        .help = "Use given file as log file",
        .placeholder = "file",
        .action = cliLogFile,
    });

    try cmd.addOption(.{
        .id = "log_format",
        .flags = &.{"--log-format"},
        .env = "LOG_FORMAT",
        .help = "Use given format as log encoding format",
        .placeholder = "format",
        .default = "ctxlog",
        .valid_values = &.{ "ctxlog", "json" },
        .action = cliLogFormat,
    });

    try cmd.addOption(.{
        .id = "log_level",
        .flags = &.{"--log-level"},
        .env = "LOG_LEVEL",
        .help = "Minimum severity for log records",
        .placeholder = "level",
        .valid_values = &.{ "debug", "info", "warn", "error", "fatal", "disabled" },
        .action = cliLogLevel,
    });

    try cmd.addOption(Command.envFileOption);
    try cmd.addOption(Command.helpOption);
    try cmd.addOption(Command.versionOption);

    // codepoint subcommand //

    var cmdSub = try cmd.addCommand(
        build_options.name ++ ".codepoint",
        "codepoint",
        &.{ "c", "cp" },
        Self.cliCodepoint,
    );

    cmdSub.description = "Sub command example";
    cmdSub.env_prefix = "CODEPOINT_";

    try cmdSub.addOption(.{
        .id = "first_codepoint",
        .flags = &.{ "-f", "--first-cp" },
        .env = "FIRST",
        .help = "First codepoint",
        .placeholder = "codepoint",
        .action = cliCodepointFirst,
    });

    try cmdSub.addOption(.{
        .id = "last_codepoint",
        .flags = &.{ "-l", "--last-cp" },
        .env = "LAST",
        .help = "Last codepoint",
        .placeholder = "codepoint",
        .is_required = true,
        .action = cliCodepointLast,
    });

    try cmdSub.addOption(Command.helpOption);

    return cmd;
}

fn cliMain(
    opts: *Self,
    arena: std.mem.Allocator,
    cmd: Command,
    args: []const []const u8,
) !void {
    opts.subcommand = .main;

    switch (args.len) {
        0...1 => {},
        2 => try opts.cliCodepointLast(arena, cmd, args[1]),

        else => {
            try opts.cliCodepointFirst(arena, cmd, args[1]);
            try opts.cliCodepointLast(arena, cmd, args[2]);
        },
    }
}

fn cliCodepoint(
    opts: *Self,
    _: std.mem.Allocator,
    _: Command,
    _: []const []const u8,
) !void {
    opts.subcommand = .codepoint;
}

fn cliCodepointFirst(
    opts: *Self,
    arena: std.mem.Allocator,
    cmd: Command,
    value: []const u8,
) !void {
    if (value.len == 0) {
        cmd.log.err("no first codepoint given");
        return error.MissingValue;
    }

    const fcp = std.fmt.parseInt(u21, value, 0) catch |err| {
        const msg = "invalid first codepoint '{s}'";
        cmd.log.withError(err).errf(arena, msg, .{value});
        return err;
    };

    if (fcp > opts.last_cp) {
        cmd.log.err("first codepoint cannot be greater than last");
        return error.InvalidValue;
    }

    opts.first_cp = fcp;
}

fn cliCodepointLast(
    opts: *Self,
    arena: std.mem.Allocator,
    cmd: Command,
    value: []const u8,
) !void {
    if (value.len == 0) {
        cmd.log.err("no last codepoint given");
        return error.MissingValue;
    }

    const lcp = std.fmt.parseInt(u21, value, 0) catch |err| {
        const msg = "invalid last codepoint '{s}'";
        cmd.log.withError(err).errf(arena, msg, .{value});
        return err;
    };

    if (lcp < opts.first_cp) {
        cmd.log.err("last codepoint cannot be lower than first");
        return error.InvalidValue;
    }

    opts.last_cp = lcp + 1;
}

// //////////
// Logging //
// //////////

pub const LogContext = struct {
    level: []const u8,
    msg: []const u8,
    @"error": ?anyerror,
    utf8: ?codepoints.LogContext,
};

pub const LogEncoder = struct {
    pub const Format = enum {
        ctxlog,
        json,
    };

    format: Format = .ctxlog,

    ctxlog_enc: ctxlog.Encoder,

    json_enc: struct {
        pub fn encode(_: @This(), writer: *std.Io.Writer, val: anytype) !void {
            var enc = std.json.Stringify{
                .writer = writer,
                .options = .{ .emit_null_optional_fields = false },
            };

            try enc.write(val);
        }
    },

    pub fn encode(e: @This(), writer: *std.Io.Writer, val: anytype) !void {
        switch (e.format) {
            .ctxlog => try e.ctxlog_enc.encode(writer, val),
            .json => try e.json_enc.encode(writer, val),
        }
    }
};

fn cliLogFile(
    opts: *Self,
    _: std.mem.Allocator,
    cmd: Command,
    value: []const u8,
) !void {
    if (value.len == 0) {
        cmd.log.info("using stdout as log file");
    }

    opts.log.file = value;
}

fn cliLogFormat(
    opts: *Self,
    arena: std.mem.Allocator,
    cmd: Command,
    value: []const u8,
) !void {
    if (value.len == 0) {
        cmd.log.err("no log format given");
        return error.EmptyValue;
    }

    if (bytes.equal(value, "ctxlog")) {
        opts.log.format = .ctxlog;
    } else if (bytes.equal(value, "json")) {
        opts.log.format = .json;
    } else {
        cmd.log.errf(arena, "invalid log format '{s}'", .{value});
        return error.InvalidValue;
    }
}

fn cliLogLevel(
    opts: *Self,
    arena: std.mem.Allocator,
    cmd: Command,
    value: []const u8,
) !void {
    if (value.len == 0) {
        cmd.log.err("no log severity given");
        return error.EmptyValue;
    }

    opts.log.level = logging.Level.fromKey(value) catch |err| {
        const msg = "invalid log severity '{s}'";
        cmd.log.withError(err).errf(arena, msg, .{value});
        return err;
    };
}
