// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.Status`
//!
//! Status propagation and cancellation.

//const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const types = @import("types/root.zig");
const slices = types.slices;

const Self = @This();

parent: ?*const Self = null,
status: Io.Event = .unset,
children: slices.Slice(Self) = .{},

pub fn deinit(s: *Self, allocator: Allocator) void {
    s.children.deinit(allocator);
}

/// Propagates a cancellation signal.
pub fn done(s: *Self, io: Io) void {
    if (s.isDone()) return;
    for (s.children.items()) |*child| child.done(io);
    s.status.set(io);
}

/// Checks if the state has been cancelled.
pub fn isDone(s: *const Self) bool {
    return s.status.isSet();
}

/// Creates a sub-state with independent state propagation.
///
/// Sub-states will be done if any parent state is done.
pub fn sub(s: *Self, allocator: Allocator) Allocator.Error!*Self {
    return s.children.appendAndReturn(allocator, .{
        .parent = s,
        .status = s.status,
    });
}

/// Waits until the state is cancelled.
pub fn wait(s: *Self, io: Io) void {
    s.status.wait(io);
}
