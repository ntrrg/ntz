// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.logging`
//!
//! A logging API with support for multiple encoding formats, severity level,
//! scoping and type safety.

const std = @import("std");

const io = @import("../io/root.zig");
const types = @import("../types/root.zig");
const bytes = types.bytes;

/// Represents the severity of a logging record.
pub const Level = enum {
    const Self = @This();

    /// Records intended to be read by developers.
    debug,

    /// Verbose records about the state of the program.
    info,

    /// Problems that doesn't interrupt the procedure execution.
    warn,

    /// Problems that interrupt the procedure execution.
    @"error",

    /// Problems that interrupt the program execution.
    fatal,

    /// Used to disable logging.
    disabled,

    pub fn key(lvl: Self) []const u8 {
        return switch (lvl) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .@"error" => "ERROR",
            .fatal => "FATAL",
            .disabled => "",
        };
    }

    pub const FromKeyError = error{
        InvalidSeverity,
    };

    pub fn fromKey(key_text: []const u8) FromKeyError!Self {
        if (bytes.equal(key_text, "DEBUG")) return .debug;
        if (bytes.equal(key_text, "INFO")) return .info;
        if (bytes.equal(key_text, "WARN")) return .warn;
        if (bytes.equal(key_text, "ERROR")) return .@"error";
        if (bytes.equal(key_text, "FATAL")) return .fatal;
        if (bytes.equal(key_text, "DISABLED")) return .disabled;
        return error.InvalidSeverity;
    }
};

pub const Logger = @import("logger.zig").Logger;

/// Creates a simple logger using the standard error as output.
pub fn init() BasicLogger {
    var l = initWith(
        io.stderr(),
        BasicEncoder{},
        BasicContext,
    );

    l.mux = &io.stderr_mux;
    return l.withSeverity(.debug);
}

/// Creates a logger using the given writer as output.
pub fn initWith(
    writer: anytype,
    encoder: anytype,
    comptime Context: type,
) Logger(@TypeOf(writer), @TypeOf(encoder), Context, "") {
    return .{
        .w = writer,
        .enc = encoder,
    };
}

// ///////////////
// Basic logger //
// ///////////////

pub const BasicContext = struct {
    level: []const u8,
    msg: []const u8,
    @"error": ?anyerror,
};

pub const BasicEncoder = struct {
    const Self = @This();

    pub fn encode(_: Self, writer: anytype, value: BasicContext) !void {
        _ = try writer.write("[");
        _ = try writer.write(value.level);
        _ = try writer.write("] ");
        _ = try writer.write(value.msg);

        if (value.@"error") |err| {
            _ = try writer.write(": ");
            _ = try writer.write(@errorName(err));
        }
    }
};

pub const BasicLogger = Logger(std.fs.File, BasicEncoder, BasicContext, "");
