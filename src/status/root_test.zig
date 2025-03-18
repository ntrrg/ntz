// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

const status = ntz.status;

test "ntz.status" {
    var grand_parent = status.State{};
    var parent = grand_parent.sub();
    var child = parent.sub();

    try testing.expect(!grand_parent.isDone());
    try testing.expect(!parent.isDone());
    try testing.expect(!child.isDone());

    parent.done();

    try testing.expect(!grand_parent.isDone());
    try testing.expect(parent.isDone());
    try testing.expect(child.isDone());
}
