// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.io`
//!
//! I/O operations and utilities.

const std = @import("std");

const types = @import("../types/root.zig");
const funcs = types.funcs;

// //////////
// Writers //
// //////////

//pub const DynWriter = @import("DynWriter.zig");

pub const Writer = @import("writer.zig").Writer;
pub const writer = @import("writer.zig").init;

pub const BufferedWriter = @import("buffered_writer.zig").BufferedWriter;
pub const bufferedWriter = @import("buffered_writer.zig").init;

pub const CountingWriter = @import("counting_writer.zig").CountingWriter;
pub const countingWriter = @import("counting_writer.zig").init;

pub const DelimitedWriter = @import("delimited_writer.zig").DelimitedWriter;
pub const delimitedWriter = @import("delimited_writer.zig").init;

pub const LimitedWriter = @import("limited_writer.zig").LimitedWriter;
pub const limitedWriter = @import("limited_writer.zig").init;
