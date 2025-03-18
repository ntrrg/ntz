// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const bytes = @import("../types/bytes.zig");

/// Represents the severity of a logging record.
pub const Level = enum {
    const Error = EncodingError;

    /// Records intended to be read by developers.
    debug,

    /// Verbose records about the state of the program.
    info,

    /// Problems that doesn't interrupt the procedure execution.
    warn,

    /// Problems that interrupt the procedure execution.
    err,

    /// Problems that interrupt the program execution.
    fatal,

    /// Returns a string representation of the given level as it would be
    /// written in logging records.
    pub fn asKey(lvl: Level) []const u8 {
        return switch (lvl) {
            .debug => "DBG",
            .info => "INF",
            .warn => "WRN",
            .err => "ERR",
            .fatal => "FTL",
        };
    }

    // ///////////
    // Encoding //
    // ///////////

    const EncodingError = TextEncodingError;

    // Logging.

    pub fn asLog(lvl: Level, log: anytype, comptime key: []const u8) void {
        log.write(key ++ "=\"");
        log.write(lvl.asKey());
        log.write("\"");
    }

    // Text.

    const TextEncodingError = FromTextError;

    /// Returns a string literal of the given level in full text form.
    pub fn asText(lvl: Level) []const u8 {
        return switch (lvl) {
            .debug => "debug",
            .info => "info",
            .warn => "warning",
            .err => "error",
            .fatal => "fatal",
        };
    }

    const FromTextError = error{
        UnkownValue,
    };

    /// Returns an equivalent logging level from given string.
    pub fn fromText(txt: []const u8) FromTextError!Level {
        if (bytes.equalAny(txt, &.{ "DBG", "debug", "dbg" }))
            return .debug;

        if (bytes.equalAny(txt, &.{ "INF", "info", "inf", "information" }))
            return .info;

        if (bytes.equalAny(txt, &.{ "WRN", "warning", "warn", "wrn" }))
            return .warn;

        if (bytes.equalAny(txt, &.{ "ERR", "error", "err" }))
            return .err;

        if (bytes.equalAny(txt, &.{ "FTL", "fatal", "ftl" }))
            return .fatal;

        return error.UnkownValue;
    }
};
