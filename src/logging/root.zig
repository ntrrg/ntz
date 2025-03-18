// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.logging`
//!
//! A logging API with support for multiple encoding formats, severity level,
//! scoping and type safety.

const std = @import("std");

const io = @import("../io/root.zig");

pub const Logger = @import("logger.zig").Logger;

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
};

/// Creates a logger using the standard error as output.
pub fn init(
    encoder: anytype,
    comptime Context: type,
) Logger(std.fs.File.Writer, @TypeOf(encoder), Context, "") {
    return initWithWriter(
        &io.std_err_mux,
        io.stdErr().writer(),
        encoder,
        Context,
    );
}

/// Creates a logger using the given writer as output.
pub fn initWithWriter(
    mutex: ?*std.Thread.Mutex,
    writer: anytype,
    encoder: anytype,
    comptime Context: type,
) Logger(@TypeOf(writer), @TypeOf(encoder), Context, "") {
    return .{ .mutex = mutex, .writer = writer, .encoder = encoder };
}
