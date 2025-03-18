// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const io = @import("root.zig");
const types = @import("../types/root.zig");
const bytes = types.bytes;
const errors = types.errors;

/// Creates a writer that actually writes when it finds an arbitrary delimiter.
///
/// Using an empty string as delimiter will call `.write` in the underlying
/// writer for every byte passed to this writer.
///
/// Use the `.deinit` method to release resources.
pub fn init(
    writer: anytype,
    allocator: anytype,
    delimiter: []const u8,
) DelimitedWriter(@TypeOf(writer), @TypeOf(allocator)) {
    return .{
        .w = writer,
        .buf = bytes.buffer(allocator),
        .delim = delimiter,
    };
}

/// A writer that actually writes when it finds an arbitrary delimiter.
pub fn DelimitedWriter(comptime Writer: type, comptime Allocator: type) type {
    return struct {
        const Self = @This();

        pub const Error = WriteError || AllocatorError || WriterError;
        pub const WriterError = errors.From(Writer);
        pub const AllocatorError = errors.From(Allocator);

        const Buffer = bytes.Buffer(Allocator);

        w: Writer,
        buf: Buffer,
        delim: []const u8,

        /// If false, the delimiter will not be written.
        include: bool = true,

        pub fn deinit(dw: *Self) void {
            dw.buf.deinit();
        }

        /// Writes any buffered bytes to the underlying writer and restores the
        /// buffer to its full capacity.
        pub fn flush(dw: *Self) WriterError!void {
            const data = dw.buf.bytes();
            if (data.len == 0) return;
            _ = try dw.w.write(data);
            dw.buf.clear();
        }

        pub const WriteError = AllocatorError || WriterError;

        /// Writes bytes into a buffer until it finds the delimiter.
        ///
        /// Whether the delimiter is written or not along with buffered bytes
        /// is configurable via the `.include` property.
        ///
        /// Bytes after the delimiter will not be written until another
        /// instance of the delimiter is found, use the `.flush` method for
        /// writing remaining bytes.
        pub fn write(dw: *Self, data: []const u8) WriteError!usize {
            if (data.len == 0) return 0;
            if (dw.delim.len == 1) return dw.scalar(data, dw.delim[0]);
            if (dw.delim.len > 1) return dw.sequence(data);

            for (0..data.len) |i| _ = try dw.w.write(data[i .. i + 1]);
            return data.len;
        }

        fn scalar(dw: *Self, data: []const u8, delim: u8) WriteError!usize {
            var i: usize = 0;

            while (bytes.findAt(i, data, delim)) |_j| {
                var j = _j;
                if (dw.include) j += 1;

                _ = try dw.buf.write(data[i..j]);
                try dw.flush();

                i = j;
                if (!dw.include) i += 1;
            }

            if (i < data.len) _ = try dw.buf.write(data[i..]);
            return data.len;
        }

        fn sequence(dw: *Self, data: []const u8) WriteError!usize {
            var i: usize = 0;

            // Check if the delimiter is partially stored in the buffer.
            if (dw.missingDelimiterBytes()) |missing| {
                if (missing > data.len) {
                    _ = try dw.buf.write(data);
                    return data.len;
                }

                if (bytes.endsWith(dw.delim, data[0..missing])) {
                    if (dw.include) {
                        _ = try dw.buf.write(data[0..missing]);
                    } else {
                        const buffered = dw.delim.len - missing;
                        dw.buf.data.len -= buffered;
                    }

                    try dw.flush();
                    i = missing;
                }
            }

            while (bytes.findSeqAt(i, data, dw.delim)) |_j| {
                var j = _j;
                if (dw.include) j += dw.delim.len;

                _ = try dw.buf.write(data[i..j]);
                try dw.flush();

                i = j;
                if (!dw.include) i += dw.delim.len;
            }

            if (i < data.len) _ = try dw.buf.write(data[i..]);
            return data.len;
        }

        pub fn writer(dw: *Self) io.Writer(*Self, WriteError, write) {
            return .{ .writer = dw };
        }

        // Helpers //

        /// Calculates the number of missing bytes required to possibly build a
        /// delimiter from the buffer.
        fn missingDelimiterBytes(dw: *Self) ?usize {
            const buf_len = dw.buf.data.len;
            if (buf_len == 0) return null;
            const buf_data = dw.buf.bytes();

            var j: usize = @min(dw.delim.len, buf_len);

            while (j > 0) : (j -= 1) {
                const i = buf_len - j;

                if (bytes.startsWith(dw.delim, buf_data[i..]))
                    return dw.delim.len - j;
            }

            return null;
        }
    };
}
