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

const MaybeLine = struct {
    name: []const u8 = "",
    a: ?Point,
    b: ?Point,
};

const Triangle = struct {
    a: Line,
    b: Line,
    c: Line,
};

const MaybeTriangle = struct {
    const Self = @This();

    a: ?MaybeLine,
    b: ?MaybeLine,
    c: ?MaybeLine,
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

// Child //

test "ntz.types.Child" {
    try testing.expectEql(types.Child([]u8), u8);
    try testing.expectEql(types.Child([0]u8), u8);
    try testing.expectEql(types.Child(*u8), u8);
    try testing.expectEql(types.Child(*[0]u8), u8);
    try testing.expectEql(types.Child(@Vector(0, u8)), u8);
    try testing.expectEql(types.Child(*@Vector(0, u8)), @Vector(0, u8));
    try testing.expectEql(types.Child([*]u8), u8);
    try testing.expectEql(types.Child([*:0]u8), u8);
    try testing.expectEql(types.Child([*c]c_char), c_char);
    try testing.expectEql(types.Child(?u8), u8);
}

// Field //

test "ntz.types.Field" {
    try testing.expectEql(types.Field(Triangle, "a"), Line);
    try testing.expectEql(types.Field(Triangle, "b.a"), Point);
    try testing.expectEql(types.Field(Rectangle, "c.b.x"), usize);
    try testing.expectEql(types.Field(Figure, "rectangle.d.b.y"), usize);
    try testing.expectEql(types.Field(MaybeLine, "a"), ?Point);
    try testing.expectEql(types.Field(MaybeTriangle, "a"), ?MaybeLine);
    try testing.expectEql(types.Field(MaybeTriangle, "a.b"), ?Point);
}

// field //

test "ntz.types.field" {
    const fig_tri = Figure{ .triangle = .{
        .a = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } },
        .b = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 0, .y = 3 } },
        .c = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 3, .y = 0 } },
    } };

    try testing.expectEql(types.field(fig_tri, "triangle.a"), .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } });
    try testing.expectEql(types.field(fig_tri, "triangle.b.b"), .{ .x = 0, .y = 3 });
    try testing.expectEql(types.field(fig_tri, "triangle.c.b.x"), 3);

    const maybe_tri = MaybeTriangle{
        .a = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } },
        .b = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 0, .y = 3 } },
        .c = null,
    };

    try testing.expectEql(types.field(maybe_tri, "a"), .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } });
    try testing.expectEql(types.field(maybe_tri, "b.b"), .{ .x = 0, .y = 3 });
    try testing.expectEql(types.field(maybe_tri, "c.b.x"), 0);
}

// Fields //

test "ntz.types.Fields" {
    try testing.expectEql(types.Fields(Triangle), std.builtin.Type.StructField);
    try testing.expectEql(types.Fields(*Triangle), std.builtin.Type.StructField);
    try testing.expectEql(types.Fields(?Triangle), std.builtin.Type.StructField);
    try testing.expectEql(types.Fields(Figure), std.builtin.Type.UnionField);
    try testing.expectEql(types.Fields(*Figure), std.builtin.Type.UnionField);
    try testing.expectEql(types.Fields(?Figure), std.builtin.Type.UnionField);
}

// fields //

test "ntz.types.fields" {
    try testing.expectEql(types.fields(Triangle).len, 3);
    try testing.expectEql(types.fields(Line).len, 3);
    try testing.expectEql(types.fields(*Point).len, 2);
    try testing.expectEql(types.fields(?Point).len, 2);
    try testing.expectEql(types.fields(Figure).len, 2);
    try testing.expectEql(types.fields(*Figure).len, 2);
    try testing.expectEql(types.fields(?Figure).len, 2);
}

// setField //

test "ntz.types.setField" {
    var fig_tri = Figure{ .triangle = .{
        .a = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 3, .y = 0 } },
        .b = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 0, .y = 3 } },
        .c = .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 3, .y = 0 } },
    } };

    try testing.expectEql(fig_tri.triangle.a.b.x, 3);
    types.setField(&fig_tri, "triangle.a.b.x", 2);
    try testing.expectEql(fig_tri.triangle.a.b.x, 2);

    try testing.expectEqlStrs(fig_tri.triangle.a.name, "");
    types.setField(&fig_tri, "triangle.a.name", "Hypotenuse");
    try testing.expectEqlStrs(fig_tri.triangle.a.name, "Hypotenuse");

    types.setField(&fig_tri, "triangle.c.name", "Opposite");
    try testing.expectEqlStrs(fig_tri.triangle.c.name, "Opposite");
    types.setField(&fig_tri, "triangle.c.b", .{ .x = 2, .y = 0 });
    try testing.expectEql(fig_tri.triangle.c.b.x, 2);
    try testing.expectEql(fig_tri.triangle.c.b.y, 0);

    var maybe_tri = MaybeTriangle{
        .a = null,
        .b = null,
        .c = null,
    };

    types.setField(&maybe_tri, "a.a.y", 3);
    types.setField(&maybe_tri, "a.b.x", 2);
    types.setField(&maybe_tri, "a.name", "Hypotenuse");
    types.setField(&maybe_tri, "b", .{ .a = .{ .x = 0, .y = 0 }, .b = .{ .x = 0, .y = 3 } });
    types.setField(&maybe_tri, "c.name", "Opposite");
    types.setField(&maybe_tri, "c.a", .{ .x = 0, .y = 0 });
    types.setField(&maybe_tri, "c.b", .{ .x = 2, .y = 0 });

    try testing.expectEql(maybe_tri.a.?.a.?, fig_tri.triangle.a.a);
    try testing.expectEql(maybe_tri.a.?.b.?, fig_tri.triangle.a.b);
    try testing.expectEql(maybe_tri.b.?.a.?, fig_tri.triangle.b.a);
    try testing.expectEql(maybe_tri.b.?.b.?, fig_tri.triangle.b.b);
    try testing.expectEql(maybe_tri.c.?.a.?, fig_tri.triangle.c.a);
    try testing.expectEql(maybe_tri.c.?.b.?, fig_tri.triangle.c.b);
}
