// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io.writer" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();

    const w = io.writer(&buf, @TypeOf(buf).Error, @TypeOf(buf).write);

    const n = try w.write("hello, world!");
    try testing.expectEqlBytes(buf.bytes(), "hello, world!");
    try testing.expectEql(n, 13);
}
