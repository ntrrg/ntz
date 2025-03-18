// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.Status`
//!
//! Status propagation and cancellation.

const builtin = @import("builtin");
const std = @import("std");

const types = @import("types/root.zig");
const slices = types.slices;

const Self = @This();

pub const Error = error{
    Interupted,
    NoAllocator,
};

pub const Interrupted = Error.Interupted;

//pub const State = enum {
//    active,
//    done,
//};

parent: ?*const Self = null,
//status: State = .active,
status: std.Thread.ResetEvent = .{},
allocator: ?std.mem.Allocator = null,
children: slices.Slice(*Self) = .{},

pub fn deinit(s: *Self) void {
    if (s.allocator == null) return;

    for (s.children.items()) |child| {
        child.deinit();
        s.allocator.?.destroy(child);
    }

    s.children.deinit(s.allocator.?);
}

/// Propagates a cancellation signal.
pub fn done(s: *Self) void {
    if (s.isDone()) return;

    //if (comptime builtin.single_threaded) {
    //    s.status = .done;
    //} else {
    //    @atomicStore(State, &s.status, .done, .release);
    //}

    for (s.children.items()) |child| child.done();
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
pub fn sub(s: *Self) !*Self {
    if (s.allocator == null) return Error.NoAllocator;
    const child = try s.allocator.?.create(Self);
    child.* = Self{ .parent = s, .allocator = s.allocator };
    try s.children.append(s.allocator.?, child);
    return child;
}

/// Waits until the state is cancelled.
pub fn wait(s: *Self) void {
    s.status.wait();
}
