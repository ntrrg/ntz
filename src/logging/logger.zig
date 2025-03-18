// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const builtin = @import("builtin");
const std = @import("std");

const types = @import("../types/root.zig");
const funcs = types.funcs;
const structs = types.structs;

const logging = @import("root.zig");
const Level = logging.Level;

pub fn Logger(
    comptime Writer: type,
    comptime Encoder: type,
    comptime Context: type,
    comptime scope: []const u8,
) type {
    if (!@hasField(Context, "msg"))
        @compileError("given Context (" ++ @typeName(Context) ++ ") doesn't have a 'msg' field");

    return struct {
        const Self = @This();

        mutex: ?*std.Thread.Mutex = null,
        writer: Writer,
        encoder: Encoder,

        level: Level = switch (builtin.mode) {
            .Debug => .debug,
            .ReleaseSafe => .warn,
            .ReleaseFast, .ReleaseSmall => .@"error",
        },

        ctx: Context = structs.init(Context),

        /// Writes a log record with the given message and level of severity.
        ///
        /// If the log context has a method `.onLog`, it will be called just
        /// before writing the log record. This method must be of the following
        /// type:
        ///
        /// ```zig
        /// pub fn onLog(_: Self) T
        /// ```
        ///
        /// The returned value may be of any other type, giving more control
        /// over encoding behavior, like date formatting, field renaming or
        /// computed values.
        pub fn log(l: Self, level: Level, msg: []const u8) void {
            if (!l.should(level)) return;

            var ctx = l.ctx;
            ctx.msg = msg;

            if (@hasField(Context, "level")) {
                ctx.level = if (@TypeOf(ctx.level) == Level)
                    level
                else
                    level.key();
            }

            const val = if (comptime funcs.hasFn(Context, "onLog"))
                ctx.onLog()
            else
                ctx;

            if (l.mutex) |mux| mux.lock();
            defer if (l.mutex) |mux| mux.unlock();
            l.encoder.encode(l.writer, val) catch return;
            _ = l.writer.write("\n") catch return;
        }

        /// Checks if given level should be logged.
        pub fn should(l: Self, level: Level) bool {
            if (l.level == .disabled) return false;
            return @intFromEnum(level) >= @intFromEnum(l.level);
        }

        /// Updates the context of the logger.
        ///
        /// This doesn't modify the logger, it creates a new one instead.
        pub fn with(
            l: Self,
            comptime key: []const u8,
            val: types.Field(Context, scope ++ key),
        ) Self {
            if (l.level == .disabled) return l;
            var _l = l;
            types.setField(&_l.ctx, scope ++ key, val);
            return _l;
        }

        /// Creates a logger using given scope.
        pub fn withScope(l: Self, comptime new_scope: []const u8) Logger(
            Writer,
            Encoder,
            Context,
            (if (scope.len > 0) scope ++ new_scope else new_scope) ++ ".",
        ) {
            return .{
                .mutex = l.mutex,
                .writer = l.writer,
                .encoder = l.encoder,
                .level = l.level,
                .ctx = l.ctx,
            };
        }

        /// Creates a logger using given level as minimum logging severity.
        pub fn withSeverity(l: Self, level: Level) Self {
            var _l = l;
            _l.level = level;
            return _l;
        }

        // Severity logging //

        /// Logs records with `.debug` level.
        ///
        /// This is equivalent to calling `l.log(.debug)`.
        pub fn debug(l: Self, msg: []const u8) void {
            l.log(.debug, msg);
        }

        /// Logs records with `.@"error"` level.
        ///
        /// This is equivalent to calling `l.log(.@"error")`.
        pub fn err(l: Self, msg: []const u8) void {
            l.log(.@"error", msg);
        }

        /// Logs records with `.fatal` level.
        ///
        /// This is equivalent to calling `l.log(.fatal)` and then
        /// `std.process.exit(3)`.
        ///
        /// Exit code `3` is used for identifying termination from the logger.
        pub fn fatal(l: Self, msg: []const u8) void {
            l.log(.fatal, msg);
            std.process.exit(3);
        }

        /// Logs records with `.info` level.
        ///
        /// This is equivalent to calling `l.log(.info)`.
        pub fn info(l: Self, msg: []const u8) void {
            l.log(.info, msg);
        }

        /// Logs records with `.warn` level.
        ///
        /// This is equivalent to calling `l.log(.warn)`.
        pub fn warn(l: Self, msg: []const u8) void {
            l.log(.warn, msg);
        }
    };
}
