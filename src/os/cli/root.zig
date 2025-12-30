// Copyright 2026 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.os.cli`
//!
//! Command line operations and utilities.

const types = @import("../../types/root.zig");
const bytes = types.bytes;
const slices = types.slices;

pub const Arguments = slices.Iterator([]const u8);
pub const Command = @import("commands.zig").Command;
pub const Entries = slices.Slice(Entry);

pub const Entry = struct {
    from: enum { config, env, flag, command, argument, manual },
    command: []const u8,
    key: []const u8,
    value: []const u8,

    pub fn init(key: []const u8, value: []const u8) Entry {
        return .{ .from = .manual, .command = "", .key = key, .value = value };
    }
};

pub const Option = @import("options.zig").Option;

// //////////////////////////////
// Help and version generation //
// //////////////////////////////

pub fn writeCommands(writer: anytype, cmd: anytype, title: []const u8) !void {
    if (cmd.cmds.len == 0) return;

    var has_title = false;

    for (cmd.cmds.items()) |sub_cmd| {
        if (!has_title and title.len > 0) {
            _ = try writer.write("\n");
            _ = try writer.write(title);
            _ = try writer.write("\n");
            has_title = true;
        }

        _ = try writer.write("  ");
        _ = try writer.write(sub_cmd.name);

        if (sub_cmd.aliases.len > 0) {
            _ = try writer.write(" (");

            for (sub_cmd.aliases, 0..) |alias, i| {
                if (i > 0) _ = try writer.write("|");
                _ = try writer.write(alias);
            }

            _ = try writer.write(")");
        }

        _ = try writer.write(": ");
        _ = try writer.write(sub_cmd.description);
        _ = try writer.write(".\n");
    }
}

pub fn writeEnvVars(writer: anytype, cmd: anytype, title: []const u8) !void {
    if (cmd.opts.len == 0) return;

    var has_title = false;

    for (cmd.opts.items()) |opt| {
        if (opt.env.len == 0) continue;

        if (!has_title and title.len > 0) {
            _ = try writer.write("\n");
            _ = try writer.write(title);
            _ = try writer.write("\n");
            has_title = true;
        }

        _ = try writer.write("  - ");
        _ = try writer.write(cmd.env_prefix);
        _ = try writer.write(opt.env);
        _ = try writer.write(" (id: ");
        _ = try writer.write(opt.id);
        _ = try writer.write("): ");
        _ = try writer.write(opt.help);
        _ = try writer.write(".\n");
    }
}

pub fn writeFlags(writer: anytype, cmd: anytype, title: []const u8) !void {
    if (cmd.opts.len == 0) return;

    var has_title = false;

    for (cmd.opts.items()) |opt| {
        if (opt.flags.len == 0) continue;

        if (!has_title and title.len > 0) {
            _ = try writer.write("\n");
            _ = try writer.write(title);
            _ = try writer.write("\n");
            has_title = true;
        }

        _ = try writer.write("  ");

        for (opt.flags, 0..) |flag, i| {
            if (i > 0) _ = try writer.write(", ");
            _ = try writer.write(cmd.flags_prefix);
            _ = try writer.write(flag);
            if (opt.is_boolean) continue;
            if (opt.has_optional_value) _ = try writer.write("[");
            _ = try writer.write("=<");
            _ = try writer.write(opt.placeholder);
            _ = try writer.write(">");
            if (opt.has_optional_value) _ = try writer.write("]");
        }

        if (opt.valid_values.len > 0) {
            _ = try writer.write(" (");

            for (opt.valid_values, 0..) |value, i| {
                if (i > 0) _ = try writer.write("|");
                _ = try writer.write(value);
            }

            _ = try writer.write(")");
        }

        if (opt.default.len > 0) {
            _ = try writer.write(" (default: ");
            _ = try writer.write(opt.default);
            _ = try writer.write(")");
        }

        _ = try writer.write(" (id: ");
        _ = try writer.write(opt.id);
        _ = try writer.write(")");

        _ = try writer.write("\n");
        _ = try writer.write("    ");
        _ = try writer.write(opt.help);
        _ = try writer.write(".\n");
    }
}

pub fn writeHelp(writer: anytype, cmd: anytype) !void {
    _ = try writeName(writer, cmd);

    if (cmd.description.len > 0) {
        _ = try writer.write(" - ");
        _ = try writer.write(cmd.description);
        _ = try writer.write(".");
    }

    _ = try writer.write("\n");

    // Long description

    if (cmd.longDescription.len > 0) {
        _ = try writer.write("\n");
        _ = try writer.write(cmd.longDescription);
        _ = try writer.write("\n");
    }

    // Usage.

    _ = try writer.write("\n");

    if (cmd.usage.len > 0) {
        _ = try writer.write(cmd.usage);
    } else {
        _ = try writer.write("Usage: ");
        _ = try writer.write(cmd.name);
        _ = try writer.write(" [<options>]\n");
    }

    // Commands, flags and environment variables.

    try writeCommands(writer, cmd, "Commands:");
    try writeFlags(writer, cmd, "Options:");
    try writeEnvVars(writer, cmd, "Environment variables:");

    // Epilogue.

    if (cmd.epilog.len > 0) {
        _ = try writer.write("\n");
        _ = try writer.write(cmd.epilog);
        _ = try writer.write("\n");
    }

    // Copyright.

    if (cmd.copyright.len > 0) {
        _ = try writer.write("\n");
        _ = try writer.write(cmd.copyright);
        _ = try writer.write("\n");
    }
}

pub fn writeName(writer: anytype, cmd: anytype) !void {
    if (cmd.parent) |parent| {
        _ = try writeName(writer, parent);
        _ = try writer.write(" ");
    }

    _ = try writer.write(cmd.name);
}

pub fn writeOptionHelp(writer: anytype, cmd: anytype, id: []const u8) !void {
    for (cmd.opts.items()) |opt| {
        if (!bytes.equal(id, opt.id)) continue;
        _ = try writer.write(opt.id);
        _ = try writer.write(" - ");
        _ = try writer.write(opt.help);
        _ = try writer.write("\n\n");

        _ = try writer.write("Required: ");
        _ = try writer.write(if (opt.is_required) "yes" else "no");
        _ = try writer.write("\n");

        _ = try writer.write("Optional value: ");
        _ = try writer.write(if (opt.has_optional_value) "yes" else "no");
        _ = try writer.write("\n");

        if (opt.default.len > 0) {
            _ = try writer.write("Default value: '");
            _ = try writer.write(opt.default);
            _ = try writer.write("'\n");
        }

        if (opt.valid_values.len > 0) {
            _ = try writer.write("Valid values: ");

            for (opt.valid_values, 0..) |value, i| {
                if (i > 0) _ = try writer.write(", ");
                _ = try writer.write("'");
                _ = try writer.write(value);
                _ = try writer.write("'");
            }

            _ = try writer.write("\n");
        }

        if (opt.flags.len > 0) {
            _ = try writer.write("Flags: ");

            for (opt.flags, 0..) |flag, i| {
                if (i > 0) _ = try writer.write(", ");
                _ = try writer.write(cmd.flags_prefix);
                _ = try writer.write(flag);
            }

            _ = try writer.write("\n");
        }

        if (opt.env.len > 0) {
            _ = try writer.write("Environment: ");
            _ = try writer.write(cmd.env_prefix);
            _ = try writer.write(opt.env);
            _ = try writer.write("\n");
        }

        if (opt.config.len > 0) {
            _ = try writer.write("Configuration: ");
            _ = try writer.write(cmd.config_prefix);
            _ = try writer.write(opt.config);
            _ = try writer.write("\n");
        }

        if (opt.longHelp.len > 0) {
            _ = try writer.write("\n");
            _ = try writer.write(opt.longHelp);
            _ = try writer.write("\n");
        }

        return;
    }

    return error.InvalidOption;
}

pub fn writeVersion(writer: anytype, cmd: anytype) !void {
    _ = try writer.write(cmd.name);
    _ = try writer.write(" v");
    _ = try writer.write(cmd.version);
    _ = try writer.write("\n");

    if (cmd.version_info.len > 0) {
        _ = try writer.write(cmd.version_info);
        _ = try writer.write("\n");
    }

    if (cmd.copyright.len > 0) {
        _ = try writer.write(cmd.copyright);
        _ = try writer.write("\n");
    }
}
