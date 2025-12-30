// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.Status`
//!
//! Status propagation and cancellation.

//const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types/root.zig");
const slices = types.slices;

const Self = @This();

//pub const State = enum {
//    active,
//    done,
//};

parent: ?*const Self = null,
//status: State = .active,
status: std.Thread.ResetEvent = .{},
children: slices.Slice(Self) = .{},

pub fn deinit(s: *Self, allocator: Allocator) void {
    s.children.deinit(allocator);
}

/// Propagates a cancellation signal.
pub fn done(s: *Self) void {
    if (s.isDone()) return;

    //if (comptime builtin.single_threaded) {
    //    s.status = .done;
    //} else {
    //    @atomicStore(State, &s.status, .done, .release);
    //}

    for (s.children.items()) |*child| child.done();
    s.status.set();
}

/// Checks if the state has been cancelled.
pub fn isDone(s: *const Self) bool {
    //if (s.parent != null and s.parent.?.isDone()) return true;

    //if (comptime builtin.single_threaded) {
    //    return s.status == .done;
    //} else {
    //    return @atomicLoad(State, &s.status, .acquire) == .done;
    //}

    return s.status.isSet();
}

/// Creates a sub-state with independent state propagation.
///
/// Sub-states will be done if any parent state is done.
pub fn sub(s: *Self, allocator: Allocator) Allocator.Error!*Self {
    return s.children.appendAndReturn(allocator, .{ .parent = s });
}

/// Waits until the state is cancelled.
pub fn wait(s: *Self) void {
    s.status.wait();
}
