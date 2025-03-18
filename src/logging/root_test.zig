// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

const logging = ntz.logging;

test "ntz.logging" {
    _ = @import("logger_test.zig");
}

test "ntz.logging.Level.key" {
    try testing.expectEqlStrs(logging.Level.debug.key(), "DEBUG");
    try testing.expectEqlStrs(logging.Level.info.key(), "INFO");
    try testing.expectEqlStrs(logging.Level.warn.key(), "WARN");
    try testing.expectEqlStrs(logging.Level.@"error".key(), "ERROR");
    try testing.expectEqlStrs(logging.Level.fatal.key(), "FATAL");
}

test "ntz.logging.Level.fromKey" {
    try testing.expectEql(try logging.Level.fromKey("DEBUG"), .debug);
    try testing.expectEql(try logging.Level.fromKey("INFO"), .info);
    try testing.expectEql(try logging.Level.fromKey("WARN"), .warn);
    try testing.expectEql(try logging.Level.fromKey("ERROR"), .@"error");
    try testing.expectEql(try logging.Level.fromKey("FATAL"), .fatal);

    try testing.expectErr(
        logging.Level.fromKey("DDEBUG"),
        logging.Level.FromKeyError.InvalidSeverity,
    );
}
