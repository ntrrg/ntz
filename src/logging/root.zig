// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.logging`
//!
//! A logging API with support for multiple encoding formats, record severity,
//! scoping and type safety.

//const std = @import("std");

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
};

//pub const Logger = @import("logger.zig").Logger;

///// Creates a logger using the standard error as log writer.
//pub fn init(comptime encoder: anytype) Logger() {
//    return withWriter(
//        std.debug.getStderrMutex(),
//        std.io.getStdErr(),
//    );
//}
//
///// Creates a logger that logs nothing.
//pub fn noop() Logger("", void, 0) {
//    return .{ .writer = void{} };
//}
//
///// Creates a logger using the given writer as log writer.
//pub fn withEncoder(
//    encoder: anytype,
//) Logger("", @TypeOf(writer), encoder) {
//    return .{ .writer = writer, .mutex = mutex };
//}
//
///// Creates a logger using the given writer as log writer.
//pub fn withWriter(
//    mutex: ?*std.Thread.Mutex,
//    writer: anytype,
//) Logger("", @TypeOf(writer), encoder) {
//    return .{ .writer = writer, .mutex = mutex };
//}
//
///// Creates a logger using the given writer as log writer.
//pub fn withWriterAndEncoder(
//    mutex: ?*std.Thread.Mutex,
//    writer: anytype,
//    encoder: anytype,
//) Logger("", @TypeOf(writer), encoder) {
//    return .{ .writer = writer, .mutex = mutex };
//}
