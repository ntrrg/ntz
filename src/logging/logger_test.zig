// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const encoding = ntz.encoding;
const ctxlog = encoding.ctxlog;
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const logging = ntz.logging;

test "ntz.logging.Logger" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    const w = buf.writer();

    const e = ctxlog.Encoder{};

    const log = logging.initCustom(w, e, struct {
        level: []const u8,

        http: ?struct {
            request: ?struct {
                method: []const u8,
                url: []const u8,
            },

            response: ?struct {
                status: u10,
            },
        },

        msg: []const u8,
    }).withSeverity(.info);

    buf.clear();
    log.info("hello, world!");

    try testing.expectEqlStrs(
        buf.bytes(),
        "level=\"INFO\" msg=\"hello, world!\"\n",
    );

    // Severity.

    buf.clear();
    const warn_log = log.withSeverity(.warn);
    warn_log.info("hello, world!");

    try testing.expectEqlStrs(buf.bytes(), "");

    // Scoping

    buf.clear();
    const http_log = log.withScope("http");

    http_log
        .with("request.method", "GET")
        .with("request.url", "http://localhost/")
        .with("response.status", 200)
        .info("hello, request!");

    try testing.expectEqlStrs(
        buf.bytes(),
        "level=\"INFO\" http.request.method=\"GET\" http.request.url=\"http://localhost/\" http.response.status=200 msg=\"hello, request!\"\n",
    );

    // onLog method.

    const timed_log = logging.initCustom(w, e, struct {
        const Self = @This();

        time: u64,
        level: []const u8,
        msg: []const u8,

        pub fn onLog(ctx: Self) Self {
            var _ctx = ctx;
            _ctx.time = 42;
            return _ctx;
        }
    });

    buf.clear();
    timed_log.err("hello, timed log!");

    try testing.expectEqlStrs(
        buf.bytes(),
        "time=42 level=\"ERROR\" msg=\"hello, timed log!\"\n",
    );
}
