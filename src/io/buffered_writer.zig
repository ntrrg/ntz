// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const io = @import("root.zig");
const types = @import("../types/root.zig");
const bytes = types.bytes;
const errors = types.errors;

/// Creates a writer that actually writes once its buffer has been filled.
pub fn init(writer: anytype) BufferedWriter(@TypeOf(writer), 4096) {
    return .{ .w = writer };
}

/// Creates a buffered writer with a specific size.
pub fn initWithSize(writer: anytype, comptime size: usize) BufferedWriter(
    @TypeOf(writer),
    size,
) {
    return .{ .w = writer };
}

/// A writer that actually writes once its buffer has been filled.
pub fn BufferedWriter(
    comptime Writer: type,
    comptime size: usize,
) type {
    return struct {
        const Self = @This();

        pub const Error = WriterError;
        pub const WriterError = errors.From(Writer);

        w: Writer,
        buf: [size]u8 = undefined,
        end: usize = 0,

        /// Writes any buffered bytes to the underlying writer and restores the
        /// buffer to its full capacity.
        pub fn flush(bw: *Self) WriterError!void {
            if (bw.end == 0) return;
            _ = try bw.w.write(bw.buf[0..bw.end]);
            bw.end = 0;
        }

        /// Writes bytes into a buffer until it is full.
        ///
        /// Use the `.flush` method for writing remaining bytes.
        pub fn write(bw: *Self, data: []const u8) WriterError!usize {
            var i: usize = 0;

            while (i < data.len) {
                const n = bytes.copy(bw.buf[bw.end..], data[i..]);
                bw.end += n;
                if (bw.end == size) try bw.flush();
                i += n;
            }

            return data.len;
        }

        pub fn writer(dw: *Self) io.Writer(*Self, WriterError, write) {
            return .{ .writer = dw };
        }
    };
}
