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
const funcs = types.funcs;
const slices = types.slices;

const field_size = 64;

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
        UnboundedPointer,
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
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T);

        if (comptime funcs.hasFn(T, "asCtxlog"))
            return value.asCtxlog(writer, e);

        switch (ti) {
            .pointer => try e.encodePointer(writer, value),
            .optional => try e.encodeOptional(writer, value),
            .int, .comptime_int => try e.encodeNumber(writer, value),
            .float, .comptime_float => try e.encodeNumber(writer, value),
            .@"enum", .enum_literal => try e.encodeEnum(writer, value),
            .bool => try e.encodeBoolean(writer, value),
            .@"struct" => try e.encodeStruct(writer, value),
            .array => try e.encodePointer(writer, &value),
            .vector => try e.encodeVector(writer, value),
            .@"union" => try e.encodeUnion(writer, value),
            .error_set => try e.encodeError(writer, value),
            .error_union => try e.encodeErrorUnion(writer, value),
            .void => try e.encodeVoid(writer),
            .type => try e.encodeType(writer, value),
            else => return EncodeError.UnkownType,
        }
    }

    pub fn encodeBoolean(
        _: Self,
        writer: anytype,
        value: bool,
    ) @TypeOf(writer).Error!void {
        _ = try writer.write(if (value) "true" else "false");
    }

    pub fn encodeEnum(
        e: Self,
        writer: anytype,
        value: anytype,
    ) @TypeOf(writer).Error!void {
        return e.encodeString(writer, @tagName(value));
    }

    pub fn encodeError(
        e: Self,
        writer: anytype,
        value: anyerror,
    ) @TypeOf(writer).Error!void {
        return e.encodeString(writer, @errorName(value));
    }

    pub fn encodeErrorUnion(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        if (value) |v| {
            return e.encode(writer, v);
        } else |err| {
            return e.encodeError(writer, err);
        }
    }

    pub fn encodeIterable(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        const _e = e.withField("");

        _ = try writer.write("[");

        for (0..value.len) |i| {
            if (i > 0) _ = try writer.write(", ");
            try _e.encode(writer, value[i]);
        }

        _ = try writer.write("]");
    }

    pub fn encodeNumber(
        _: Self,
        writer: anytype,
        value: anytype,
    ) @TypeOf(writer).Error!void {
        var std_writer = writer.stdWriter(&.{});
        var w: *std.Io.Writer = &std_writer.interface;
        w.print("{d}", .{value}) catch return std_writer.err.?;
    }

    pub fn encodeOptional(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        if (value) |v| {
            try e.encode(writer, v);
        } else {
            _ = try writer.write("null");
        }
    }

    pub fn encodePointer(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        if (slices.as(value)) |slc| {
            if (types.Child(@TypeOf(slc)) == u8 and utf8.isValid(slc)) {
                return e.encodeString(writer, slc);
            } else {
                return e.encodeIterable(writer, slc);
            }
        }

        const T = @TypeOf(value);
        const ti = @typeInfo(T).pointer;

        switch (ti.size) {
            .one => return e.encode(writer, value.*),
            else => return error.UnboundedPointer,
        }
    }

    const escape_seq: []const u8 = "\"\n";

    pub fn encodeString(
        _: Self,
        writer: anytype,
        value: []const u8,
    ) @TypeOf(writer).Error!void {
        _ = try writer.write("\"");

        var i: usize = 0;

        while (bytes.findAnyAt(i, value, escape_seq)) |res| {
            _ = try writer.write(value[i..res.index]);
            _ = try writer.write("\\");

            switch (res.value) {
                '\n' => _ = try writer.write("n"),
                else => _ = try writer.write(&.{res.value}),
            }

            i = res.index + 1;
        }

        if (i < value.len) _ = try writer.write(value[i..]);

        _ = try writer.write("\"");
    }

    pub fn encodeStruct(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T).@"struct";

        var should_space = false;

        inline for (ti.fields) |field| {
            blk: {
                const field_ti = @typeInfo(field.type);
                const field_val = @field(value, field.name);

                if (e.shouldOmit(field_val)) break :blk;

                if (should_space) _ = try writer.write(" ");
                should_space = true;

                var field_name: [field_size]u8 = undefined;

                const j = bytes.copyMany(&field_name, &.{
                    e.options.field_name,
                    if (e.options.field_name.len > 0) "." else "",
                    field.name,
                });

                const _e = e.withField(field_name[0..j]);

                if (comptime funcs.hasFn(field.type, "asCtxlog")) {
                    try field_val.asCtxlog(writer, _e);
                    break :blk;
                }

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

                if (should_field) {
                    _ = try writer.write(_e.options.field_name);
                    _ = try writer.write("=");
                }

                try _e.encode(writer, field_val);
            }
        }
    }

    pub fn encodeType(
        e: Self,
        writer: anytype,
        value: type,
    ) @TypeOf(writer).Error!void {
        try e.encodeString(writer, @typeName(value));
    }

    pub fn encodeUnion(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T).@"union";

        if (ti.tag_type == null) return EncodeError.UntaggedUnion;

        const Tag = ti.tag_type.?;

        inline for (ti.fields) |field| {
            if (value == @field(Tag, field.name)) {
                const field_val = @field(value, field.name);

                if (field.type == void) {
                    try e.encodeString(writer, field.name);
                } else {
                    try e.encode(writer, field_val);
                }
            }
        }
    }

    pub fn encodeVector(
        e: Self,
        writer: anytype,
        value: anytype,
    ) (EncodeError || @TypeOf(writer).Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T).vector;

        const arr: [ti.len]ti.child = value;
        try e.encodePointer(writer, &arr);
    }

    pub fn encodeVoid(
        _: Self,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = try writer.write("null");
    }

    pub fn shouldOmit(e: Self, value: anytype) bool {
        const T = @TypeOf(value);
        const ti = @typeInfo(T);

        return switch (ti) {
            .pointer => |ptr| if (ptr.size == .slice and value.len == 0)
                e.options.omit_empty
            else
                false,

            .optional => if (value == null) e.options.omit_null else false,
            .array => if (value.len == 0) e.options.omit_empty else false,
            .void => e.options.omit_null,
            else => false,
        };
    }

    pub fn withField(e: Self, field_name: []const u8) Self {
        var opts = e.options;
        opts.field_name = field_name;
        return Self{ .options = opts };
    }
};
