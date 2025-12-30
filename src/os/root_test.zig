// Copyright 2026 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");

const os = ntz.os;

test "ntz.os" {
    _ = @import("cli/root_test.zig");
}
