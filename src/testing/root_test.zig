// Copyright 2024 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");

const testing = ntz.testing;

test "ntz.testing" {}

test "ntz.testing.expect" {
    try testing.expect(true);
    if (testing.expect(false)) return error.UnexpectedResult else |_| {}
}
