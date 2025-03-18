// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.types.slices`
//!
//! Utilities for working with slices.

/// Creates a new slice that contains all items from `these` and adds `that` at
/// the end of it.
pub fn append(
    comptime T: type,
    allocator: anytype,
    these: []const T,
    that: T,
) ![]T {
    var new = try allocator.alloc(T, these.len + 1);
    errdefer allocator.free(new);
    @memcpy(new[0..these.len], these);
    new[these.len] = that;
    return new;
}

/// Coerces the given slice-able type (arrays and pointers) to a slice.
///
/// This is normally done by the compiler, but for functions receiving
/// `anytype` arguments, it cannot be enforced.
pub fn as(val: anytype) ?[]const Child(@TypeOf(val)) {
    return switch (@typeInfo(@TypeOf(val))) {
        .array => &val,

        .pointer => |ti| switch (ti.size) {
            .slice => val,

            .many => blk: {
                if (ti.sentinel()) |sent| {
                    var l: usize = 0;
                    while (val[l] != sent) l += 1;
                    break :blk val[0..l];
                } else {
                    break :blk null;
                }
            },

            .one => switch (@typeInfo(ti.child)) {
                .array => val,
                else => null,
            },

            .c => null,
        },

        else => null,
    };
}

/// Returns the child type of the given slice-able type (arrays and pointers).
pub fn Child(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .array => |ti| ti.child,

        .pointer => |ti| switch (ti.size) {
            .one => switch (@typeInfo(ti.child)) {
                .array => |child_ti| return child_ti.child,
                else => ti.child,
            },

            else => return ti.child,
        },

        else => @compileError(@typeName(T) ++ " is not a slice-able type"),
    };
}

/// Creates a new slice that contains all items from `these` and `those`.
pub fn concat(
    comptime T: type,
    allocator: anytype,
    these: []const T,
    those: []const T,
) ![]T {
    var new = try allocator.alloc(T, these.len + those.len);
    errdefer allocator.free(new);
    @memcpy(new[0..these.len], these);
    @memcpy(new[these.len..], those);
    return new;
}

/// Creates a new slice that contains all items from the given slices.
pub fn concatMany(
    comptime T: type,
    allocator: anytype,
    these: []const []const T,
) ![]T {
    var len: usize = 0;
    for (these) |s| len += s.len;

    var new = try allocator.alloc(T, len);
    errdefer allocator.free(new);

    var i: usize = 0;

    for (these) |s| {
        @memcpy(new[i .. i + s.len], s);
        i += s.len;
    }

    return new;
}

/// Copies elements from `src` into `dst`.
///
/// Copying overlapping slices may cause unexpected results, see `copyLtr` and
/// `copyRtl` for explicit copying behavior.
///
/// The actual number of elements copied is returned. This number is calculated
/// as the minimum of `dst.len` and `src.len`.
pub fn copy(comptime T: type, dst: []T, src: []const T) usize {
    // For now, this uses `copyLtr`, but it is planned to change in the future.
    return copyLtr(T, dst, src);
}

/// Copies elements from `src` into `dst`. Elements are copied from left to
/// right one by one.
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
/// The actual number of elements copied is returned. This number is calculated
/// as the minimum of `dst.len` and `src.len`.
pub fn copyLtr(comptime T: type, dst: []T, src: []const T) usize {
    const l = @min(dst.len, src.len);
    for (0..l) |i| dst[i] = src[i];
    return l;
}

/// Copies elements from `src` into `dst`. Elements are copied from right to
/// left one by one.
///
/// ```
/// src = [1 2 3]
/// dst = [4 5 6]
///
/// src[2] = dst[2]
/// src[1] = dst[1]
/// src[0] = dst[0]
/// ```
///
/// The actual number of elements copied is returned. This number is calculated
/// as the minimum of `dst.len` and `src.len`.
pub fn copyRtl(comptime T: type, dst: []T, src: []const T) usize {
    const l = @min(dst.len, src.len);
    var i = l;
    while (i > 0) : (i -= 1) dst[i - 1] = src[i - 1];
    return l;
}

/// Checks if `these` ends with `suffix`.
pub fn endsWith(comptime T: type, these: []const T, suffix: []const T) bool {
    if (suffix.len == 0) return false;
    if (suffix.len > these.len) return false;
    return equal(T, suffix, these[these.len - suffix.len ..]);
}

/// Checks if `these` is equal to `those`.
pub fn equal(comptime T: type, these: []const T, those: []const T) bool {
    if (these.len != those.len) return false;
    if (these.ptr == those.ptr) return true;

    for (0..these.len) |i|
        if (these[i] != those[i]) return false;

    return true;
}

/// Checks if `these` is equal to all the given slices.
pub fn equalAll(comptime T: type, these: []const T, all: []const []const T) bool {
    if (all.len == 0) return false;

    for (all) |those|
        if (!equal(T, these, those)) return false;

    return true;
}

/// Checks if `these` is equal to any of the given slices.
pub fn equalAny(comptime T: type, these: []const T, any: []const []const T) bool {
    if (any.len == 0) return false;

    for (any) |those|
        if (equal(T, these, those)) return true;

    return false;
}

/// Finds the first appearance of `that` in `these` and returns its index.
pub inline fn find(comptime T: type, these: []const T, that: T) ?usize {
    return findAt(T, 0, these, that);
}

/// Finds the first appearance of `that` in `these`, starting from index `at`,
/// and returns its index.
pub fn findAt(comptime T: type, at: usize, these: []const T, that: T) ?usize {
    if (at > these.len) return null;

    for (at..these.len) |i|
        if (these[i] == that) return i;

    return null;
}

/// Finds the first appearance of `those` in `these` and returns its index.
pub inline fn findSeq(comptime T: type, these: []const T, those: []const T) ?usize {
    return findSeqAt(T, 0, these, those);
}

/// Finds the first appearance of `those` in `these`, starting from index `at`,
/// and returns its index.
pub fn findSeqAt(comptime T: type, at: usize, these: []const T, those: []const T) ?usize {
    if (those.len == 0) return null;
    if (those.len > these.len) return null;

    for (at..these.len) |i|
        if (startsWith(T, these[i..], those)) return i;

    return null;
}

/// Checks if `these` starts with `prefix`.
pub fn startsWith(comptime T: type, these: []const T, prefix: []const T) bool {
    if (prefix.len == 0) return false;
    if (prefix.len > these.len) return false;
    return equal(T, these[0..prefix.len], prefix);
}
