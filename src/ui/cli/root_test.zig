// Copyright 2026 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");
const logging = ntz.logging;
const types = ntz.types;
const bytes = types.bytes;
const ui = ntz.ui;

const cli = ui.cli;

test "ntz.os.cli" {
    const ally = testing.allocator;

    var opts = Options{};

    defer opts.deinit(ally);

    var log_buf = bytes.buffer(ally);
    defer log_buf.deinit();

    const log = logging.initWith(
        &log_buf,
        logging.BasicEncoder{},
        logging.BasicContext,
    ).withSeverity(.debug);

    const cmd = try Options.command(ally, log);
    defer ally.destroy(cmd);
    defer cmd.deinit();

    // Load options //

    var arena_ally = std.heap.ArenaAllocator.init(ally);
    //defer arena_ally.deinit(); // Don't deinit arena to check if load leaks.
    const arena = arena_ally.allocator();

    var entries: cli.Entries = .{};

    cmd.fromEnvString(arena, &entries, "LOG_LEVEL=\"ERROR\"") catch |err| {
        std.debug.print("{s}\n", .{log_buf.bytes()});
        return err;
    };

    cmd.fromArgsSlice(arena, &opts, &entries, &.{
        "numbers", "--log-file", "log.ctxlog",
    }) catch |err| {
        std.debug.print("{s}\n", .{log_buf.bytes()});
        return err;
    };

    const entries_want: []const cli.Entry = &.{
        .{ .from = .env, .command = "numbers", .key = "LOG_LEVEL", .value = "ERROR" },
        .{ .from = .flag, .command = "numbers", .key = "--log-file", .value = "log.ctxlog" },
        .{ .from = .argument, .command = "numbers", .key = "", .value = "numbers" },
    };

    try testing.expectEqual(entries_want.len, entries.len);

    for (entries.items(), entries_want) |got, want| {
        try testing.expectEqualDeep(want, got);
    }

    const exit_code = cmd.load(&arena_ally, &opts, entries.items()) catch |err| {
        std.debug.print("{s}\n", .{log_buf.bytes()});
        return err;
    };

    try testing.expectEqual(0, exit_code);
}

const Logger = logging.Logger(
    *bytes.Buffer,
    logging.BasicEncoder,
    logging.BasicContext,
    "",
);

const Options = struct {
    const Self = @This();

    first: usize = 0,
    last: usize = 10,
    interval: usize = 1,

    calc: struct {
        operation: enum { none, add, sub, mul, div } = .none,
    } = .{},

    log: struct {
        file: []const u8 = "",
        level: logging.Level = .@"error",
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

    pub const Command = cli.Command(Logger, Self);

    pub fn command(allocator: std.mem.Allocator, log: Logger) !*Command {
        const cmd_id = "numbers";

        const cmd = try allocator.create(Command);

        cmd.* = .{
            .allocator = allocator,
            .log = log,

            .id = cmd_id,
            .name = cmd_id,
            .version = "0.0.1",
            .description = "print a range of numbers",

            .longDescription =
            \\Print a range of numbers starting from <first number> and ending on
            \\<last number> with the given interval. This will not print more than 5
            \\numbers.
            ,

            .usage = "Usage: " ++ cmd_id ++ " [<options>] <last number>\n" ++
                "  or:  " ++ cmd_id ++ " [<options>] <last number> <interval>\n" ++
                "  or:  " ++ cmd_id ++ " [<options>] <first number> <last number> <interval>\n",

            .copyright =
            \\Copyright (c) 2026 Miguel Angel Rivera Notararigo
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
            .id = "log_level",
            .flags = &.{"--log-level"},
            .env = "LOG_LEVEL",
            .config = "log_level",
            .help = "Minimum severity for log records",
            .placeholder = "level",
            .valid_values = &.{ "debug", "info", "warn", "error", "fatal", "disabled" },
            .action = cmdLogLevel,
        });

        try cmd.addOption(Command.envFileOption);
        try cmd.addOption(Command.helpOption);
        try cmd.addOption(Command.versionOption);

        // calc subcommand //

        var cmdCalc = try cmd.addCommand(
            cmd_id ++ ".calc",
            "calc",
            &.{ "c", "clc" },
            main,
        );

        cmdCalc.description = "Do some math operations on the given range instead of just printing them";
        cmdCalc.env_prefix = "CALC_";

        try cmdCalc.addOption(.{
            .id = "first",
            .flags = &.{ "-f", "--first" },
            .env = "FIRST",
            .config = "first",
            .help = "First number",
            .placeholder = "number",
            .action = cmdFirst,
        });

        try cmdCalc.addOption(.{
            .id = "last",
            .flags = &.{ "-l", "--last" },
            .env = "LAST",
            .config = "last",
            .help = "Last number",
            .placeholder = "number",
            .action = cmdLast,
        });

        try cmdCalc.addOption(.{
            .id = "interval",
            .flags = &.{ "-i", "--interval" },
            .env = "INTERVAL",
            .config = "interval",
            .help = "Interval",
            .placeholder = "interval",
            .has_optional_value = true,
            .default = "2",
            .action = cmdInterval,
        });

        try cmdCalc.addOption(.{
            .id = "operation",
            .flags = &.{ "-o", "--operation", "--op" },
            .env = "OPERATION",
            .config = "operation",
            .help = "interval",
            .placeholder = "operation",

            .valid_values = &.{
                "add", "s", "+",
                "sub", "s", "-",
                "mul", "m", "*",
                "div", "d", "/",
            },

            .action = cmdOperation,
        });

        try cmdCalc.addOption(Command.helpOption);

        return cmd;
    }

    pub fn main(
        opts: *Self,
        cmd: Command,
        args: []const []const u8,
    ) !u8 {
        switch (args.len) {
            0...1 => {},
            2 => try opts.cmdLast(cmd.allocator, cmd, args[1]),

            3 => {
                try opts.cmdFirst(cmd.allocator, cmd, args[1]);
                try opts.cmdLast(cmd.allocator, cmd, args[2]);
            },

            4 => {
                try opts.cmdFirst(cmd.allocator, cmd, args[1]);
                try opts.cmdLast(cmd.allocator, cmd, args[2]);
                try opts.cmdInterval(cmd.allocator, cmd, args[3]);
            },

            else => {
                cmd.log.err("too many arguments");
                return 1;
            },
        }

        return 0;
    }

    pub fn cmdFirst(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.log.err("no first number given");
            return error.MissingValue;
        }

        const first_num = std.fmt.parseInt(usize, value, 0) catch |err| {
            const msg = "invalid first number '{s}'";
            cmd.log.with("error", err).errf(arena, msg, .{value});
            return err;
        };

        if (first_num > opts.last) {
            const msg = "first number cannot be greater than last";
            cmd.log.err(msg);
            return error.InvalidValue;
        }

        opts.first = first_num;
    }

    pub fn cmdLast(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.log.err("no last number given");
            return error.MissingValue;
        }

        const last_num = std.fmt.parseInt(usize, value, 0) catch |err| {
            const msg = "invalid last number '{s}'";
            cmd.log.with("error", err).errf(arena, msg, .{value});
            return err;
        };

        if (last_num < opts.first) {
            const msg = "last number cannot be lower than first";
            cmd.log.err(msg);
            return error.InvalidValue;
        }

        opts.last = last_num + 1;
    }

    pub fn cmdInterval(
        opts: *Self,
        arena: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.log.err("no interval given");
            return error.MissingValue;
        }

        const interval = std.fmt.parseInt(usize, value, 0) catch |err| {
            const msg = "invalid interval '{s}'";
            cmd.log.with("error", err).errf(arena, msg, .{value});
            return err;
        };

        if (interval < 1) {
            const msg = "interval cannot be lower than 1";
            cmd.log.err(msg);
            return error.InvalidValue;
        }

        opts.interval = interval;
    }

    pub fn cmdOperation(
        opts: *Self,
        _: std.mem.Allocator,
        cmd: Command,
        value: []const u8,
    ) !void {
        if (value.len == 0) {
            cmd.log.err("no operation given");
            return error.MissingValue;
        }

        opts.calc.operation = if (bytes.equalAny(value, &.{ "add", "a", "+" }))
            .add
        else if (bytes.equalAny(value, &.{ "sub", "s", "-" }))
            .sub
        else if (bytes.equalAny(value, &.{ "mul", "m", "*" }))
            .mul
        else if (bytes.equalAny(value, &.{ "div", "d", "/" }))
            .div
        else
            return error.InvalidValue;
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
};
