// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");
const errors = ntz.types.errors;

test "ntz.types.errors" {}

test "ntz.types.errors.of" {
    const Error = error{SomeError};
    try testing.expect(errors.of(Error, error.SomeError));
    try testing.expect(!errors.of(Error, error.SomeOtherError));
    try testing.expect(errors.of(anyerror, error.SomeOtherError));
}
