// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

/// Creates a writable stream using a custom type.
pub fn init(
    writer: anytype,
    comptime Error: type,
    comptime write_fn: fn (w: @TypeOf(writer), data: []const u8) Error!usize,
) Writer(@TypeOf(writer), Error, write_fn) {
    return .{ .writer = writer };
}

/// A common interface for writable streams.
pub fn Writer(
    comptime T: type,
    comptime WriteError: type,
    comptime write_fn: fn (w: T, data: []const u8) WriteError!usize,
) type {
    return struct {
        const Self = @This();
        pub const Error = WriteError;

        writer: T,

        /// Writes the given data and returns the number of bytes processed.
        pub fn write(w: Self, data: []const u8) Error!usize {
            return write_fn(w.writer, data);
        }

        pub fn stdWriter(w: Self) std.io.Writer(Self, Error, write) {
            return .{ .context = .{ .writer = w } };
        }
    };
}
