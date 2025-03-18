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
            else => "",
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
        return error.InvalidSeverity;
    }
};

pub const Logger = @import("logger.zig").Logger;

/// Creates a logger using the standard error as output.
pub fn init(
    encoder: anytype,
    comptime Context: type,
) Logger(std.fs.File.Writer, @TypeOf(encoder), Context, "") {
    var l = initWithWriter(
        io.stdErr().writer(),
        encoder,
        Context,
    );

    l.mutex = &io.std_err_mux;
    return l;
}

/// Creates a logger using the given writer as output.
pub fn initWithWriter(
    writer: anytype,
    encoder: anytype,
    comptime Context: type,
) Logger(@TypeOf(writer), @TypeOf(encoder), Context, "") {
    return .{
        .writer = writer,
        .encoder = encoder,
    };
}

// ///////////////
// Debug logger //
// ///////////////

const DebugContext = struct { level: []const u8, msg: []const u8 };

const DebugEncoder = struct {
    const Self = @This();

    pub fn encode(_: Self, writer: anytype, val: DebugContext) !void {
        _ = try writer.write(val.level);
        _ = try writer.write(": ");
        _ = try writer.write(val.msg);
        _ = try writer.write("\n");
    }
};

pub fn debug() Logger(std.fs.File.Writer, DebugEncoder, DebugContext, "") {
    var l = initWithWriter(
        io.stdErr().writer(),
        DebugEncoder{},
        DebugContext,
    );

    l.mutex = &io.std_err_mux;
    return l.withSeverity(.debug);
}
