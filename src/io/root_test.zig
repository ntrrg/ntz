// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const errors = types.errors;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io" {
    // Readers.
    //_ = @import("counting_reader_test.zig");

    // Writers.
    _ = @import("DynWriter_test.zig");
    _ = @import("writer_test.zig");
    _ = @import("buffered_writer_test.zig");
    _ = @import("counting_writer_test.zig");
    _ = @import("delimited_writer_test.zig");
    _ = @import("limited_writer_test.zig");
}

// //////////
// Writers //
// //////////

fn SingleByteWriter(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriteError;

        writer: T,

        pub const WriteError = errors.From(T);

        pub fn write(sbw: Self, data: []const u8) WriteError!usize {
            if (data.len == 0) return 0;
            return sbw.writer.write(data[0..1]);
        }
    };
}

test "ntz.io.writeAll" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    const sbw = SingleByteWriter(*@TypeOf(cw)){ .writer = &cw };

    const in = "hello, world!";
    const n = try io.writeAll(sbw, in);
    try testing.expectEqlStrs(buf.bytes(), in);
    try testing.expectEql(n, 13);
    try testing.expectEql(cw.write_count, 13);
    try testing.expectEql(cw.byte_count, 13);
}
