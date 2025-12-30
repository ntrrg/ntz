// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.encoding.unicode`
//!
//! Contextual logging encoding.

const std = @import("std");
const Writer = std.Io.Writer;

const encoding = @import("../root.zig");
const unicode = encoding.unicode;
const utf8 = unicode.utf8;
const types = @import("../../types/root.zig");
const bytes = types.bytes;
const funcs = types.funcs;
const slices = types.slices;

pub const Encoder = struct {
    const Self = @This();

    pub const Error = error{
        UnboundedPointer,
        UnkownType,
        UntaggedUnion,
    } || bytes.SliceFixed.Error;

    /// Bytes to be escaped in strings.
    const escape_seq: []const u8 = "\"\n\r\t";

    pub const Options = struct {
        /// Field name.
        field_name: bytes.SliceFixed,

        /// Ignore empty struct fields (strings and arrays).
        omit_empty: bool = true,

        /// Ignore null struct fields.
        omit_null: bool = true,
    };

    options: Options,

    pub fn init(field_name_buf: []u8) Self {
        return .{
            .options = .{ .field_name = .{ .data = field_name_buf } },
        };
    }

    /// Encodes a value.
    ///
    /// If `val` has a method `.asCtxlog`, it will be used instead of default
    /// encoding. Field name writing is delegated to this method. This method
    /// must be of the following type:
    ///
    /// ```zig
    /// pub fn asCtxlog(_: Self, w: *std.Io.Writer, enc: Encoder) !void
    /// ```
    pub fn encode(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
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
            else => return error.UnkownType,
        }
    }

    pub fn encodeBoolean(
        _: Self,
        writer: *Writer,
        value: bool,
    ) Writer.Error!void {
        _ = try writer.write(if (value) "true" else "false");
    }

    pub fn encodeBytes(
        _: Self,
        writer: *Writer,
        value: []const u8,
    ) Writer.Error!void {
        var i: usize = 0;

        while (bytes.findAnyAt(i, value, escape_seq)) |res| {
            _ = try writer.write(value[i..res.index]);
            _ = try writer.write("\\");

            switch (res.value) {
                '\n' => _ = try writer.write("n"),
                '\r' => _ = try writer.write("r"),
                '\t' => _ = try writer.write("t"),
                else => _ = try writer.write(&.{res.value}),
            }

            i = res.index + 1;
        }

        if (i < value.len) _ = try writer.write(value[i..]);
    }

    pub fn encodeEnum(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) Writer.Error!void {
        return e.encodeString(writer, @tagName(value));
    }

    pub fn encodeError(
        e: Self,
        writer: *Writer,
        value: anyerror,
    ) Writer.Error!void {
        return e.encodeString(writer, @errorName(value));
    }

    pub fn encodeErrorUnion(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
        if (value) |v| {
            return e.encode(writer, v);
        } else |err| {
            return e.encodeError(writer, err);
        }
    }

    pub fn encodeIterable(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
        var _e = try e.withField("");

        _ = try writer.write("[");

        for (0..value.len) |i| {
            if (i > 0) _ = try writer.write(", ");
            try _e.encode(writer, value[i]);
        }

        _ = try writer.write("]");
    }

    pub fn encodeNumber(
        _: Self,
        writer: *Writer,
        value: anytype,
    ) Writer.Error!void {
        try writer.print("{d}", .{value});
    }

    pub fn encodeOptional(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
        if (value) |v| {
            try e.encode(writer, v);
        } else {
            _ = try writer.write("null");
        }
    }

    pub fn encodePointer(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
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

    pub fn encodeString(
        e: Self,
        writer: *Writer,
        value: []const u8,
    ) Writer.Error!void {
        _ = try writer.write("\"");
        try e.encodeBytes(writer, value);
        _ = try writer.write("\"");
    }

    pub fn encodeStruct(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T).@"struct";

        var should_space = false;

        inline for (ti.fields) |field| {
            blk: {
                if (e.shouldOmit(@field(value, field.name))) break :blk;
                if (should_space) _ = try writer.write(" ");
                const field_val = @field(value, field.name);
                try e.encodeStructField(writer, field, field_val);
                should_space = true;
            }
        }
    }

    pub fn encodeStructField(
        e: Self,
        writer: *Writer,
        field: std.builtin.Type.StructField,
        value: anytype,
    ) (Error || Writer.Error)!void {
        const _e = try e.withField(field.name);

        if (comptime funcs.hasFn(field.type, "asCtxlog")) {
            try value.asCtxlog(writer, _e);
            return;
        }

        if (e.shouldWriteField(value)) {
            _ = try writer.write(_e.options.field_name.items());
            _ = try writer.write("=");
        }

        try _e.encode(writer, value);
    }

    pub fn encodeType(e: Self, writer: *Writer, value: type) Writer.Error!void {
        try e.encodeString(writer, @typeName(value));
    }

    pub fn encodeUnion(
        e: Self,
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T).@"union";

        if (ti.tag_type == null) return error.UntaggedUnion;

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
        writer: *Writer,
        value: anytype,
    ) (Error || Writer.Error)!void {
        const T = @TypeOf(value);
        const ti = @typeInfo(T).vector;

        const arr: [ti.len]ti.child = value;
        try e.encodePointer(writer, &arr);
    }

    pub fn encodeVoid(_: Self, writer: *Writer) Writer.Error!void {
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

    pub fn shouldWriteField(_: Self, value: anytype) bool {
        switch (@typeInfo(@TypeOf(value))) {
            .@"struct" => return false,

            .optional => |child_ti| {
                if (@typeInfo(child_ti.child) == .@"struct" and
                    value != null)
                    return false;
            },

            .pointer => |child_ti| {
                if (child_ti.size == .one and
                    @typeInfo(child_ti.child) == .@"struct")
                    return false;
            },

            .@"union" => |child_ti| {
                if (child_ti.tag_type) |Tag| {
                    inline for (child_ti.fields) |u_field| {
                        if (value == @field(Tag, u_field.name)) {
                            if (@typeInfo(u_field.type) == .@"struct")
                                return false;
                        }
                    }
                }
            },

            else => return true,
        }

        return true;
    }

    pub fn withField(
        e: Self,
        field_name: []const u8,
    ) bytes.SliceFixed.Error!Self {
        var opts = e.options;

        if (field_name.len == 0) {
            opts.field_name.data = opts.field_name.data[opts.field_name.len..];
            opts.field_name.len = 0;
        } else {
            if (opts.field_name.len > 0) try opts.field_name.append('.');
            try opts.field_name.appendMany(field_name);
        }

        return Self{ .options = opts };
    }
};
