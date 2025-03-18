// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io.Writer" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();

    var bw = buf.writer();
    const w = io.DynWriter.init(&bw);

    const n = try w.write("hello, world!");
    try testing.expectEqlBytes(buf.bytes(), "hello, world!");
    try testing.expectEql(n, 13);
}
