// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const io = @import("root.zig");
const types = @import("../types/root.zig");
const errors = types.errors;

/// Creates a writer that counts how many times it writes and how many bytes it
/// writes.
pub fn init(writer: anytype) CountingWriter(@TypeOf(writer)) {
    return .{ .w = writer };
}

/// A writer that counts how many times it writes and how many bytes it writes.
pub fn CountingWriter(comptime Writer: type) type {
    return struct {
        const Self = @This();

        pub const Error = WriterError;
        pub const WriterError = errors.From(Writer);

        w: Writer,

        /// Writes count.
        write_count: u64 = 0,

        /// Bytes written.
        byte_count: u64 = 0,

        /// Sets its counters to 0.
        pub fn reset(cw: *Self) void {
            cw.write_count = 0;
            cw.byte_count = 0;
        }

        /// Counts how many times `.write` is called on the underlying writer
        /// and how many bytes have been written.
        pub fn write(cw: *Self, data: []const u8) WriterError!usize {
            const n = try cw.w.write(data);
            cw.write_count += 1;
            cw.byte_count += n;
            return n;
        }

        pub fn writer(cw: *Self) io.Writer(*Self, WriterError, write) {
            return .{ .writer = cw };
        }
    };
}
