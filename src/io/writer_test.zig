// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");
const types = ntz.types;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io.writer" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();

    const w = io.writer(&buf, std.mem.Allocator.Error, bytes.Buffer.write);

    const n = try w.write("hello, world!");
    try testing.expectEqualStrings("hello, world!", buf.bytes());
    try testing.expectEqual(13, n);
}

test "ntz.io.Writer.stdWriter" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();

    const io_w = io.writer(&buf, std.mem.Allocator.Error, bytes.Buffer.write);
    var std_w = io_w.stdWriter(&.{});
    var w: *std.Io.Writer = &std_w.interface;

    const n = try w.write("hello, world!");
    try testing.expectEqualStrings("hello, world!", buf.bytes());
    try testing.expectEqual(13, n);
}
