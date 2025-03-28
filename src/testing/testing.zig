// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.testing`
//!
//! Testing utilities.

const std = @import("std");

const strings = @import("../types/strings.zig");

pub const allocator = std.testing.allocator;

pub const Error = error{
    Skip,
    UnexpectedResult,
};

/// Checks if given value is true.
pub fn expect(ok: bool) !void {
    if (!ok)
        return Error.UnexpectedResult;
}

/// Checks if given values are equal.
pub fn expectEql(got: anytype, want: @TypeOf(got)) !void {
    try std.testing.expectEqual(want, got);
}

/// Checks if given slices of bytes are equal.
pub fn expectEqlBytes(got: []const u8, want: []const u8) !void {
    try std.testing.expectEqualSlices(u8, want, got);
}

/// Checks if given slices are equal.
pub fn expectEqlSlcs(comptime T: type, got: []const T, want: []const T) !void {
    try std.testing.expectEqualSlices(T, want, got);
}

/// Checks if given strings are equal.
pub fn expectEqlStrs(got: []const u8, want: []const u8) !void {
    try std.testing.expectEqualStrings(want, got);
}

/// Checks if given error union matches .
pub fn expectErr(got: anytype, err: anyerror) !void {
    try std.testing.expectError(err, got);
}

/// Prints to stderr if the test runner supports it.
pub fn print(comptime format: []const u8, args: anytype) void {
    if (@inComptime()) {
        @compileError(std.fmt.comptimePrint(format, args));
    } else if (std.testing.backend_can_print) {
        std.debug.print(format, args);
    }
}

/// Makes the test runner to skip the test.
pub fn skip() !void {
    return error.SkipZigTest;
}
