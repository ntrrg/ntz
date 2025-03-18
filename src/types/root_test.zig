// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const testing = ntz.testing;

const types = ntz.types;

test "ntz.types" {
    _ = @import("bytes_test.zig");
    _ = @import("enums_test.zig");
    _ = @import("errors_test.zig");
    _ = @import("funcs_test.zig");
    _ = @import("slices_test.zig");
    //_ = @import("strings_test.zig");
    _ = @import("structs_test.zig");
}

const Point = struct {
    x: usize,
    y: usize,
};

const Line = struct {
    name: []const u8 = "",
    a: Point,
    b: Point,
};

const Triangle = struct {
    a: Line,
    b: Line,
    c: Line,
};

const Rectangle = struct {
    a: Line,
    b: Line,
    c: Line,
    d: Line,
};

const Figure = union(enum) {
    triangle: Triangle,
    rectangle: Rectangle,
};

// Field //

test "ntz.types.Field" {
    try testing.expectEql(types.Field(Triangle, "a"), Line);
    try testing.expectEql(types.Field(Triangle, "b.a"), Point);
    try testing.expectEql(types.Field(Rectangle, "c.b.x"), usize);
    try testing.expectEql(types.Field(Figure, "rectangle.d.b.y"), usize);
}

// field //

test "ntz.types.field" {
    const val = Figure{ .triangle = .{
        .a = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } },
        .b = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 0, .y = 3 } },
        .c = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 3, .y = 0 } },
    } };

    try testing.expectEql(types.field(val, "triangle.a"), .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } });
    try testing.expectEql(types.field(val, "triangle.b.b"), .{ .x = 0, .y = 3 });
    try testing.expectEql(types.field(val, "triangle.c.b.x"), 3);
}

// Fields //

test "ntz.types.Fields" {
    try testing.expectEql(types.Fields(Triangle), std.builtin.Type.StructField);
    try testing.expectEql(types.Fields(*Triangle), std.builtin.Type.StructField);
    try testing.expectEql(types.Fields(Figure), std.builtin.Type.UnionField);
    try testing.expectEql(types.Fields(*Figure), std.builtin.Type.UnionField);
}

// fields //

test "ntz.types.fields" {
    try testing.expectEql(types.fields(Triangle).len, 3);
    try testing.expectEql(types.fields(Line).len, 3);
    try testing.expectEql(types.fields(*Point).len, 2);
    try testing.expectEql(types.fields(Figure).len, 2);
    try testing.expectEql(types.fields(*Figure).len, 2);
}

// setField //

test "ntz.types.setField" {
    var orig = Figure{ .triangle = .{
        .a = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } },
        .b = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 0, .y = 3 } },
        .c = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 3, .y = 0 } },
    } };

    try testing.expectEql(orig.triangle.a.b.x, 3);
    types.setField(&orig, "triangle.a.b.x", 2);
    try testing.expectEql(orig.triangle.a.b.x, 2);

    try testing.expectEqlStrs(orig.triangle.a.name, "");
    types.setField(&orig, "triangle.a.name", "Hypotenuse");
    try testing.expectEqlStrs(orig.triangle.a.name, "Hypotenuse");

    types.setField(&orig, "triangle.c.name", "Opposite");
    try testing.expectEqlStrs(orig.triangle.c.name, "Opposite");
    types.setField(&orig, "triangle.c.b", .{ .x = 2, .y = 0 });
    try testing.expectEql(orig.triangle.c.b.x, 2);
    try testing.expectEql(orig.triangle.c.b.y, 0);
}
