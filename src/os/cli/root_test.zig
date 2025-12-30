// Copyright 2026 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");
const logging = ntz.logging;
const os = ntz.os;
const types = ntz.types;
const bytes = types.bytes;

const cli = os.cli;

test "ntz.os.cli" {
    const ally = testing.allocator;

    var opts = Options{
        .allocator = ally,
    };

    defer opts.deinit();
}

const Logger = logging.Logger(
    bytes.Buffer,
    logging.BasicEncoder,
    logging.BasicContext,
    "",
);

const Options = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    first_cp: u21 = 0x20,
    last_cp: u21 = 0x30,
    //last_cp: u21 = 0x10FFFF,

    log: struct {
        file: []const u8 = "",
        level: []const u8 = "ERROR",
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

    pub const Command = cli.Command(Logger, Self);

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
