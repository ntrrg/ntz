// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const io = @import("root.zig");
const types = @import("../types/root.zig");
const errors = types.errors;

/// Creates a writer that only writes an arbitrary amount of bytes.
pub fn init(writer: anytype, comptime limit: usize) LimitedWriter(
    @TypeOf(writer),
    limit,
) {
    return .{ .w = writer };
}

/// A writer that only writes an arbitrary amount of bytes.
pub fn LimitedWriter(comptime Writer: type, comptime limit: usize) type {
    return struct {
        const Self = @This();

        pub const Error = WriterError;
        pub const WriterError = errors.From(Writer);

        w: Writer,
        count: usize = 0,

        /// Allows the writer to be reused, by setting its byte count to 0.
        pub fn reset(lw: *Self) void {
            lw.count = 0;
        }

        /// Writes an arbitrary amount of bytes.
        ///
        /// Once the writer reaches its limit, it will discard all byte from
        /// subsequent calls. It is possible to reuse the writer by calling the
        /// `.reset` method.
        pub fn write(lw: *Self, data: []const u8) WriterError!usize {
            if (data.len == 0) return data.len;
            if (lw.count >= limit) return data.len;

            const j = @min(limit - lw.count, data.len);
            const n = try lw.w.write(data[0..j]);
            lw.count += n;
            return data.len;
        }

        pub fn writer(lw: *Self) io.Writer(*Self, WriterError, write) {
            return .{ .writer = lw };
        }
    };
}
