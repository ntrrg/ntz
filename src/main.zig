// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const unicode = ntz.encoding.unicode;
const utf8 = unicode.utf8;

pub fn main() !void {
    const std_out = std.io.getStdOut();
    var bw = std.io.bufferedWriter(std_out.writer());
    defer bw.flush() catch {};
    const w = bw.writer();

    for (0..0x10FFFF) |i| {
        if (unicode.isSurrogateCharacter(i)) continue;

        var buf: [4]u8 = undefined;

        const want = try unicode.Codepoint.init(@intCast(i));
        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        try w.print("{x}   {s}\n", .{ got.value, buf[0..n] });
    }

    //const msg = "hello, world!\n";

    //try w.print("{}\n", .{try utf8.len(msg)});
    //_ = try w.write(msg);

    try bw.flush();
}
