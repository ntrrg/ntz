// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.types.errors`
//!
//! Utilities for working with errors.

const bytes = @import("bytes.zig");

/// Checks if `err` is part of the given error set.
pub fn of(comptime ErrorSet: type, err: anyerror) bool {
    const set_ti = @typeInfo(ErrorSet);

    if (set_ti != .error_set)
        @compileError(@typeName(ErrorSet) ++ " is not an error set");

    const err_name = @errorName(err);

    if (set_ti.error_set) |set| {
        for (set) |_err|
            if (bytes.equal(err_name, _err.name)) return true;
    } else {
        return true;
    }

    return false;
}
