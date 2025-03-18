// Copyright 2025 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

const status = ntz.status;

test "ntz.status" {
    var state = status.State{};
    var state_child = state.sub();
    var state_grand_child = state_child.sub();

    try testing.expect(!state.isDone());
    try testing.expect(!state_child.isDone());
    try testing.expect(!state_grand_child.isDone());

    state_child.done();

    try testing.expect(!state.isDone());
    try testing.expect(state_child.isDone());
    try testing.expect(state_grand_child.isDone());
}
