// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.io`
//!
//! I/O operations and utilities.

const std = @import("std");

const types = @import("../types/root.zig");
const funcs = types.funcs;

pub var std_in_mux: std.Thread.Mutex = .{};
pub const stdIn = std.io.getStdIn;

pub var std_out_mux: std.Thread.Mutex = .{};
pub const stdOut = std.io.getStdOut;

pub var std_err_mux: std.Thread.Mutex = .{};
pub const stdErr = std.io.getStdErr;

// //////////
// Writers //
// //////////

pub const DynWriter = @import("DynWriter.zig");

pub const Writer = @import("writer.zig").Writer;
pub const writer = @import("writer.zig").init;

pub const BufferedWriter = @import("buffered_writer.zig").BufferedWriter;
pub const bufferedWriter = @import("buffered_writer.zig").init;
pub const bufferedWriterWithSize = @import("buffered_writer.zig").initWithSize;

pub const CountingWriter = @import("counting_writer.zig").CountingWriter;
pub const countingWriter = @import("counting_writer.zig").init;

pub const DelimitedWriter = @import("delimited_writer.zig").DelimitedWriter;
pub const delimitedWriter = @import("delimited_writer.zig").init;

pub const LimitedWriter = @import("limited_writer.zig").LimitedWriter;
pub const limitedWriter = @import("limited_writer.zig").init;

/// Ensures all bytes are written into writer.
pub fn writeAll(w: anytype, data: []const u8) !usize {
    if (comptime funcs.hasFn(@TypeOf(w), "writeAll"))
        return w.writeAll(data);

    var n: usize = 0;
    while (n < data.len) n += try w.write(data[n..]);
    return n;
}
