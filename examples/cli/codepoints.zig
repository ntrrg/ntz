// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const unicode = encoding.unicode;
const utf8 = unicode.utf8;

pub const LogContext = struct {
    cp: u21,
    str: []const u8,
};

pub fn print_range(
    io: std.Io,
    allocator: std.mem.Allocator,
    status: *ntz.Status,
    log: anytype,
    first_cp: u21,
    last_cp: u21,
) !void {
    log.info("preparing buffer for the standart output");

    var stdout_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout();
    var stdout_writer = stdout.writer(io, &stdout_buf);
    var writer = &stdout_writer.interface;

    defer {
        log.info("flushing the standart output buffer");
        writer.flush() catch {};
        log.info("flushed the standart output buffer");
    }

    log.info("buffer for the standart output set");

    for (first_cp..last_cp) |i| {
        if (status.isDone()) break;
        if (unicode.isSurrogateCharacter(i)) continue;

        var buf: [4]u8 = undefined;

        const want = unicode.Codepoint.init(@intCast(i)) catch |err| {
            log.withError(err)
                .errf(allocator, "{d} is not a valid codepoint", .{i});

            return err;
        };

        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        log.with("cp", got.value).with("str", buf[0..n]).debug("");
        try writer.print("0x{X:<6} [{s}]\n", .{ got.value, buf[0..n] });
    }
}
