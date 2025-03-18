// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const ctxlog = ntz.encoding.ctxlog;

test "ntz.encoding.ctxlog.encode" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    const w = buf.writer();

    var e = ctxlog.Encoder.init();

    // Booleans.

    try e.encode(w, true);
    try testing.expectEqlStrs(buf.bytes(), "true");
    buf.clear();

    try e.encode(w, false);
    try testing.expectEqlStrs(buf.bytes(), "false");
    buf.clear();

    // Numbers.

    try e.encode(w, 42);
    try testing.expectEqlStrs(buf.bytes(), "42");
    buf.clear();

    try e.encode(w, 42.42);
    try testing.expectEqlStrs(buf.bytes(), "42.42");
    buf.clear();

    // Enums.

    const Proficiency = enum {
        beginner,
        average,
        pro,
        god,
    };

    try e.encode(w, Proficiency.pro);
    try testing.expectEqlStrs(buf.bytes(), "\"pro\"");
    buf.clear();

    try e.encode(w, .other_proficiency);
    try testing.expectEqlStrs(buf.bytes(), "\"other_proficiency\"");
    buf.clear();

    // Strings, arrays, vectors and pointers.

    try e.encode(w, "");
    try testing.expectEqlStrs(buf.bytes(), "\"\"");
    buf.clear();

    try e.encode(w, "hello, world!");
    try testing.expectEqlStrs(buf.bytes(), "\"hello, world!\"");
    buf.clear();

    try e.encode(w, "\"double quotes\" and 'single quotes'");
    try testing.expectEqlStrs(buf.bytes(), "\"\\\"double quotes\\\" and 'single quotes'\"");
    buf.clear();

    try e.encode(w, "new\nline");
    try testing.expectEqlStrs(buf.bytes(), "\"new\\nline\"");
    buf.clear();

    try e.encode(w, "\"double quotes\"\n'single quotes'");
    try testing.expectEqlStrs(buf.bytes(), "\"\\\"double quotes\\\"\\n'single quotes'\"");
    buf.clear();

    try e.encode(w, "\xF0\xFF\xFF\xFF");
    try testing.expectEqlStrs(buf.bytes(), "[240, 255, 255, 255]");
    buf.clear();

    try e.encode(w, [_]u8{});
    try testing.expectEqlStrs(buf.bytes(), "\"\"");
    buf.clear();

    try e.encode(w, [_]u8{ 'a', 'b', 'c' });
    try testing.expectEqlStrs(buf.bytes(), "\"abc\"");
    buf.clear();

    try e.encode(w, [_]u32{ 1, 2, 3 });
    try testing.expectEqlStrs(buf.bytes(), "[1, 2, 3]");
    buf.clear();

    try e.encode(w, @Vector(3, u8){ 'a', 'b', 'c' });
    try testing.expectEqlStrs(buf.bytes(), "\"abc\"");
    buf.clear();

    try e.encode(w, @Vector(3, u32){ 1, 2, 3 });
    try testing.expectEqlStrs(buf.bytes(), "[1, 2, 3]");
    buf.clear();

    const mpz: [*:0]const u8 = "hello, world!";
    try e.encode(w, mpz);
    try testing.expectEqlStrs(buf.bytes(), "\"hello, world!\"");
    buf.clear();

    const mpz32: [*:0]const u32 = &.{ 1, 2, 3, 0 };
    try e.encode(w, mpz32);
    try testing.expectEqlStrs(buf.bytes(), "[1, 2, 3]");
    buf.clear();

    var n: usize = 42;
    try e.encode(w, &n);
    try testing.expectEqlStrs(buf.bytes(), "42");
    buf.clear();

    const mp: [*]const u8 = "hello, world!";
    try testing.expectErr(e.encode(w, mp), ctxlog.Encoder.EncodeError.UnboundedPointer);
    buf.clear();

    const cp: [*c]const u8 = "hello, world!";
    try testing.expectErr(e.encode(w, cp), ctxlog.Encoder.EncodeError.UnboundedPointer);
    buf.clear();

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
        skills: []const Skill = &.{},
        pet: ?Pet = null,
    };

    const skills: []const Skill = &.{
        .{ .name = "Zig", .prof = .beginner },
        .{ .name = "Go", .prof = .average },
        .{ .name = "Breathing", .prof = .pro },
        .{ .name = "Eating", .prof = .god },
    };

    var person: Person = .{
        .name = "Miguel Angel",
        .height = 187,
        .skills = skills,
    };

    try e.encode(w, person);
    try testing.expectEqlStrs(buf.bytes(), "name=\"Miguel Angel\" height=187 skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"]");
    buf.clear();

    e.options.omit_empty = false;
    e.options.omit_null = false;
    person.skills = &.{};
    try e.encode(w, person);
    try testing.expectEqlStrs(buf.bytes(), "name=\"Miguel Angel\" height=187 skills=[] pet=null");
    buf.clear();
    e.options.omit_empty = true;
    e.options.omit_null = true;
    person.skills = skills;

    person.pet = .{ .name = "Draka", .kind = .dog };

    try e.encode(w, person);
    try testing.expectEqlStrs(buf.bytes(), "name=\"Miguel Angel\" height=187 skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] pet.name=\"Draka\" pet.kind=\"dog\"");
    buf.clear();

    person.pet.?.name = "";
    try e.encode(w, person);
    try testing.expectEqlStrs(buf.bytes(), "name=\"Miguel Angel\" height=187 skills=[name=\"Zig\" prof=\"beginner\", name=\"Go\" prof=\"average\", name=\"Breathing\" prof=\"pro\", name=\"Eating\" prof=\"god\"] pet.kind=\"dog\"");
    buf.clear();

    person.pet = null;
    person.skills = &.{};
    try e.encode(w, person);
    try testing.expectEqlStrs(buf.bytes(), "name=\"Miguel Angel\" height=187");
    buf.clear();

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

    try e.encode(w, Vehicle.bike);
    try testing.expectEqlStrs(buf.bytes(), "\"bike\"");
    buf.clear();

    try e.encode(w, Vehicle{ .car = 42 });
    try testing.expectEqlStrs(buf.bytes(), "42");
    buf.clear();

    try e.encode(w, Vehicle{ .plane = .{ .name = "Some name", .altitude_max = 5000 } });
    try testing.expectEqlStrs(buf.bytes(), "name=\"Some name\" altitude_max=5000");
    buf.clear();

    const Driver = struct {
        person: Person,
        vehicle: Vehicle,
    };

    try e.encode(w, Driver{ .person = person, .vehicle = .bike });
    try testing.expectEqlStrs(buf.bytes(), "person.name=\"Miguel Angel\" person.height=187 vehicle=\"bike\"");
    buf.clear();

    try e.encode(w, Driver{ .person = person, .vehicle = .{ .car = 42 } });
    try testing.expectEqlStrs(buf.bytes(), "person.name=\"Miguel Angel\" person.height=187 vehicle=42");
    buf.clear();

    try e.encode(w, Driver{ .person = person, .vehicle = .{ .plane = .{ .name = "Some name", .altitude_max = 5000 } } });
    try testing.expectEqlStrs(buf.bytes(), "person.name=\"Miguel Angel\" person.height=187 vehicle.name=\"Some name\" vehicle.altitude_max=5000");
    buf.clear();

    // Optionals.

    var optional: ?bool = null;

    try e.encode(w, optional);
    try testing.expectEqlStrs(buf.bytes(), "null");
    buf.clear();

    optional = true;

    try e.encode(w, optional);
    try testing.expectEqlStrs(buf.bytes(), "true");
    buf.clear();

    // Errors.

    const CtxlogTestingError = error{
        SomeError,
    };

    try e.encode(w, error.SomeError);
    try testing.expectEqlStrs(buf.bytes(), "\"SomeError\"");
    buf.clear();

    try e.encode(w, CtxlogTestingError.SomeError);
    try testing.expectEqlStrs(buf.bytes(), "\"SomeError\"");
    buf.clear();

    var may_err: CtxlogTestingError!bool = error.SomeError;

    try e.encode(w, may_err);
    try testing.expectEqlStrs(buf.bytes(), "\"SomeError\"");
    buf.clear();

    may_err = true;

    try e.encode(w, may_err);
    try testing.expectEqlStrs(buf.bytes(), "true");
    buf.clear();

    // Void.

    try e.encode(w, void{});
    try testing.expectEqlStrs(buf.bytes(), "null");
    buf.clear();

    // Types.

    try e.encode(w, bool);
    try testing.expectEqlStrs(buf.bytes(), "\"bool\"");
    buf.clear();

    // Custom encoding.

    const Point = struct {
        const Self = @This();

        x: u8,
        y: u8,

        pub fn asCtxlog(p: Self, writer: anytype, enc: ctxlog.Encoder) !void {
            if (enc.options.field_name.len > 0) {
                _ = try writer.write(enc.options.field_name);
                _ = try writer.write("=");
            }

            _ = try writer.write("\"{");
            _ = try writer.write(" x: ");
            try enc.encode(writer, p.x);
            _ = try writer.write(", y: ");
            try enc.encode(writer, p.y);
            _ = try writer.write(" }\"");
        }
    };

    try e.encode(w, Point{ .x = 10, .y = 11 });
    try testing.expectEqlStrs(buf.bytes(), "\"{ x: 10, y: 11 }\"");
    buf.clear();

    const Line = struct {
        p1: Point,
        p2: Point,
    };

    try e.encode(w, Line{ .p1 = .{ .x = 10, .y = 11 }, .p2 = .{ .x = 20, .y = 21 } });
    try testing.expectEqlStrs(buf.bytes(), "p1=\"{ x: 10, y: 11 }\" p2=\"{ x: 20, y: 21 }\"");
    buf.clear();
}
