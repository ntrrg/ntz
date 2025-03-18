// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.encoding.unicode`
//!
//! Contextual logging encoding.

const std = @import("std");

const encoding = @import("../root.zig");
const unicode = encoding.unicode;
const utf8 = unicode.utf8;
const types = @import("../../types/root.zig");
const bytes = types.bytes;
const errors = types.errors;
const funcs = types.funcs;
const slices = types.slices;

const escape_seq: []const u8 = "\"\n";

pub const Encoder = struct {
    const Self = @This();

    pub const Error = EncodeError;

    pub const Options = struct {
        /// Field name.
        field_name: []const u8 = "",

        /// Ignore empty struct fields (strings and arrays).
        omit_empty: bool = true,

        /// Ignore null struct fields.
        omit_null: bool = true,
    };

    options: Options = .{},

    pub fn init() Self {
        return .{};
    }

    pub const EncodeError = error{
        InvalidPointer,
        UnkownType,
        UntaggedUnion,
    };

    /// Encodes a value into the given writer.
    ///
    /// If `val` has a method `.asCtxlog`, it will be used instead of default
    /// encoding. Field name writing is delegated to this method. This method
    /// must be of the following type:
    ///
    /// ```zig
    /// pub fn asCtxlog(_: Self, writer: anytype, enc: Encoder) !void
    /// ```
    ///
    /// Field names have a limit of 64 bytes.
    pub fn encode(
        e: Self,
        writer: anytype,
        val: anytype,
    ) (EncodeError || errors.From(@TypeOf(writer)))!void {
        const T = @TypeOf(val);
        const val_ti = @typeInfo(T);

        if (comptime funcs.hasFn(T, "asCtxlog"))
            return val.asCtxlog(writer, e);

        const std_writer = if (comptime funcs.hasFn(@TypeOf(writer), "writeAll"))
            writer
        else if (comptime funcs.hasFn(@TypeOf(writer), "stdWriter"))
            writer.stdWriter()
        else if (comptime funcs.hasFn(@TypeOf(writer), "writer"))
            writer.writer().stdWriter()
        else
            std.io.GenericWriter(@TypeOf(writer), @TypeOf(writer).Error, @TypeOf(writer).write){ .context = writer };

        switch (val_ti) {
            .@"struct" => |ti| {
                var should_space = false;

                inline for (ti.fields) |field| {
                    blk: {
                        const field_ti = @typeInfo(field.type);
                        const field_val = @field(val, field.name);

                        switch (field_ti) {
                            .optional => {
                                if (e.options.omit_null and field_val == null)
                                    break :blk;
                            },

                            .pointer => |child_ti| {
                                if (child_ti.size == .slice and e.options.omit_empty and field_val.len == 0)
                                    break :blk;
                            },

                            .array => {
                                if (e.options.omit_empty and field_val.len == 0)
                                    break :blk;
                            },

                            .void => if (e.options.omit_null) break :blk,
                            else => {},
                        }

                        if (should_space) _ = try writer.write(" ");
                        should_space = true;

                        var j: usize = e.options.field_name.len;
                        var field_name: [64]u8 = undefined;
                        @memcpy(field_name[0..j], e.options.field_name);

                        if (j > 0) {
                            field_name[j] = '.';
                            j += 1;
                        }

                        @memcpy(field_name[j .. j + field.name.len], field.name);
                        j += field.name.len;

                        const _e = e.withField(field_name[0..j]);

                        var should_field = true;

                        switch (field_ti) {
                            .@"struct" => should_field = false,

                            .optional => |child_ti| {
                                if (@typeInfo(child_ti.child) == .@"struct" and field_val != null)
                                    should_field = false;
                            },

                            .pointer => |child_ti| {
                                if (child_ti.size == .one and @typeInfo(child_ti.child) == .@"struct")
                                    should_field = false;
                            },

                            .@"union" => |child_ti| {
                                if (child_ti.tag_type) |Tag| {
                                    inline for (child_ti.fields) |u_field| {
                                        if (field_val == @field(Tag, u_field.name)) {
                                            if (@typeInfo(u_field.type) == .@"struct")
                                                should_field = false;
                                        }
                                    }
                                }
                            },

                            else => should_field = true,
                        }

                        if (comptime funcs.hasFn(field.type, "asCtxlog"))
                            should_field = false;

                        if (should_field) {
                            _ = try writer.write(_e.options.field_name);
                            _ = try writer.write("=");
                        }

                        try _e.encode(writer, field_val);
                    }
                }
            },

            .bool => {
                _ = try writer.write(if (val) "true" else "false");
            },

            .int, .comptime_int => {
                try std.fmt.format(std_writer, "{d}", .{val});
            },

            .float, .comptime_float => {
                try std.fmt.format(std_writer, "{d}", .{val});
            },

            .@"enum", .enum_literal => {
                try e.encode(writer, @tagName(val));
            },

            .pointer => |ti| {
                if (slices.as(val)) |slc| {
                    if (types.Child(@TypeOf(slc)) == u8 and utf8.isValid(slc)) {
                        _ = try writer.write("\"");

                        var i: usize = 0;

                        while (bytes.findAnyAt(i, slc, escape_seq)) |res| {
                            _ = try writer.write(slc[i..res.index]);
                            _ = try writer.write("\\");

                            switch (res.value) {
                                '\n' => _ = try writer.write("n"),
                                else => _ = try writer.write(&.{res.value}),
                            }

                            i = res.index + 1;
                        }

                        if (i < slc.len) _ = try writer.write(slc[i..]);

                        _ = try writer.write("\"");
                    } else {
                        const _e = e.withField("");

                        _ = try writer.write("[");

                        for (0..slc.len) |i| {
                            if (i > 0) _ = try writer.write(", ");
                            try _e.encode(writer, slc[i]);
                        }

                        _ = try writer.write("]");
                    }
                } else {
                    switch (ti.size) {
                        .one => try e.encode(writer, val.*),

                        else => {
                            return EncodeError.InvalidPointer;
                        },
                    }
                }
            },

            .array => try e.encode(writer, &val),

            .vector => |ti| {
                const arr: [ti.len]ti.child = val;
                try e.encode(writer, &arr);
            },

            .optional => {
                if (val) |v| {
                    try e.encode(writer, v);
                } else {
                    _ = try writer.write("null");
                }
            },

            .@"union" => |ti| {
                if (ti.tag_type) |Tag| {
                    inline for (ti.fields) |field| {
                        blk: {
                            if (val != @field(Tag, field.name)) break :blk;

                            const field_val = @field(val, field.name);

                            if (field.type == void) {
                                try e.encode(writer, field.name);
                            } else {
                                try e.encode(writer, field_val);
                            }
                        }
                    }
                } else {
                    return EncodeError.UntaggedUnion;
                }
            },

            .error_set => {
                try e.encode(writer, @errorName(val));
            },

            .error_union => {
                if (val) |v| {
                    try e.encode(writer, v);
                } else |err| {
                    try e.encode(writer, err);
                }
            },

            .void => _ = {
                _ = try writer.write("null");
            },

            .type => {
                try e.encode(writer, @typeName(val));
            },

            else => {
                return EncodeError.UnkownType;
            },
        }
    }

    pub fn withField(e: Self, field_name: []const u8) Self {
        var opts = e.options;
        opts.field_name = field_name;
        return Self{ .options = opts };
    }
};
