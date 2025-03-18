// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const unicode = encoding.unicode;
const utf8 = unicode.utf8;
const logging = ntz.logging;

pub fn main() !void {
    const log = logging.init(ctxlog.Encoder{}, struct {
        level: logging.Level,
        msg: []const u8,

        utf8: ?struct {
            cp: u21,
            str: []const u8,
        },
    });

    log.info("preparing buffer for the standart output");

    const std_out = std.io.getStdOut();
    var bw = std.io.bufferedWriter(std_out.writer());
    defer bw.flush() catch {};
    const w = bw.writer();

    log.info("buffer for the standart output set");

    const utf8_log = log.withScope("utf8");

    for (0x20..0b0111_1111) |i| {
        var buf: [4]u8 = undefined;

        const want = try unicode.Codepoint.init(@intCast(i));
        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        utf8_log.with("cp", got.value).with("str", buf[0..n]).debug("");
        try w.print("{x}   {s}\n", .{ got.value, buf[0..n] });
    }

    log.info("flushing standart output buffer");
    try bw.flush();
    log.info("standart output buffer flushed");
}
