// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io.buffered_writer: smaller than buffer size" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var bw = io.bufferedWriterWithSize(&cw, 16);

    const in = "hello, world!";
    const n = try bw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "");
    try testing.expectEql(n, in.len);
    try testing.expectEql(cw.write_count, 0);
    try testing.expectEql(cw.byte_count, 0);

    try bw.flush();
    try testing.expectEqlStrs(buf.bytes(), in);
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 13);
}

test "ntz.io.buffered_writer: equal than buffer size" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var bw = io.bufferedWriterWithSize(&cw, 13);

    const in = "hello, world!";
    const n = try bw.write(in);
    try testing.expectEqlStrs(buf.bytes(), in);
    try testing.expectEql(n, in.len);
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 13);

    try bw.flush();
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 13);
}

test "ntz.io.buffered_writer: bigger than buffer size" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var bw = io.bufferedWriterWithSize(&cw, 4);

    const in = "hello, world!";
    const n = try bw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "hello, world");
    try testing.expectEql(n, in.len);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 12);

    try bw.flush();
    try testing.expectEqlStrs(buf.bytes(), in);
    try testing.expectEql(cw.write_count, 4);
    try testing.expectEql(cw.byte_count, 13);
}
