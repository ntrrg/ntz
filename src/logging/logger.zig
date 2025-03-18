// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const builtin = @import("builtin");
const std = @import("std");

const types = @import("../types/root.zig");
const errors = types.errors;

const logging = @import("root.zig");
const Level = logging.Level;

/// Type-safe logger.
///
/// `Context` is the structure of the logging records, there are 2 fields
/// required:
///
/// - 'level': severity of the logging record and must be of type
///   `logging.Level`.
///
/// - 'msg': descriptive message of the logging record and must be of type
///   `[]const u8`.
pub fn Logger(
    comptime Context: type,
    comptime Writer: type,
    comptime Encoder: type,
) type {
    if (!@hasField(Context, "level"))
        @compileError("given Context (" ++ @typeName(Context) ++ ") doesn't have a 'level' field");

    if (!@hasField(Context, "msg"))
        @compileError("given Context (" ++ @typeName(Context) ++ ") doesn't have a 'msg' field");

    return struct {
        const Self = @This();

        ctx: Context,
        mutex: ?*std.Thread.Mutex = null,
        writer: Writer,
        encoder: Encoder,

        pub const LogError =
            errors.From(Encoder) ||
            errors.From(Writer);

        pub fn log(l: Self, level: Level, msg: []const u8) LogError!void {
            if (!l.should(level)) return;

            var ctx = l.ctx;
            ctx.level = level;
            ctx.msg = msg;

            if (l.mutex) |mux| mux.lock();
            defer if (l.mutex) |mux| mux.unlock();
            try l.encoder.encode(l.writer, ctx);
            _ = try l.writer.write("\n");
        }

        /// Checks if given level should be logged.
        pub fn should(l: Self, level: Level) bool {
            return @intFromEnum(level) >= @intFromEnum(l.ctx.level);
        }

        pub fn with(
            l: Self,
            comptime key: []const u8,
            val: types.Field(@TypeOf(Context), key),
        ) Self {
            var _l = l;
            types.setField(&_l, key, val);
            return _l;
        }

        // Severity logging //

        /// Logs records with `.debug` level.
        ///
        /// This is equivalent to calling `l.log(.debug, "")`.
        pub fn debug(l: Self, msg: []const u8) void {
            l.log(.debug, msg);
        }

        /// Logs records with `.@"error"` level.
        ///
        /// This is equivalent to calling `l.log(.@"error", "")`.
        pub fn err(l: Self, msg: []const u8) void {
            l.log(.@"error", msg);
        }

        /// Logs records with `.fatal` level.
        ///
        /// This is equivalent to calling `l.log(.fatal, "")` and then
        /// `std.process.exit(3)`.
        ///
        /// Exit code `3` is used for identifying termination from the logger.
        pub fn fatal(l: Self, msg: []const u8) void {
            l.log(.fatal, msg);
            std.process.exit(3);
        }

        /// Logs records with `.info` level.
        ///
        /// This is equivalent to calling `l.log(.info, "")`.
        pub fn info(l: Self, msg: []const u8) void {
            l.log(.info, msg);
        }

        /// Logs records with `.warn` level.
        ///
        /// This is equivalent to calling `l.log(.warn, "")`.
        pub fn warn(l: Self, msg: []const u8) void {
            l.log(.warn, msg);
        }
    };
}
