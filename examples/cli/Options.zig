// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const Self = @This();

const build_options = @import("build_options");

const builtin = @import("builtin");
const std = @import("std");

const ntz = @import("ntz");
const logging = ntz.logging;
const types = ntz.types;
const bytes = types.bytes;
const ui = ntz.ui;
const cli = ui.cli;

const _main = @import("main.zig");
const LogEncoder = _main.LogEncoder;

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

pub fn command(allocator: std.mem.Allocator, log: anytype) !*Command {
    const cmd = try allocator.create(Command);

    cmd.* = .{
        .allocator = allocator,
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

        .action = Self.main,
    };

    try cmd.addOption(.{
        .id = "log_file",
        .flags = &.{"--log-file"},
        .env = "LOG_FILE",
        .config = "log_file",
        .help = "Use given file as log file",
        .placeholder = "file",
        .action = cmdLogFile,
    });

    try cmd.addOption(.{
        .id = "log_format",
        .flags = &.{"--log-format"},
        .env = "LOG_FORMAT",
        .config = "log_format",
        .help = "Use given format as log encoding format",
        .placeholder = "format",
        .default = "ctxlog",
        .valid_values = &.{ "ctxlog", "json" },
        .action = cmdLogFormat,
    });

    try cmd.addOption(.{
        .id = "log_level",
        .flags = &.{"--log-level"},
        .env = "LOG_LEVEL",
        .config = "log_level",
        .help = "Minimum severity for log records",
        .placeholder = "level",
        .valid_values = &.{ "debug", "info", "warn", "error", "fatal", "disabled" },
        .action = cmdLogLevel,
    });

    try cmd.addOption(Command.configStructOption);
    try cmd.addOption(Command.envFileOption);
    try cmd.addOption(Command.helpOption);
    try cmd.addOption(Command.versionOption);

    // codepoint subcommand //

    var cmdSub = try cmd.addCommand(
        build_options.name ++ ".codepoint",
        "codepoint",
        &.{ "c", "cp" },
        Self.main,
    );

    cmdSub.description = "Sub command example";
    cmdSub.env_prefix = "CODEPOINT_";

    try cmdSub.addOption(.{
        .id = "first_codepoint",
        .flags = &.{ "-f", "--first-cp" },
        .env = "FIRST",
        .config = "first_codepoint",
        .help = "First codepoint",
        .placeholder = "codepoint",
        .action = cmdFirstCp,
    });

    try cmdSub.addOption(.{
        .id = "last_codepoint",
        .flags = &.{ "-l", "--last-cp" },
        .env = "LAST",
        .config = "last_codepoint",
        .help = "Last codepoint",
        .placeholder = "codepoint",
        .action = cmdLastCp,
    });

    try cmdSub.addOption(Command.helpOption);

    return cmd;
}

pub fn main(
    opts: *Self,
    cmd: Command,
    args: []const []const u8,
) !u8 {
    for (args) |arg| cmd.log.debug(arg);

    switch (args.len) {
        0...1 => {},
        2 => try opts.cmdLastCp(cmd.allocator, cmd, args[1]),

        else => {
            try opts.cmdFirstCp(cmd.allocator, cmd, args[1]);
            try opts.cmdLastCp(cmd.allocator, cmd, args[2]);
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
        cmd.log.err("no first codepoint given");
        return error.MissingValue;
    }

    const fcp = std.fmt.parseInt(u21, value, 0) catch |err| {
        const msg = "invalid first codepoint '{s}'";
        cmd.log.with("error", err).errf(arena, msg, .{value});
        return err;
    };

    if (fcp > opts.last_cp) {
        const msg = "first codepoint cannot be greater than last";
        cmd.log.err(msg);
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
        cmd.log.err("no last codepoint given");
        return error.MissingValue;
    }

    const lcp = std.fmt.parseInt(u21, value, 0) catch |err| {
        const msg = "invalid last codepoint '{s}'";
        cmd.log.with("error", err).errf(arena, msg, .{value});
        return err;
    };

    if (lcp < opts.first_cp) {
        const msg = "last codepoint cannot be lower than first";
        cmd.log.err(msg);
        return error.InvalidValue;
    }

    opts.last_cp = lcp + 1;
}

// Logging.

pub fn cmdLogFile(
    opts: *Self,
    _: std.mem.Allocator,
    cmd: Command,
    value: []const u8,
) !void {
    if (value.len == 0) return;
    if (opts.log.file.len > 0) cmd.allocator.free(opts.log.file);
    opts.log.file = try cmd.allocator.dupe(u8, value);
}

pub fn cmdLogFormat(
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
        const msg = "invalid log format '{s}'";
        cmd.log.errf(arena, msg, .{value});
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
        cmd.log.err("no log severity given");
        return error.EmptyValue;
    }

    opts.log.level = logging.Level.fromKey(value) catch |err| {
        const msg = "invalid log severity '{s}'";
        cmd.log.with("error", err).errf(arena, msg, .{value});
        return err;
    };
}
