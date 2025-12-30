// Copyright 2026 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const io = @import("../../io/root.zig");
const types = @import("../../types/root.zig");
const bytes = types.bytes;
const slices = types.slices;

const cli = @import("root.zig");

pub fn Command(
    comptime Logger: type,
    comptime Context: type,
) type {
    return struct {
        const Self = @This();

        pub const Action = *const fn (
            ctx: *Context,
            cmd: Self,
            args: []const []const u8,
        ) anyerror!u8;

        parent: ?*const Self = null,

        allocator: std.mem.Allocator,
        logger: Logger,

        id: []const u8 = "command",
        name: []const u8 = "command",
        aliases: []const []const u8 = &.{},
        version: []const u8 = "0.0.1",
        version_info: []const u8 = "",
        description: []const u8 = "",
        longDescription: []const u8 = "",
        usage: []const u8 = "",
        epilog: []const u8 = "",
        copyright: []const u8 = "",

        opts: slices.Slice(cli.Option(Self, Context)) = .{},
        cmds: slices.Slice(Self) = .{},

        flags_prefix: []const u8 = "",
        env_prefix: []const u8 = "",
        config_prefix: []const u8 = "",

        action: ?Action = null,

        pub fn deinit(cmd: *Self) void {
            cmd.opts.deinit(cmd.allocator);
            for (cmd.cmds.items()) |*sub_cmd| sub_cmd.deinit();
            cmd.cmds.deinit(cmd.allocator);
        }

        pub fn load(
            cmd: Self,
            allocator: *std.heap.ArenaAllocator,
            ctx: *Context,
            entries: *cli.Entries,
        ) !u8 {
            const arena = allocator.allocator();

            for (cmd.opts.items()) |opt| {
                opt.load(arena, cmd, ctx, entries.items()) catch |err| {
                    const msg = "cannot load option '{s}'";
                    cmd.logger.with("error", err).errf(arena, msg, .{opt.id});
                    return err;
                };
            }

            var args: slices.Slice([]const u8) = .{};

            defer {
                for (args.items()) |arg| cmd.allocator.free(arg);
                args.deinit(cmd.allocator);
            }

            for (entries.items(), 0..) |entry, i| {
                if (entry.from == .argument) {
                    try args.append(
                        cmd.allocator,
                        try cmd.allocator.dupe(u8, entry.value),
                    );

                    continue;
                }

                if (entry.from != .command) continue;

                const name = entry.value;

                for (cmd.cmds.items()) |*sub_cmd| {
                    if (!bytes.equal(name, sub_cmd.name) and
                        !bytes.equalAny(name, sub_cmd.aliases))
                        continue;

                    _ = slices.copyLtr(
                        cli.Entry,
                        entries.ptr[i - 1 .. entries.len - 1],
                        entries.ptr[i..entries.len],
                    );

                    entries.len -= 1;

                    return sub_cmd.load(allocator, ctx, entries) catch |err| {
                        const msg = "cannot load option entries for subcommand '{s}'";
                        cmd.logger.with("error", err).errf(arena, msg, .{sub_cmd.name});
                        return err;
                    };
                }
            }

            _ = allocator.reset(.free_all);
            if (cmd.action) |act| return act(ctx, cmd, args.items());
            return 0;
        }

        // //////////
        // Options //
        // //////////

        pub const AddOptionError = error{
            NoOptionId,
        } || std.mem.Allocator.Error;

        pub fn addOption(cmd: *Self, opt: cli.Option(Self, Context)) AddOptionError!void {
            if (opt.id.len == 0)
                return error.NoOptionId;

            try cmd.opts.append(cmd.allocator, opt);
        }

        // Default options //

        pub const envFileOption: cli.Option(Self, Context) = .{
            .id = "env_file",
            .flags = &.{"--env-file"},
            .help = "Read environment variables from the given file",
            .placeholder = "file",
            .has_optional_value = true,
            .default = ".env",
            .readAction = Self.envFileReadAction,
            .action = Self.emptyAction,
        };

        pub const helpOption: cli.Option(Self, Context) = .{
            .id = "help",
            .flags = &.{"--help"},
            .help = "Print this help message",
            .placeholder = "option_id",
            .has_optional_value = true,
            .readAction = Self.helpReadAction,
            .action = Self.emptyAction,
        };

        pub const versionOption: cli.Option(Self, Context) = .{
            .id = "version",
            .flags = &.{"--version"},
            .help = "Print version number",
            .is_boolean = true,
            .readAction = Self.versionAction,
            .action = Self.emptyAction,
        };

        // Default actions //

        pub fn emptyAction(
            _: *Context,
            _: std.mem.Allocator,
            _: Self,
            _: []const u8,
        ) !void {}

        pub fn envFileReadAction(
            _: *Context,
            arena: std.mem.Allocator,
            cmd: Self,
            entries: *cli.Entries,
            _: *slices.Iterator([]const u8),
            entry: cli.Entry,
        ) !void {
            const name = entry.value;

            cmd.fromEnvFile(arena, entries, name) catch |err| {
                const msg = "cannot read option entries from env file '{s}''";
                cmd.logger.with("error", err).errf(arena, msg, .{name});
                return err;
            };
        }

        pub fn helpReadAction(
            _: *Context,
            _: std.mem.Allocator,
            cmd: Self,
            _: *cli.Entries,
            _: *slices.Iterator([]const u8),
            entry: cli.Entry,
        ) !void {
            const writer = io.stdout();

            if (entry.value.len > 0) {
                try cli.writeOptionHelp(writer, cmd, entry.value);
            } else {
                try cli.writeHelp(writer, cmd);
            }

            std.process.exit(0);
        }

        pub fn versionAction(
            _: *Context,
            _: std.mem.Allocator,
            cmd: Self,
            _: *cli.Entries,
            _: *slices.Iterator([]const u8),
            _: cli.Entry,
        ) !void {
            try cli.writeVersion(io.stdout(), cmd);
            std.process.exit(0);
        }

        // ///////////////
        // Sub commands //
        // ///////////////

        pub fn addCommand(
            cmd: *Self,
            comptime id: []const u8,
            comptime name: []const u8,
            comptime aliases: []const []const u8,
            action: ?Action,
        ) !*Self {
            return cmd.cmds.appendAndReturn(cmd.allocator, .{
                .parent = cmd,

                .allocator = cmd.allocator,
                .logger = cmd.logger,

                .id = id,
                .name = name,
                .aliases = aliases,
                .version = cmd.version,
                .version_info = cmd.version_info,
                .copyright = cmd.copyright,

                .flags_prefix = cmd.flags_prefix,
                .env_prefix = cmd.env_prefix,
                .config_prefix = cmd.config_prefix,

                .action = action,
            });
        }

        // //////////
        // Reading //
        // //////////

        pub fn fromOS(cmd: Self, ctx: *Context) !u8 {
            var arena_ally = std.heap.ArenaAllocator.init(cmd.allocator);
            defer arena_ally.deinit();
            const arena = arena_ally.allocator();

            var entries: cli.Entries = .{};

            cmd.fromEnv(arena, &entries) catch |err| {
                const msg = "cannot read option entries from environment variables";
                cmd.logger.with("error", err).err(msg);
                return err;
            };

            cmd.fromArgs(arena, ctx, &entries) catch |err| {
                const msg = "cannot read option entries from arguments";
                cmd.logger.with("error", err).err(msg);
                return err;
            };

            return cmd.load(&arena_ally, ctx, &entries);
        }

        // Arguments and flags //

        pub fn fromArgs(
            cmd: Self,
            arena: std.mem.Allocator,
            ctx: *Context,
            entries: *cli.Entries,
        ) !void {
            const args = std.process.argsAlloc(arena) catch |err| {
                const msg = "cannot get command line arguments";
                cmd.logger.with("error", err).err(msg);
                return err;
            };

            defer std.process.argsFree(arena, args);

            try cmd.fromArgsSlice(arena, ctx, entries, args);
        }

        pub fn fromArgsIterator(
            cmd: Self,
            arena: std.mem.Allocator,
            ctx: *Context,
            entries: *cli.Entries,
            args: *slices.Iterator([]const u8),
        ) !void {
            var pos_args: slices.Slice([]const u8) = .{};
            defer pos_args.deinit(arena);
            try pos_args.append(arena, args.next() orelse cmd.name);

            var no_more_flags = false;
            var is_first_arg = true;

            while (args.next()) |arg| {
                const is_flag = !no_more_flags and bytes.startsWith(arg, "-");

                if (!is_flag) {
                    if (is_first_arg) {
                        for (cmd.cmds.items()) |sub_cmd| {
                            if (!bytes.equal(arg, sub_cmd.name) and
                                !bytes.equalAny(arg, sub_cmd.aliases))
                                continue;

                            const entry = cli.Entry{
                                .from = .command,
                                .command = cmd.id,
                                .key = "",
                                .value = try arena.dupe(u8, arg),
                            };

                            try entries.append(arena, entry);
                            args.index -= 1;

                            return sub_cmd.fromArgsIterator(arena, ctx, entries, args) catch |err| {
                                const msg = "cannot read flags for subcommand '{s}'";
                                cmd.logger.with("error", err).errf(arena, msg, .{sub_cmd.name});
                                return err;
                            };
                        }

                        is_first_arg = false;
                    }

                    try pos_args.append(arena, arg);
                    continue;
                }

                if (bytes.equal(arg, "--")) {
                    no_more_flags = true;
                    continue;
                }

                if (cmd.flags_prefix.len > 0 and
                    !bytes.startsWith(arg, cmd.flags_prefix))
                    continue;

                const j = bytes.findAt(cmd.flags_prefix.len, arg, '=');
                const has_value = if (j) |_| true else false;
                const key = arg[cmd.flags_prefix.len .. j orelse arg.len];
                var value = if (j) |i| arg[i + 1 ..] else "";

                for (cmd.opts.items()) |opt| {
                    if (!bytes.equalAny(key, opt.flags)) continue;

                    if (!opt.is_boolean and !has_value) {
                        value = if (!opt.has_optional_value)
                            args.next() orelse {
                                const msg = "missing value for flag '{s}'";
                                cmd.logger.errf(arena, msg, .{key});
                                return error.MissingValue;
                            }
                        else
                            opt.default;
                    }

                    const entry = cli.Entry{
                        .from = .flag,
                        .command = cmd.id,
                        .key = try arena.dupe(u8, key),
                        .value = try arena.dupe(u8, value),
                    };

                    if (opt.readAction) |act| {
                        try act(ctx, arena, cmd, entries, args, entry);
                    } else {
                        try entries.append(arena, entry);
                    }

                    break;
                } else {
                    const msg = "unknown flag '{s}'";
                    cmd.logger.errf(arena, msg, .{arg});
                    return error.UnknowFlag;
                }
            }

            for (pos_args.items()) |arg| {
                const entry = cli.Entry{
                    .from = .argument,
                    .command = cmd.id,
                    .key = "",
                    .value = try arena.dupe(u8, arg),
                };

                try entries.append(arena, entry);
            }
        }

        pub fn fromArgsSlice(
            cmd: Self,
            arena: std.mem.Allocator,
            ctx: *Context,
            entries: *cli.Entries,
            slc: []const []const u8,
        ) !void {
            var it = slices.iterator(slc);
            try cmd.fromArgsIterator(arena, ctx, entries, &it);
        }

        // Environment variables //

        pub fn fromEnv(
            cmd: Self,
            arena: std.mem.Allocator,
            entries: *cli.Entries,
        ) !void {
            var env = std.process.getEnvMap(arena) catch |err| {
                const msg = "cannot get environment variables";
                cmd.logger.with("error", err).err(msg);
                return err;
            };

            defer env.deinit();

            try cmd.fromEnvMap(arena, entries, env);
        }

        pub fn fromEnvFile(
            cmd: Self,
            arena: std.mem.Allocator,
            entries: *cli.Entries,
            name: []const u8,
        ) !void {
            const cwd = std.fs.cwd();

            const env_stat = try cwd.statFile(name);
            const size = @as(usize, env_stat.size);

            const env_buf = try cwd.readFileAlloc(arena, name, size);
            defer arena.free(env_buf);

            try cmd.fromEnvString(arena, entries, env_buf);
        }

        pub fn fromEnvMap(
            cmd: Self,
            arena: std.mem.Allocator,
            entries: *cli.Entries,
            env: std.process.EnvMap,
        ) !void {
            const prefix = cmd.env_prefix;

            for (cmd.opts.items()) |opt| {
                if (opt.env.len == 0) continue;

                const key = if (prefix.len == 0)
                    opt.env
                else
                    try bytes.concat(arena, prefix, opt.env);

                const value = env.get(key) orelse continue;

                const entry = cli.Entry{
                    .from = .env,
                    .command = cmd.id,
                    .key = key,
                    .value = try arena.dupe(u8, value),
                };

                try entries.append(arena, entry);
            }

            for (cmd.cmds.items()) |sub_cmd|
                try sub_cmd.fromEnvMap(arena, entries, env);
        }

        pub fn fromEnvString(
            cmd: Self,
            arena: std.mem.Allocator,
            entries: *cli.Entries,
            s: []const u8,
        ) !void {
            var env = std.process.EnvMap.init(arena);
            defer env.deinit();

            var ln: usize = 1;
            var it = std.mem.splitScalar(u8, s, '\n');

            while (it.next()) |line| : (ln += 1) {
                if (line.len == 0) continue;
                if (line[0] == '#') continue;

                const eq_i = bytes.find(line, '=');

                if (eq_i == null or eq_i.? == line.len - 1) {
                    const msg = "missing value for key '{s}' in line {d}";
                    cmd.logger.errf(arena, msg, .{ line, ln });
                    return error.MissingValue;
                }

                const i = eq_i.?;
                const key = try arena.dupe(u8, line[0..i]);
                var value = try arena.dupe(u8, line[i + 1 ..]);

                if (value[0] == '"') {
                    if (value.len == 1 or value[value.len - 1] != '"') {
                        const msg = "unclosed quote for '{s}' in line {d}";
                        cmd.logger.errf(arena, msg, .{ key, ln });
                        return error.InvalidValue;
                    }

                    value = value[1 .. value.len - 1];
                }

                try env.put(key, value);
            }

            try cmd.fromEnvMap(arena, entries, env);
        }
    };
}
