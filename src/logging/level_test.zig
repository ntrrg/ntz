// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

const Level = ntz.logging.Level;

test "ntz.logging.Level.asKey" {
    try testing.expectEqlStrs(Level.fatal.asKey(), "FTL");
    try testing.expectEqlStrs(Level.err.asKey(), "ERR");
    try testing.expectEqlStrs(Level.warn.asKey(), "WRN");
    try testing.expectEqlStrs(Level.info.asKey(), "INF");
    try testing.expectEqlStrs(Level.debug.asKey(), "DBG");
}

test "ntz.logging.Level.asText" {
    try testing.expectEqlStrs(Level.fatal.asText(), "fatal");
    try testing.expectEqlStrs(Level.err.asText(), "error");
    try testing.expectEqlStrs(Level.warn.asText(), "warning");
    try testing.expectEqlStrs(Level.info.asText(), "info");
    try testing.expectEqlStrs(Level.debug.asText(), "debug");
}

test "ntz.logging.Level.fromText" {
    try testing.expectEql(try Level.fromText("FTL"), .fatal);
    try testing.expectEql(try Level.fromText("fatal"), .fatal);
    try testing.expectEql(try Level.fromText("ftl"), .fatal);

    try testing.expectEql(try Level.fromText("ERR"), .err);
    try testing.expectEql(try Level.fromText("error"), .err);
    try testing.expectEql(try Level.fromText("err"), .err);

    try testing.expectEql(try Level.fromText("WRN"), .warn);
    try testing.expectEql(try Level.fromText("warning"), .warn);
    try testing.expectEql(try Level.fromText("warn"), .warn);
    try testing.expectEql(try Level.fromText("wrn"), .warn);

    try testing.expectEql(try Level.fromText("INF"), .info);
    try testing.expectEql(try Level.fromText("info"), .info);
    try testing.expectEql(try Level.fromText("information"), .info);
    try testing.expectEql(try Level.fromText("inf"), .info);

    try testing.expectEql(try Level.fromText("DBG"), .debug);
    try testing.expectEql(try Level.fromText("debug"), .debug);
    try testing.expectEql(try Level.fromText("dbg"), .debug);
}
