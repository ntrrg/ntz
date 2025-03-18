// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.types.funcs`
//!
//! Utilities for working with funcions and methods.

/// Returns true if `T` has a `name` public method. `T` may be pointer `*T`, in
/// which case, its child type will be used.
pub fn hasFn(comptime T: type, comptime name: [:0]const u8) bool {
    const ti = @typeInfo(T);

    if (ti == .pointer and ti.pointer.size == .one)
        return hasFn(ti.pointer.child, name);

    switch (ti) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {},
        else => return false,
    }

    if (!@hasDecl(T, name))
        return false;

    return @typeInfo(@TypeOf(@field(T, name))) == .@"fn";
}

/// Returns the infered error set from the return type of the given function.
pub fn ErrorSet(comptime func: anytype) type {
    const T = Return(func);
    const ti = @typeInfo(T);

    return ti.error_union.error_set;
}

/// Returns the return type of the given function.
pub fn Return(comptime func: anytype) type {
    const T = @TypeOf(func);
    const ti = @typeInfo(T);

    if (ti == .pointer and ti.pointer.size == .one)
        return Return(ti.pointer.child);

    return ti.@"fn".return_type orelse void;
}
