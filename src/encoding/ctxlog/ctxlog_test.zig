// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const std = @import("std");

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const ctxlog = ntz.encoding.ctxlog;

test "ntz.encoding.ctxlog.encode" {
    const ally = testing.allocator;

    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const w = buf.writer();

    var enc = ctxlog.Encoder.init();

    // Booleans.

    try enc.encode(w, true);
    try testing.expectEqlStrs(buf.items, "true");
    buf.clearRetainingCapacity();

    try enc.encode(w, false);
    try testing.expectEqlStrs(buf.items, "false");
    buf.clearRetainingCapacity();

    // Numbers.

    try enc.encode(w, 42);
    try testing.expectEqlStrs(buf.items, "42");
    buf.clearRetainingCapacity();

    try enc.encode(w, 42.42);
    try testing.expectEqlStrs(buf.items, "42.42");
    buf.clearRetainingCapacity();

    // Enums.

    const Proficiency = enum {
        beginner,
        average,
        pro,
        god,
    };

    try enc.encode(w, Proficiency.pro);
    try testing.expectEqlStrs(buf.items, "\"pro\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, .other_proficiency);
    try testing.expectEqlStrs(buf.items, "\"other_proficiency\"");
    buf.clearRetainingCapacity();

    // Strings, arrays, vectors and pointers.

    try enc.encode(w, "");
    try testing.expectEqlStrs(buf.items, "\"\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, "hello, world!");
    try testing.expectEqlStrs(buf.items, "\"hello, world!\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, "\xF0\xFF\xFF\xFF");
    try testing.expectEqlStrs(buf.items, "[240, 255, 255, 255]");
    buf.clearRetainingCapacity();

    try enc.encode(w, [_]u8{});
    try testing.expectEqlStrs(buf.items, "\"\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, [_]u8{ 'a', 'b', 'c' });
    try testing.expectEqlStrs(buf.items, "\"abc\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, [_]u32{ 1, 2, 3 });
    try testing.expectEqlStrs(buf.items, "[1, 2, 3]");
    buf.clearRetainingCapacity();

    try enc.encode(w, @Vector(3, u8){ 'a', 'b', 'c' });
    try testing.expectEqlStrs(buf.items, "\"abc\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, @Vector(3, u32){ 1, 2, 3 });
    try testing.expectEqlStrs(buf.items, "[1, 2, 3]");
    buf.clearRetainingCapacity();

    const mpz: [*:0]const u8 = "hello, world!";
    try enc.encode(w, mpz);
    try testing.expectEqlStrs(buf.items, "\"hello, world!\"");
    buf.clearRetainingCapacity();

    const mpz32: [*:0]const u32 = &.{ 1, 2, 3, 0 };
    try enc.encode(w, mpz32);
    try testing.expectEqlStrs(buf.items, "[1, 2, 3]");
    buf.clearRetainingCapacity();

    var n: usize = 42;
    try enc.encode(w, &n);
    try testing.expectEqlStrs(buf.items, "42");
    buf.clearRetainingCapacity();

    const mp: [*]const u8 = "hello, world!";
    try testing.expectErr(enc.encode(w, mp), ctxlog.Encoder.EncodeError.InvalidPointer);
    buf.clearRetainingCapacity();

    const cp: [*c]const u8 = "hello, world!";
    try testing.expectErr(enc.encode(w, cp), ctxlog.Encoder.EncodeError.InvalidPointer);
    buf.clearRetainingCapacity();

    // Structs.

    const Skill = struct {
        name: []const u8,
        prof: Proficiency,
    };

    const Pet = struct {
        const Kind = enum {
            dog,
            cat,
        };

        name: []const u8,
        kind: Kind,
    };

    const Person = struct {
        name: []const u8,
        height: u8,
        skills: []const Skill,
        pet: ?Pet = null,
    };

    var person: Person = .{
        .name = "Miguel Angel",
        .height = 187,
        .skills = &.{
            .{ .name = "Zig", .prof = .beginner },
            .{ .name = "Go", .prof = .average },
            .{ .name = "Breathing", .prof = .pro },
            .{ .name = "Eating", .prof = .god },
        },
    };

    try enc.encode(w, person);
    try testing.expectEqlStrs(buf.items, "name=\"Miguel Angel\" height=187 skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"]");
    buf.clearRetainingCapacity();

    enc.options.omit_null = false;
    try enc.encode(w, person);
    try testing.expectEqlStrs(buf.items, "name=\"Miguel Angel\" height=187 skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] pet=null");
    buf.clearRetainingCapacity();
    enc.options.omit_null = true;

    person.pet = .{ .name = "Draka", .kind = .dog };

    try enc.encode(w, person);
    try testing.expectEqlStrs(buf.items, "name=\"Miguel Angel\" height=187 skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] pet.name=\"Draka\" pet.kind=\"dog\"");
    buf.clearRetainingCapacity();

    // Unions.

    const Plane = struct {
        name: []const u8,
        altitude_max: u64,
    };

    const Vehicle = union(enum) {
        bike: void,
        car: u8,
        plane: Plane,
        ship: []const u8,
    };

    try enc.encode(w, Vehicle.bike);
    try testing.expectEqlStrs(buf.items, "\"bike\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, Vehicle{ .car = 42 });
    try testing.expectEqlStrs(buf.items, "42");
    buf.clearRetainingCapacity();

    try enc.encode(w, Vehicle{ .plane = .{ .name = "Some name", .altitude_max = 5000 } });
    try testing.expectEqlStrs(buf.items, "name=\"Some name\" altitude_max=5000");
    buf.clearRetainingCapacity();

    const Driver = struct {
        person: Person,
        vehicle: Vehicle,
    };

    try enc.encode(w, Driver{ .person = person, .vehicle = .bike });
    try testing.expectEqlStrs(buf.items, "person.name=\"Miguel Angel\" person.height=187 person.skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] person.pet.name=\"Draka\" person.pet.kind=\"dog\" vehicle=\"bike\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, Driver{ .person = person, .vehicle = .{ .car = 42 } });
    try testing.expectEqlStrs(buf.items, "person.name=\"Miguel Angel\" person.height=187 person.skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] person.pet.name=\"Draka\" person.pet.kind=\"dog\" vehicle=42");
    buf.clearRetainingCapacity();

    try enc.encode(w, Driver{ .person = person, .vehicle = .{ .plane = .{ .name = "Some name", .altitude_max = 5000 } } });
    try testing.expectEqlStrs(buf.items, "person.name=\"Miguel Angel\" person.height=187 person.skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] person.pet.name=\"Draka\" person.pet.kind=\"dog\" vehicle.name=\"Some name\" vehicle.altitude_max=5000");
    buf.clearRetainingCapacity();

    // Optionals.

    var optional: ?bool = null;

    try enc.encode(w, optional);
    try testing.expectEqlStrs(buf.items, "null");
    buf.clearRetainingCapacity();

    optional = true;

    try enc.encode(w, optional);
    try testing.expectEqlStrs(buf.items, "true");
    buf.clearRetainingCapacity();

    // Errors.

    const CtxlogTestingError = error{
        SomeError,
    };

    try enc.encode(w, error.SomeError);
    try testing.expectEqlStrs(buf.items, "\"SomeError\"");
    buf.clearRetainingCapacity();

    try enc.encode(w, CtxlogTestingError.SomeError);
    try testing.expectEqlStrs(buf.items, "\"SomeError\"");
    buf.clearRetainingCapacity();

    var may_err: CtxlogTestingError!bool = error.SomeError;

    try enc.encode(w, may_err);
    try testing.expectEqlStrs(buf.items, "\"SomeError\"");
    buf.clearRetainingCapacity();

    may_err = true;

    try enc.encode(w, may_err);
    try testing.expectEqlStrs(buf.items, "true");
    buf.clearRetainingCapacity();

    // Void.

    try enc.encode(w, void{});
    try testing.expectEqlStrs(buf.items, "null");
    buf.clearRetainingCapacity();

    // Types.

    try enc.encode(w, bool);
    try testing.expectEqlStrs(buf.items, "\"bool\"");
    buf.clearRetainingCapacity();

    // Custom encoding.

    const Point = struct {
        const Self = @This();

        x: u8,
        y: u8,

        pub fn asLog(p: Self, writer: anytype, e: ctxlog.Encoder) !void {
            if (e.options.prefix.len > 0) {
                _ = try writer.write(e.options.prefix);
                _ = try writer.write("=");
            }

            _ = try writer.write("\"{");
            _ = try writer.write(" x: ");
            try e.encode(writer, p.x);
            _ = try writer.write(", y: ");
            try e.encode(writer, p.y);
            _ = try writer.write(" }\"");
        }
    };

    try enc.encode(w, Point{ .x = 10, .y = 11 });
    try testing.expectEqlStrs(buf.items, "\"{ x: 10, y: 11 }\"");
    buf.clearRetainingCapacity();

    const Line = struct {
        p1: Point,
        p2: Point,
    };

    try enc.encode(w, Line{ .p1 = .{ .x = 10, .y = 11 }, .p2 = .{ .x = 20, .y = 21 } });
    try testing.expectEqlStrs(buf.items, "p1=\"{ x: 10, y: 11 }\" p2=\"{ x: 20, y: 21 }\"");
    buf.clearRetainingCapacity();
}
