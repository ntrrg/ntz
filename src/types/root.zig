// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.types`
//!
//! Utilities for working with data types.

const std = @import("std");

pub const bytes = @import("bytes.zig");
pub const enums = @import("enums.zig");
pub const errors = @import("errors.zig");
pub const funcs = @import("funcs.zig");
pub const slices = @import("slices.zig");
//pub const strings = @import("strings.zig");
pub const structs = @import("structs.zig");

/// Returns the child type of the given type.
///
/// Single pointer to array returns the array child type.
pub fn Child(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .pointer => |ti| switch (ti.size) {
            .one => switch (@typeInfo(ti.child)) {
                .array => |child_ti| return child_ti.child,
                else => ti.child,
            },

            else => ti.child,
        },

        .array => |ti| ti.child,
        .vector => |ti| ti.child,
        .optional => |ti| ti.child,
        else => @compileError(@typeName(T) ++ " has no child type"),
    };
}

/// Returns the type of the given field. `fp` may be a field name or a field
/// path.
///
/// A field path is a list of fields separated by periods (`.`). All elements
/// in the field path must be structs or unions, except for the last one.
pub fn Field(comptime T: type, comptime fp: []const u8) type {
    var field_T = T;
    var field_name, var rest = bytes.split(fp, '.');

    loop: while (true) {
        for (fields(field_T)) |f| {
            if (!bytes.equal(f.name, field_name)) continue;
            field_T = f.type;
            if (rest.len == 0) break :loop;
            field_name, rest = bytes.split(rest, '.');
            break;
        } else {
            @compileError("no field '" ++ field_name ++ "' on type " ++ @typeName(field_T));
        }
    }

    return field_T;
}

/// Returns the value of a field in `val`. `fp` may be a field name or a field
/// path.
///
/// This is equivalent to `x.a` or `x.a.b`, but it can be done
/// programmatically.
///
/// A field path is a list of fields separated by periods (`.`). All elements
/// in the field path must be structs or unions, except for the last one.
pub fn field(val: anytype, comptime fp: []const u8) Field(@TypeOf(val), fp) {
    const T = @TypeOf(val);
    const ti = @typeInfo(T);

    if (ti == .optional and @typeInfo(ti.optional.child) == .@"struct")
        return field(val orelse structs.init(ti.optional.child), fp);

    const field_name, const rest = comptime bytes.split(fp, '.');
    const field_val = @field(val, field_name);
    if (rest.len == 0) return field_val;
    return field(field_val, rest);
}

/// Returns the type of fields `T` contains. If `T` is a single pointer to a
/// sctruct or a union, this will use its child type.
pub fn Fields(comptime T: type) type {
    return sw: switch (@typeInfo(T)) {
        .@"struct" => std.builtin.Type.StructField,
        .@"union" => std.builtin.Type.UnionField,

        .pointer => |ti| switch (ti.size) {
            .one => continue :sw @typeInfo(ti.child),
            else => @compileError(@typeName(T) ++ " doesn't have fields"),
        },

        .optional => |ti| continue :sw @typeInfo(ti.child),
        else => @compileError(@typeName(T) ++ " doesn't have fields"),
    };
}

/// Returns the list of fields on `T`. If `T` is a single pointer to a sctruct
/// or a union, this will use its child type.
pub fn fields(comptime T: type) []const Fields(T) {
    return sw: switch (@typeInfo(T)) {
        .@"struct" => |ti| ti.fields,
        .@"union" => |ti| ti.fields,

        .pointer => |ti| switch (ti.size) {
            .one => continue :sw @typeInfo(ti.child),
            else => unreachable,
        },

        .optional => |ti| continue :sw @typeInfo(ti.child),
        else => unreachable,
    };
}

/// Sets the value of a field in `orig` to `val`. `fp` may be a field name or a
/// field path.
///
/// This is equivalent to `x.a = val` or `x.a.b = val`, but it can be done
/// programmatically.
///
/// A field path is a list of fields separated by periods (`.`). All elements
/// in the field path must be structs or unions, except for the last one.
pub fn setField(
    orig: anytype,
    comptime fp: []const u8,
    val: Field(@TypeOf(orig), fp),
) void {
    const T = @TypeOf(orig);
    const ti = @typeInfo(T);

    if (ti != .pointer)
        @compileError(@typeName(T) ++ " is not a pointer to a struct or a union");

    const child_ti = @typeInfo(ti.pointer.child);

    if (child_ti == .optional and @typeInfo(child_ti.optional.child) == .@"struct") {
        var _orig = orig.* orelse structs.init(child_ti.optional.child);
        setField(&_orig, fp, val);
        orig.* = _orig;
        return;
    }

    const field_name, const rest = comptime bytes.split(fp, '.');

    if (rest.len == 0) {
        @field(orig, field_name) = val;
        return;
    }

    return setField(&@field(orig, field_name), rest, val);
}
