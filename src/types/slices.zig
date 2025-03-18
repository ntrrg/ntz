// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

//! # `ntz.types.slices`
//!
//! Utilities for working with slices.

const types = @import("root.zig");
const errors = @import("errors.zig");

/// Creates a new slice that contains all items from `these` and adds `that` at
/// the end of it.
pub fn append(
    comptime T: type,
    allocator: anytype,
    these: []const T,
    that: T,
) errors.From(@TypeOf(allocator))![]T {
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
pub fn as(val: anytype) ?[]const types.Child(@TypeOf(val)) {
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

/// Returns the child type of the given slice-able type.
pub fn Child(comptime T: type) type {
    const err_msg = @typeName(T) ++ " is not a slice-able type";

    return switch (@typeInfo(T)) {
        .pointer => |ti| switch (ti.size) {
            .slice => ti.child,

            .one => switch (@typeInfo(ti.child)) {
                .array => |child_ti| return child_ti.child,
                else => @compileError(err_msg),
            },

            .many => if (ti.sentinel()) |_|
                ti.child
            else
                @compileError(err_msg),

            else => @compileError(err_msg),
        },

        .array => |ti| ti.child,
        else => @compileError(err_msg),
    };
}

/// Creates a new slice that contains all items from `these` and `those`.
pub fn concat(
    comptime T: type,
    allocator: anytype,
    these: []const T,
    those: []const T,
) errors.From(@TypeOf(allocator))![]T {
    var new = try allocator.alloc(T, these.len + those.len);
    errdefer allocator.free(new);
    _ = copyMany(T, new[0..], &.{ these, those });
    return new;
}

/// Creates a new slice that contains all items from the given slices.
pub fn concatMany(
    comptime T: type,
    allocator: anytype,
    these: []const []const T,
) errors.From(@TypeOf(allocator))![]T {
    var n: usize = 0;
    for (these) |s| n += s.len;
    var new = try allocator.alloc(T, n);
    errdefer allocator.free(new);
    _ = copyMany(T, new[0..], these);
    return new;
}

/// Copies up to `dst.len` elements from `src` into `dst`.
///
/// Cannot copy overlapping slices, use `copyLtr` and `copyRtl` instead.
///
/// The actual number of elements copied is returned.
pub fn copy(comptime T: type, dst: []T, src: []const T) usize {
    return copyAt(T, 0, dst, src);
}

/// Copies up to `dst.len - at` elements from `src` into `dst[at..]`.
///
/// Cannot copy overlapping slices, use `copyLtr` and `copyRtl` instead.
///
/// The actual number of elements copied is returned.
pub fn copyAt(comptime T: type, at: usize, dst: []T, src: []const T) usize {
    if (at > dst.len) return 0;
    const n = @min(dst.len - at, src.len);
    const j = @min(at + n, dst.len);
    @memcpy(dst[at..j], src[0..n]);
    return n;
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
/// The actual number of elements copied is returned.
pub fn copyLtr(comptime T: type, dst: []T, src: []const T) usize {
    const l = @min(dst.len, src.len);
    for (0..l) |i| dst[i] = src[i];
    return l;
}

/// Copies up to `dst.len` elements from various sources into `dst`.
///
/// The actual number of elements copied is returned.
pub fn copyMany(comptime T: type, dst: []T, srcs: []const []const T) usize {
    var i: usize = 0;

    for (srcs) |src| {
        i += copyAt(T, i, dst, src);
        if (i == dst.len) break;
    }

    return i;
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
/// The actual number of elements copied is returned.
pub fn copyRtl(comptime T: type, dst: []T, src: []const T) usize {
    const l = @min(dst.len, src.len);
    var i = l;
    while (i > 0) : (i -= 1) dst[i - 1] = src[i - 1];
    return l;
}

/// Counts how many times `that` appears in `these`.
pub fn count(comptime T: type, these: []const T, that: T) usize {
    return countAt(T, 0, these, that);
}

/// Counts how many times `that` appears in `these`, starting from index `at`.
pub fn countAt(comptime T: type, at: usize, these: []const T, that: T) usize {
    var i = at;
    var n: usize = 0;

    while (findAt(T, i, these, that)) |j| {
        n += 1;
        i = j + 1;
    }

    return n;
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
pub fn find(comptime T: type, these: []const T, that: T) ?usize {
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

pub fn FindResult(comptime T: type) type {
    return struct {
        index: usize,
        value: T,
    };
}

/// Finds the first appearance of any element from `those` in `these`, and
/// returns its index and the matching element.
pub fn findAny(
    comptime T: type,
    these: []const T,
    those: []const T,
) ?FindResult(T) {
    return findAnyAt(T, 0, these, those);
}

/// Finds the first appearance of any element from `those` in `these`, starting
/// from index `at`, and returns its index and the matching element.
pub fn findAnyAt(
    comptime T: type,
    at: usize,
    these: []const T,
    those: []const T,
) ?FindResult(T) {
    if (at > these.len) return null;

    for (at..these.len) |i|
        for (those) |that|
            if (these[i] == that) return .{ .index = i, .value = that };

    return null;
}

/// Finds the first appearance of `those` in `these` and returns its index.
pub fn findSeq(comptime T: type, these: []const T, those: []const T) ?usize {
    return findSeqAt(T, 0, these, those);
}

/// Finds the first appearance of `those` in `these`, starting from index `at`,
/// and returns its index.
pub fn findSeqAt(comptime T: type, at: usize, these: []const T, those: []const T) ?usize {
    if (those.len == 0) return null;
    if (those.len > these.len) return null;

    var i = at;

    while (i < these.len) {
        i = findAt(T, i, these, those[0]) orelse return null;
        if (startsWith(T, these[i..], those)) return i;
        i += 1;
    }

    return null;
}

/// Checks if the given value is a slice-able type (arrays and pointers).
///
/// If `val` is a type, this will check if the given type may be coerced to a
/// slice.
pub fn is(val: anytype) bool {
    return switch (@typeInfo(@TypeOf(val))) {
        .array => true,

        .pointer => |ti| switch (ti.size) {
            .slice => true,

            .one => switch (@typeInfo(ti.child)) {
                .array => true,
                else => false,
            },

            .many => if (ti.sentinel()) |_| true else false,
            .c => false,
        },

        else => false,
    };
}

/// Splits `these` in 2 at the first appearance of `that`. If `that` is not
/// found, `these` will be returned as the first part, and an empty slice as
/// the rest.
pub fn split(comptime T: type, these: []const T, that: T) [2][]const T {
    return splitAt(T, 0, these, that);
}

/// Splits `these` in 2 at the first appearance of `that`, starting from index
/// `at`. If `that` is not found, `these` will be returned as the first part,
/// and an empty slice as the rest.
pub fn splitAt(comptime T: type, at: usize, these: []const T, that: T) [2][]const T {
    const i = findAt(T, at, these, that) orelse return .{ these[at..], &.{} };
    return .{ these[at..i], these[i + 1 ..] };
}

/// Counts how many times `these` may be sliced using `that` as separator.
pub fn splitCount(comptime T: type, these: []const T, that: T) usize {
    if (these.len == 0) return 1;
    var i: usize = 0;
    var n: usize = 0;

    while (findAt(T, i, these, that)) |j| {
        n += 1;
        i = j + 1;
    }

    if (i < these.len or endsWith(T, these, &.{that})) n += 1;
    return n;
}

pub const SplitError = error{
    OutOfSpace,
};

/// Splits `these` at the appearances of `that` up to `n` times, the resulting
/// slices are stored in `out`. If `that` is not found, `these` will be
/// returned as the only item.
pub fn splitn(
    comptime T: type,
    n: usize,
    out: [][]const T,
    these: []const T,
    that: T,
) SplitError![]const []const T {
    return splitnAt(T, 0, n, out, these, that);
}

/// Splits `these` at the appearances of `that` up to `n` times, starting from
/// index `at`, the resulting slices are stored in `out`. If `that` is not
/// found, `these` will be returned as the only item.
pub fn splitnAt(
    comptime T: type,
    at: usize,
    n: usize,
    out: [][]const T,
    these: []const T,
    that: T,
) SplitError![]const []const T {
    if (out.len == 0) return error.OutOfSpace;

    if (these.len == 0 or n == 0) {
        out[0] = these;
        return out[0..1];
    }

    var i = at;
    var out_i: usize = 0;
    var split_count: usize = 0;

    while (findAt(T, i, these, that)) |j| {
        if (out_i >= out.len) return error.OutOfSpace;
        out[out_i] = these[i..j];
        out_i += 1;

        i = j + 1;
        split_count += 1;
        if (split_count >= n) break;
    }

    if (i < these.len or endsWith(T, these, &.{that})) {
        if (out_i >= out.len) return error.OutOfSpace;
        out[out_i] = these[i..these.len];
        out_i += 1;
    }

    return out[0..out_i];
}

/// Checks if `these` starts with `prefix`.
pub fn startsWith(comptime T: type, these: []const T, prefix: []const T) bool {
    if (prefix.len == 0) return false;
    if (prefix.len > these.len) return false;
    return equal(T, these[0..prefix.len], prefix);
}

// ////////
// Slice //
// ////////

/// Creates an empty slice.
///
/// If `void{}` is used as allocator, `*Alloc` variations of methods must be
/// used.
pub fn init(
    comptime T: type,
    allocator: anytype,
) Slice(T, @TypeOf(allocator)) {
    return .{ .ally = allocator };
}

/// Self growable slice.
///
/// Allocated memory is owned by the slice.
pub fn Slice(comptime T: type, comptime Allocator: type) type {
    return struct {
        const Self = @This();

        pub const AllocatorError = if (Allocator != void)
            errors.From(Allocator)
        else
            error{};

        ally: Allocator,
        data: [*]T = undefined,

        /// Number of items the slice may contain without memory allocations.
        cap: usize = 0,

        /// Number of items the slice contain.
        len: usize = 0,

        pub fn deinit(slc: Self) void {
            slc.deinitAlloc(slc.ally);
        }

        pub fn deinitAlloc(slc: Self, allocator: anytype) void {
            if (slc.cap > 0) allocator.free(slc.data[0..slc.cap]);
        }

        /// Available slots to be used without memory allocations.
        pub fn available(slc: Self) usize {
            return slc.cap - slc.len;
        }

        /// Adds the given item at the end of the slice.
        ///
        /// This only allocates memory when there is not enough capacity.
        pub fn append(slc: *Self, elem: T) AllocatorError!void {
            return slc.appendAlloc(slc.ally, elem);
        }

        /// Adds the given item at the end of the slice.
        ///
        /// This only allocates memory when there is not enough capacity.
        pub fn appendAlloc(
            slc: *Self,
            allocator: anytype,
            elem: T,
        ) errors.From(@TypeOf(allocator))!void {
            try slc.ensureCapacityAlloc(allocator, slc.len + 1);
            slc.data[slc.len] = elem;
            slc.len += 1;
        }

        /// Adds the given items at the end of the slice.
        ///
        /// This only allocates memory when there is not enough capacity.
        pub fn appendMany(slc: *Self, elems: []const T) AllocatorError!void {
            return slc.appendManyAlloc(slc.ally, elems);
        }

        /// Adds the given items at the end of the slice.
        ///
        /// This only allocates memory when there is not enough capacity.
        pub fn appendManyAlloc(
            slc: *Self,
            allocator: anytype,
            elems: []const T,
        ) errors.From(@TypeOf(allocator))!void {
            try slc.ensureCapacityAlloc(allocator, slc.len + elems.len);
            slc.len += copy(T, slc.data[slc.len .. slc.len + elems.len], elems);
        }

        /// Sets the slice as empty. This doesn't deallocates memory.
        pub fn clear(slc: *Self) void {
            slc.len = 0;
        }

        fn ensureCapacity(slc: *Self, size: usize) AllocatorError!void {
            return slc.ensureCapacityAlloc(slc.ally, size);
        }

        fn ensureCapacityAlloc(
            slc: *Self,
            allocator: anytype,
            size: usize,
        ) errors.From(@TypeOf(allocator))!void {
            if (size <= slc.cap) return;
            const new_size = @max(slc.cap * 2, size);
            try slc.setCapacityAlloc(allocator, new_size);
        }

        /// Returns the active items in the slice.
        pub fn items(slc: Self) []const T {
            return slc.data[0..slc.len];
        }

        /// Creates a copy of the slice with an underlying allocator.
        pub fn managed(
            slc: Self,
            allocator: anytype,
        ) Slice(T, @TypeOf(allocator)) {
            return .{
                .ally = allocator,
                .data = slc.data,
                .cap = slc.cap,
                .len = slc.len,
            };
        }

        /// Sets the slice capacity to the given size.
        pub fn setCapacity(slc: *Self, size: usize) AllocatorError!void {
            return slc.setCapacityAlloc(slc.ally, size);
        }

        /// Sets the slice capacity to the given size.
        pub fn setCapacityAlloc(
            slc: *Self,
            allocator: anytype,
            size: usize,
        ) errors.From(@TypeOf(allocator))!void {
            if (size == 0) {
                slc.len = 0;

                if (slc.cap > 0) {
                    allocator.free(slc.data[0..slc.cap]);
                    slc.cap = 0;
                    slc.len = 0;
                }

                return;
            }

            if (slc.cap > 0 and allocator.resize(slc.data[0..slc.cap], size)) {
                slc.cap = size;
                return;
            }

            var new_data = try allocator.alloc(T, size);

            if (slc.cap > 0) {
                _ = copy(T, new_data[0..], slc.data[0..slc.len]);
                allocator.free(slc.data[0..slc.cap]);
            }

            slc.cap = size;
            if (slc.len > size) slc.len = size;
            slc.data = new_data.ptr;
        }
    };
}
