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

        /// Like `.log` but supports string formatting.
        pub fn logf(
            l: Self,
            allocator: anytype,
            level: Level,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            const msg = std.fmt.allocPrint(allocator, fmt, args) catch return;
            defer allocator.free(msg);
            l.log(level, msg);
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

        /// Like `.debug` but supports string formatting.
        pub fn debugf(
            l: Self,
            allocator: anytype,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            l.logf(allocator, .debug, fmt, args);
        }

        /// Logs records with `.@"error"` level.
        ///
        /// This is equivalent to calling `l.log(.@"error")`.
        pub fn err(l: Self, msg: []const u8) void {
            l.log(.@"error", msg);
        }

        /// Like `.err` but supports string formatting.
        pub fn errf(
            l: Self,
            allocator: anytype,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            l.logf(allocator, .@"error", fmt, args);
        }

        /// Logs records with `.fatal` level.
        ///
        /// This is equivalent to calling `l.log(.fatal)` and then
        /// `std.process.exit(exit_code)`.
        pub fn fatal(l: Self, exit_code: u8, msg: []const u8) void {
            l.log(.fatal, msg);
            std.process.exit(exit_code);
        }

        /// Like `.fatal` but supports string formatting.
        pub fn fatalf(
            l: Self,
            allocator: anytype,
            exit_code: u8,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            l.logf(allocator, .fatal, fmt, args);
            std.process.exit(exit_code);
        }

        /// Logs records with `.info` level.
        ///
        /// This is equivalent to calling `l.log(.info)`.
        pub fn info(l: Self, msg: []const u8) void {
            l.log(.info, msg);
        }

        /// Like `.info` but supports string formatting.
        pub fn infof(
            l: Self,
            allocator: anytype,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            l.logf(allocator, .info, fmt, args);
        }

        /// Logs records with `.warn` level.
        ///
        /// This is equivalent to calling `l.log(.warn)`.
        pub fn warn(l: Self, msg: []const u8) void {
            l.log(.warn, msg);
        }

        /// Like `.warn but supports string formatting.
        pub fn warnf(
            l: Self,
            allocator: anytype,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            l.logf(allocator, .warn, fmt, args);
        }
    };
}
