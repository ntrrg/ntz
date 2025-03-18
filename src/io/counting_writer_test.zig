// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io.counting_writer" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();

    var cw = io.countingWriter(&buf);

    var n = try cw.write("hello,");
    try testing.expectEqlStrs(buf.bytes(), "hello,");
    try testing.expectEql(n, 6);
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 6);

    n = try cw.write(" world");
    try testing.expectEqlStrs(buf.bytes(), "hello, world");
    try testing.expectEql(n, 6);
    try testing.expectEql(cw.write_count, 2);
    try testing.expectEql(cw.byte_count, 12);

    n = try cw.write("!");
    try testing.expectEqlStrs(buf.bytes(), "hello, world!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 13);
}
