// Copyright 2024 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

const bytes = ntz.types.bytes;

test "ntz.types.bytes" {}

// append //

test "ntz.types.bytes.append" {
    const ally = testing.allocator;

    const got = try bytes.append(ally, "hello, world", '!');
    defer ally.free(got);
    try testing.expectEqlBytes(got, "hello, world!");
}

// as //

test "ntz.types.bytes.as" {
    const array = [_]u8{ 'a', 'b', 0 };
    try testing.expectEql(@TypeOf(bytes.as(array).?), []const u8);
    try testing.expectEql(@TypeOf(bytes.as(&array).?), []const u8);
    try testing.expectEql(@TypeOf(bytes.as("hello, world!").?), []const u8);

    const mpz: [*:0]const u8 = array[0..2 :0];
    const slc = bytes.as(mpz).?;
    try testing.expectEql(@TypeOf(slc), []const u8);
    try testing.expectEql(slc.len, 2);

    const mp: [*]const u8 = &array;
    try testing.expectEql(bytes.as(mp), null);
}

// concat //

test "ntz.types.bytes.concat" {
    const ally = testing.allocator;

    const got = try bytes.concat(ally, "hello, ", "world!");
    defer ally.free(got);
    try testing.expectEqlBytes(got, "hello, world!");
}

// concatMany //

test "ntz.types.bytes.concatMany" {
    const ally = testing.allocator;

    const got = try bytes.concatMany(ally, &.{ "hello", ", ", "world", "!" });
    defer ally.free(got);
    try testing.expectEqlBytes(got, "hello, world!");
}

// copy //

test "ntz.types.bytes.copy" {
    const src = "abcde";
    var dst: [src.len]u8 = undefined;
    var n = bytes.copy(&dst, src);

    try testing.expectEqlBytes(&dst, src);
    try testing.expectEql(n, src.len);

    n = bytes.copyAt(3, &dst, "ab");
    try testing.expectEqlBytes(&dst, "abcab");
    try testing.expectEql(n, 2);
}

// copyLtr //

test "ntz.types.bytes.copyLtr" {
    const src = "abcde";
    var dst: [src.len]u8 = undefined;
    var n = bytes.copyLtr(&dst, src);

    try testing.expectEqlBytes(&dst, src);
    try testing.expectEql(n, src.len);

    n = bytes.copyLtr(dst[0..3], dst[2..]);

    try testing.expectEqlBytes(&dst, "cdede");
    try testing.expectEql(n, 3);

    _ = bytes.copyLtr(&dst, src);
    n = bytes.copyLtr(dst[2..], dst[0..3]);

    try testing.expectEqlBytes(&dst, "ababa");
    try testing.expectEql(n, 3);
}

// copyMany //

test "ntz.types.bytes.copyMany" {
    const src1 = "ab";
    const src2 = "c";
    const src3 = "de";
    var dst: [5]u8 = undefined;
    const n = bytes.copyMany(&dst, &.{ src1, src2, src3 });

    try testing.expectEqlBytes(&dst, "abcde");
    try testing.expectEql(n, 5);
}

// copyRtl //

test "ntz.types.bytes.copyRtl" {
    const src = "abcde";
    var dst: [src.len]u8 = undefined;
    var n = bytes.copyRtl(&dst, src);

    try testing.expectEqlBytes(&dst, src);
    try testing.expectEql(n, src.len);

    n = bytes.copyRtl(dst[0..3], dst[2..]);

    try testing.expectEqlBytes(&dst, "edede");
    try testing.expectEql(n, 3);

    _ = bytes.copyRtl(&dst, src);
    n = bytes.copyRtl(dst[2..], dst[0..3]);

    try testing.expectEqlBytes(&dst, "ababc");
    try testing.expectEql(n, 3);
}

// count //

test "ntz.types.bytes.count" {
    try testing.expectEql(bytes.count("asd", 'a'), 1);
    try testing.expectEql(bytes.count("asd", 's'), 1);
    try testing.expectEql(bytes.count("asd", 'd'), 1);
    try testing.expectEql(bytes.count("asd", 'f'), 0);
    try testing.expectEql(bytes.count("www", 'w'), 3);

    try testing.expectEql(bytes.countAt(1, "asd", 'a'), 0);
    try testing.expectEql(bytes.countAt(0, "www", 'w'), 3);
    try testing.expectEql(bytes.countAt(1, "www", 'w'), 2);
    try testing.expectEql(bytes.countAt(2, "www", 'w'), 1);
}

// endsWith //

test "ntz.types.bytes.endsWith" {
    try testing.expect(bytes.endsWith("asd", "d"));
    try testing.expect(bytes.endsWith("asd", "sd"));
    try testing.expect(bytes.endsWith("asd", "asd"));
    try testing.expect(!bytes.endsWith("asd", ""));
    try testing.expect(!bytes.endsWith("asd", "q"));
    try testing.expect(!bytes.endsWith("asd", "qwer"));
}

// equal //

test "ntz.types.bytes.equal" {
    try testing.expect(bytes.equal("asd", "asd"));
    try testing.expect(!bytes.equal("qwe", "asd"));
    try testing.expect(!bytes.equal("qwe", "asdf"));
}

// equalAll //

test "ntz.types.bytes.equalAll" {
    try testing.expect(bytes.equalAll("asd", &.{ "asd", "asd", "asd" }));
    try testing.expect(!bytes.equalAll("asd", &.{ "qwe", "asd", "asd" }));
    try testing.expect(!bytes.equalAll("asd", &.{ "asd", "qwe", "asd" }));
    try testing.expect(!bytes.equalAll("asd", &.{ "asd", "asd", "qwe" }));
}

// equalAny //

test "ntz.types.bytes.equalAny" {
    try testing.expect(bytes.equalAny("asd", &.{ "asd", "asd", "asd" }));
    try testing.expect(bytes.equalAny("asd", &.{ "qwe", "asd", "asd" }));
    try testing.expect(bytes.equalAny("asd", &.{ "qwe", "qwe", "asd" }));
    try testing.expect(!bytes.equalAny("asd", &.{ "qwe", "qwe", "qwe" }));
}

// find //

test "ntz.types.bytes.find" {
    try testing.expectEql(bytes.find("asd", 'a'), 0);
    try testing.expectEql(bytes.find("asd", 's'), 1);
    try testing.expectEql(bytes.find("asd", 'd'), 2);
    try testing.expectEql(bytes.find("asd", 'f'), null);

    try testing.expectEql(bytes.findAt(1, "asd", 'a'), null);
    try testing.expectEql(bytes.findAt(3, "asd", 'd'), null);
    try testing.expectEql(bytes.findAt(0, "asd", 'f'), null);
    try testing.expectEql(bytes.findAt(3, "asd", 'f'), null);
}

// findAny //

test "ntz.types.bytes.findAny" {
    try testing.expectEql(
        bytes.findAny("asd", &.{ 'a', 's', 'd' }),
        .{ .index = 0, .value = 'a' },
    );

    try testing.expectEql(bytes.findAny("asd", &.{}), null);
    try testing.expectEql(bytes.findAny("asd", &.{'f'}), null);
    try testing.expectEql(bytes.findAny("asd", &.{ 'f', 'g' }), null);

    try testing.expectEql(
        bytes.findAnyAt(1, "asd", &.{ 'a', 's' }),
        .{ .index = 1, .value = 's' },
    );

    try testing.expectEql(bytes.findAnyAt(2, "asd", &.{ 'a', 's' }), null);
}

// findSeq //

test "ntz.types.bytes.findSeq" {
    try testing.expectEql(bytes.findSeq("asd", "a"), 0);
    try testing.expectEql(bytes.findSeq("asd", "as"), 0);
    try testing.expectEql(bytes.findSeq("asd", "asd"), 0);
    try testing.expectEql(bytes.findSeq("asd", "s"), 1);
    try testing.expectEql(bytes.findSeq("asd", "sd"), 1);
    try testing.expectEql(bytes.findSeq("asd", "d"), 2);
    try testing.expectEql(bytes.findSeq("asd", "f"), null);

    try testing.expectEql(bytes.findSeqAt(1, "asd", "a"), null);
    try testing.expectEql(bytes.findSeqAt(1, "asd", "as"), null);
    try testing.expectEql(bytes.findSeqAt(3, "asd", "d"), null);
    try testing.expectEql(bytes.findSeqAt(0, "asd", "f"), null);
    try testing.expectEql(bytes.findSeqAt(3, "asd", "f"), null);
}

// is //

test "ntz.types.bytes.is" {
    // Slices.

    var s: []const u8 = "";
    try testing.expect(bytes.is(s));

    s = "hello, world";
    try testing.expect(bytes.is(s));

    var ss: [:0]const u8 = "";
    try testing.expect(bytes.is(ss));

    ss = "hello, world";
    try testing.expect(bytes.is(ss));

    const s32: []const u32 = &.{ 1, 2, 3 };
    try testing.expect(!bytes.is(s32));

    // Arrays.

    var arr = bytes.mut("qwerry");
    arr[4] = 't';
    try testing.expect(bytes.is(arr));

    const arr32 = [_]u32{ 1, 2, 3 };
    try testing.expect(!bytes.is(arr32));

    // Pointers.

    try testing.expect(bytes.is(&arr));
    try testing.expect(!bytes.is(&arr32));

    const n = 42;
    try testing.expect(!bytes.is(&n));

    const mps: [*:0]const u8 = "hello, world";
    try testing.expect(bytes.is(mps));

    const mps32: [*:0]const u32 = &.{ 1, 2, 3, 0 };
    try testing.expect(!bytes.is(mps32));

    const mp: [*]const u8 = "hello, world";
    try testing.expect(!bytes.is(mp));

    const mp32: [*]const u32 = &.{ 1, 2, 3 };
    try testing.expect(!bytes.is(mp32));

    const cp: [*c]const u8 = "hello, world";
    try testing.expect(!bytes.is(cp));
}

// mut //

test "ntz.types.bytes.mut" {
    var in = bytes.mut("hello. world!");
    in[5] = ',';
    const want = "hello, world!";
    try testing.expectEqlBytes(&in, want);
}

// split //

test "ntz.types.bytes.split" {
    var first, var rest = bytes.split("asd", 'a');
    try testing.expectEqlBytes(first, "");
    try testing.expectEqlBytes(rest, "sd");

    first, rest = bytes.split("asd", 's');
    try testing.expectEqlBytes(first, "a");
    try testing.expectEqlBytes(rest, "d");

    first, rest = bytes.split("asd", 'd');
    try testing.expectEqlBytes(first, "as");
    try testing.expectEqlBytes(rest, "");

    first, rest = bytes.split("asd", 'f');
    try testing.expectEqlBytes(first, "asd");
    try testing.expectEqlBytes(rest, "");

    first, rest = bytes.splitAt(1, "asd", 'a');
    try testing.expectEqlBytes(first, "sd");
    try testing.expectEqlBytes(rest, "");

    first, rest = bytes.splitAt(2, "asd", 'd');
    try testing.expectEqlBytes(first, "");
    try testing.expectEqlBytes(rest, "");

    first, rest = bytes.splitAt(0, "asd", 'f');
    try testing.expectEqlBytes(first, "asd");
    try testing.expectEqlBytes(rest, "");
}

// splitCount //

test "ntz.types.bytes.splitCount" {
    try testing.expectEql(bytes.splitCount("asd", 'a'), 2);
    try testing.expectEql(bytes.splitCount("asd", 's'), 2);
    try testing.expectEql(bytes.splitCount("asd", 'd'), 2);
    try testing.expectEql(bytes.splitCount("asd", 'f'), 1);
}

// splitn //

test "ntz.types.bytes.splitn" {
    var out: [4][]const u8 = undefined;

    var got = try bytes.splitn(1, &out, "asd", 'a');
    var want: []const []const u8 = &.{ "", "sd" };
    for (0..want.len) |i| try testing.expectEqlBytes(got[i], want[i]);
    try testing.expectEql(got.len, 2);

    got = try bytes.splitn(1, &out, "asd", 's');
    want = &.{ "a", "d" };
    for (0..want.len) |i| try testing.expectEqlBytes(got[i], want[i]);
    try testing.expectEql(got.len, 2);

    got = try bytes.splitn(1, &out, "asd", 'd');
    want = &.{ "as", "" };
    for (0..want.len) |i| try testing.expectEqlBytes(got[i], want[i]);
    try testing.expectEql(got.len, 2);
}

// startsWith //

test "ntz.types.bytes.startsWith" {
    try testing.expect(bytes.startsWith("asd", "a"));
    try testing.expect(bytes.startsWith("asd", "as"));
    try testing.expect(bytes.startsWith("asd", "asd"));
    try testing.expect(!bytes.startsWith("asd", ""));
    try testing.expect(!bytes.startsWith("asd", "q"));
    try testing.expect(!bytes.startsWith("asd", "qwer"));
}

// /////////
// Buffer //
// /////////

test "ntz.types.bytes.Buffer" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();

    var n = try buf.write("hello, world");
    try testing.expectEqlBytes(buf.bytes(), "hello, world");
    try testing.expectEql(n, 12);

    n = try buf.write("!");
    try testing.expectEqlBytes(buf.bytes(), "hello, world!");
    try testing.expectEql(n, 1);

    n = try buf.write(" and bye..");
    try testing.expectEql(n, 10);
    try testing.expectEqlBytes(buf.bytes(), "hello, world! and bye..");

    buf.clear();
    try testing.expectEqlBytes(buf.bytes(), "");
}
