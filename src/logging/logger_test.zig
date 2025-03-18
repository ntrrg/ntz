// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const testing = ntz.testing;

const logging = ntz.logging;

test "ntz.logging.Logger" {
    const ally = testing.allocator;

    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const w = buf.writer();
    var mutex: std.Thread.Mutex = .{};

    const Logger = logging.Logger("", @TypeOf(w), 1024, .{ .with_time = false });
    const logger: Logger = .{ .writer = w, .mutex = &mutex };
    const log = logger.withLevel(.debug);

    // ////////
    // Basic //
    // ////////

    buf.clearRetainingCapacity();

    // Check run-time known formatting args.
    var lvl = "debug";
    _ = &lvl;

    log.info("hello, world from: {s}!", .{lvl});

    try testing.expectEqlStrs(
        buf.items,
        "level=\"INF\" msg=\"hello, world from: debug!\"\n",
    );
}
