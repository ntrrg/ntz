// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

test "ntz.Status" {
    const ally = testing.allocator;

    var grand_parent = ntz.Status{ .allocator = ally };
    defer grand_parent.deinit();
    var parent = try grand_parent.sub();
    var child = try parent.sub();

    try testing.expect(!grand_parent.isDone());
    try testing.expect(!parent.isDone());
    try testing.expect(!child.isDone());

    parent.done();

    try testing.expect(!grand_parent.isDone());
    try testing.expect(parent.isDone());
    try testing.expect(child.isDone());
}
