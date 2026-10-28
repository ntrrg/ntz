// Copyright 2026 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");
const types = ntz.types;
const bytes = types.bytes;
const errors = types.errors;

const tracing = ntz.id.tracing;

test "ntz.id.tracing" {}

test "ntz.id.tracing.new" {
    const io = testing.io;

    const id = try tracing.new(4, io, .secure);
    try std.testing.expectEqual(8, id.len);
    for (id) |c| try std.testing.expect(std.ascii.isHex(c));

    for (id) |b| {
        if (b != 0) break;
    } else return error.AllZero;
}

test "ntz.id.tracing.span" {
    const io = testing.io;

    const id = try tracing.span(io);
    try std.testing.expectEqual(16, id.len);
    for (id) |c| try std.testing.expect(std.ascii.isHex(c));

    for (id) |b| {
        if (b != 0) break;
    } else return error.AllZero;
}

test "ntz.id.tracing.trace" {
    const io = testing.io;

    const id = try tracing.trace(io);
    try std.testing.expectEqual(32, id.len);
    for (id) |c| try std.testing.expect(std.ascii.isHex(c));

    for (id) |b| {
        if (b != 0) break;
    } else return error.AllZero;
}
