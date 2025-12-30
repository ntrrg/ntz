// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");
const testing = std.testing;

const ntz = @import("ntz");
const types = ntz.types;
const bytes = types.bytes;

const io_utils = ntz.io;

test "ntz.io" {
    // Readers.
    //_ = @import("counting_reader_test.zig");

    // Writers.
    //_ = @import("DynWriter_test.zig");
    _ = @import("writer_test.zig");
    _ = @import("buffered_writer_test.zig");
    _ = @import("counting_writer_test.zig");
    _ = @import("delimited_writer_test.zig");
    _ = @import("limited_writer_test.zig");
}
