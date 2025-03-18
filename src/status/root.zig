// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.status`
//!
//! State propagation and cancellation.

const builtin = @import("builtin");

pub const State = struct {
    const Self = @This();

    pub const Status = enum {
        active,
        done,
    };

    status: Status = .active,
    parent: ?*const Self = null,

    /// Creates a sub-state with independent state propagation.
    ///
    /// Sub-states will be done if any parent state is done.
    pub fn sub(s: *const Self) Self {
        return .{ .status = .active, .parent = s };
    }

    /// Propagates a cancellation signal.
    pub fn done(s: *Self) void {
        if (s.isDone()) return;

        if (comptime builtin.single_threaded) {
            s.status = .done;
        } else {
            @atomicStore(Status, &s.status, .done, .release);
        }
    }

    /// Checks if this has been cancelled.
    pub fn isDone(s: *const Self) bool {
        if (s.parent != null and s.parent.?.isDone()) return true;

        if (comptime builtin.single_threaded) {
            return s.status == .done;
        } else {
            return @atomicLoad(Status, &s.status, .acquire) == .done;
        }
    }
};
