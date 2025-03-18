// Copyright 2024 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.types.bytes`
//!
//! Utilities for working with slices of bytes.

const slices = @import("slices.zig");

/// Creates a new slice that contains all bytes from `these` and adds `that` at
/// the end of it.
pub fn append(allocator: anytype, these: []const u8, that: u8) ![]u8 {
    return slices.append(u8, allocator, these, that);
}

/// Checks if the given value may be a string, and returns it as a slice.
pub fn asString(val: anytype) ?[]const u8 {
    const slc = slices.as(val) orelse return null;
    if (@typeInfo(@TypeOf(slc)).pointer.child != u8) return null;
    return slc;
}

/// Creates a new slice that contains all bytes from `these` and `those`.
pub fn concat(allocator: anytype, these: []const u8, those: []const u8) ![]u8 {
    return slices.concat(u8, allocator, these, those);
}

/// Creates a new slice that contains all bytes from the given slices.
pub fn concatMany(allocator: anytype, these: []const []const u8) ![]u8 {
    return slices.concatMany(u8, allocator, these);
}

/// Copies bytes from `src` into `dst`.
///
/// Copying overlapping slices may cause unexpected results, see `copyLtr` and
/// `copyRtl` for explicit copying behavior.
///
/// The actual number of bytes copied is returned. This number is calculated as
/// the minimum of `dst.len` and `src.len`.
pub fn copy(dst: []u8, src: []const u8) usize {
    return slices.copy(u8, dst, src);
}

/// Copies bytes from `src` into `dst`. Bytes are copied from left to right one
/// by one.
///
/// ```
/// src = [1 2 3]
/// dst = [4 5 6]
///
/// src[0] = dst[0]
/// src[1] = dst[1]
/// src[2] = dst[2]
/// ```
///
/// The actual number of bytes copied is returned. This number is calculated as
/// the minimum of `dst.len` and `src.len`.
pub fn copyLtr(dst: []u8, src: []const u8) usize {
    return slices.copyLtr(u8, dst, src);
}

/// Copies bytes from `src` into `dst`. Bytes are copied from left to right one
/// by one.
///
/// ```
/// src = [1 2 3]
/// dst = [4 5 6]
///
/// src[0] = dst[0]
/// src[1] = dst[1]
/// src[2] = dst[2]
/// ```
///
/// The actual number of bytes copied is returned. This number is calculated as
/// the minimum of `dst.len` and `src.len`.
pub fn copyRtl(dst: []u8, src: []const u8) usize {
    return slices.copyRtl(u8, dst, src);
}

/// Checks if `these` ends with `suffix`.
pub fn endsWith(these: []const u8, suffix: []const u8) bool {
    return slices.endsWith(u8, these, suffix);
}

/// Checks if `these` is equal to `those`.
pub fn equal(these: []const u8, those: []const u8) bool {
    return slices.equal(u8, these, those);
}

/// Checks if `these` is equal to all the given slices.
pub fn equalAll(these: []const u8, all: []const []const u8) bool {
    return slices.equalAll(u8, these, all);
}

/// Checks if `these` is equal to any of the given slices.
pub fn equalAny(these: []const u8, any: []const []const u8) bool {
    return slices.equalAny(u8, these, any);
}

/// Finds the first appearance of `that` in `these` and returns its index.
pub fn find(these: []const u8, that: u8) ?usize {
    return slices.find(u8, these, that);
}

/// Finds the first appearance of `that` in `these`, starting from index `at`,
/// and returns its index.
pub fn findAt(at: usize, these: []const u8, that: u8) ?usize {
    return slices.findAt(u8, at, these, that);
}

/// Finds the first appearance of `those` in `these` and returns its index.
pub fn findSeq(these: []const u8, those: []const u8) ?usize {
    return slices.findSeq(u8, these, those);
}

/// Finds the first appearance of `those` in `these`, starting from index `at`,
/// and returns its index.
pub fn findSeqAt(at: usize, these: []const u8, those: []const u8) ?usize {
    return slices.findSeqAt(u8, at, these, those);
}

/// Checks if the given value may be a string.
pub fn isString(val: anytype) bool {
    if (slices.as(val)) |slc|
        return @typeInfo(@TypeOf(slc)).pointer.child == u8;

    return false;
}

/// Creates a mutable copy of the given string literal.
pub fn mut(comptime lit: []const u8) [lit.len]u8 {
    var new: [lit.len]u8 = undefined;
    _ = copy(&new, lit);
    return new;
}

/// Checks if `these` starts with `prefix`.
pub fn startsWith(these: []const u8, prefix: []const u8) bool {
    return slices.startsWith(u8, these, prefix);
}
