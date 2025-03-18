// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;

const slices = ntz.types.slices;

test "ntz.types.slices" {}

// append //

test "ntz.types.slices.append" {
    const ally = testing.allocator;

    const got = try slices.append(u8, ally, "hello, world", '!');
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "hello, world!");
}

test "ntz.types.slices.append: empty slice" {
    const ally = testing.allocator;

    const got = try slices.append(u8, ally, "", 'M');
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "M");
}

// as //

test "ntz.types.slices.as" {
    const array = [_]u8{ 'a', 'b', 0 };
    try testing.expectEql(@TypeOf(slices.as(array).?), []const u8);
    try testing.expectEql(@TypeOf(slices.as(&array).?), []const u8);
    try testing.expectEql(@TypeOf(slices.as("hello, world!").?), []const u8);

    const mpz: [*:0]const u8 = array[0..2 :0];
    const slc = slices.as(mpz).?;
    try testing.expectEql(@TypeOf(slc), []const u8);
    try testing.expectEql(slc.len, 2);

    const mp: [*]const u8 = &array;
    try testing.expectEql(slices.as(mp), null);
}

// Child //

test "ntz.types.slices.Child" {
    try testing.expectEql(slices.Child([0]u8), u8);
    try testing.expectEql(slices.Child(*u8), u8);
    try testing.expectEql(slices.Child(*[0]u8), u8);
    try testing.expectEql(slices.Child(*@Vector(0, u8)), @Vector(0, u8));
    try testing.expectEql(slices.Child([*]u8), u8);
    try testing.expectEql(slices.Child([*:0]u8), u8);
    try testing.expectEql(slices.Child([]u8), u8);
}

// concat //

test "ntz.types.slices.concat" {
    const ally = testing.allocator;

    const got = try slices.concat(u8, ally, "hello, ", "world!");
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "hello, world!");
}

test "ntz.types.slices.concat: empty" {
    const ally = testing.allocator;

    const got = try slices.concat(u8, ally, "", "");
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "");
}

test "ntz.types.slices.concat: empty these" {
    const ally = testing.allocator;

    const got = try slices.concat(u8, ally, "", "world");
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "world");
}

test "ntz.types.slices.concat: empty those" {
    const ally = testing.allocator;

    const got = try slices.concat(u8, ally, "hello", "");
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "hello");
}

// concatMany //

test "ntz.types.slices.concatMany" {
    const ally = testing.allocator;

    const got = try slices.concatMany(u8, ally, &.{ "hello", ", ", "world", "!" });
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "hello, world!");
}

test "ntz.types.slices.concatMany: empty" {
    const ally = testing.allocator;

    const got = try slices.concatMany(u8, ally, &.{});
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "");
}

test "ntz.types.slices.concatMany: empty slices" {
    const ally = testing.allocator;

    const got = try slices.concatMany(u8, ally, &.{ "", "" });
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "");
}

test "ntz.types.slices.concatMany: some empty slices" {
    const ally = testing.allocator;

    const got = try slices.concatMany(u8, ally, &.{ "", "world" });
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "world");
}

test "ntz.types.slices.concatMany: empty edges" {
    const ally = testing.allocator;

    const got = try slices.concatMany(u8, ally, &.{ "", "hello", "" });
    defer ally.free(got);
    try testing.expectEqlSlcs(u8, got, "hello");
}

// copy //

test "ntz.types.slices.copy" {
    const src = "abcde";
    var dst: [src.len]u8 = undefined;
    const n = slices.copy(u8, &dst, src);

    try testing.expectEqlSlcs(u8, &dst, src);
    try testing.expectEql(n, src.len);
}

// copyLtr //

test "ntz.types.slices.copyLtr" {
    const src = "abcde";
    var dst: [src.len]u8 = undefined;
    var n = slices.copyLtr(u8, &dst, src);

    try testing.expectEqlSlcs(u8, &dst, src);
    try testing.expectEql(n, src.len);

    n = slices.copyLtr(u8, dst[0..3], dst[2..]);

    try testing.expectEqlSlcs(u8, &dst, "cdede");
    try testing.expectEql(n, 3);

    _ = slices.copyLtr(u8, &dst, src);
    n = slices.copyLtr(u8, dst[2..], dst[0..3]);

    try testing.expectEqlSlcs(u8, &dst, "ababa");
    try testing.expectEql(n, 3);
}

// copyRtl //

test "ntz.types.slices.copyRtl" {
    const src = "abcde";
    var dst: [src.len]u8 = undefined;
    var n = slices.copyRtl(u8, &dst, src);

    try testing.expectEqlSlcs(u8, &dst, src);
    try testing.expectEql(n, src.len);

    n = slices.copyRtl(u8, dst[0..3], dst[2..]);

    try testing.expectEqlSlcs(u8, &dst, "edede");
    try testing.expectEql(n, 3);

    _ = slices.copyRtl(u8, &dst, src);
    n = slices.copyRtl(u8, dst[2..], dst[0..3]);

    try testing.expectEqlSlcs(u8, &dst, "ababc");
    try testing.expectEql(n, 3);
}

// count //

test "ntz.types.slices.count" {
    try testing.expectEql(slices.count(u8, "asd", 'a'), 1);
    try testing.expectEql(slices.count(u8, "asd", 's'), 1);
    try testing.expectEql(slices.count(u8, "asd", 'd'), 1);
    try testing.expectEql(slices.count(u8, "asd", 'f'), 0);
    try testing.expectEql(slices.count(u8, "www", 'w'), 3);

    try testing.expectEql(slices.countAt(u8, 1, "asd", 'a'), 0);
    try testing.expectEql(slices.countAt(u8, 0, "www", 'w'), 3);
    try testing.expectEql(slices.countAt(u8, 1, "www", 'w'), 2);
    try testing.expectEql(slices.countAt(u8, 2, "www", 'w'), 1);
}

// endsWith //

test "ntz.types.slices.endsWith" {
    try testing.expect(slices.endsWith(u8, "asd", "d"));
    try testing.expect(slices.endsWith(u8, "asd", "sd"));
    try testing.expect(slices.endsWith(u8, "asd", "asd"));
    try testing.expect(!slices.endsWith(u8, "asd", ""));
    try testing.expect(!slices.endsWith(u8, "asd", "q"));
    try testing.expect(!slices.endsWith(u8, "asd", "qwer"));
}

// equal //

test "ntz.types.slices.equal" {
    try testing.expect(slices.equal(u8, "asd", "asd"));
    try testing.expect(!slices.equal(u8, "qwe", "asd"));
    try testing.expect(!slices.equal(u8, "qwe", "asdf"));
}

test "ntz.types.slices.equal: same pointer" {
    const data: []const u8 = "hello, world!";
    try testing.expect(slices.equal(u8, data, data[0..]));
}

test "ntz.types.slices.equal: different pointer" {
    var a: [4]u8 = undefined;
    var b: [4]u8 = undefined;

    @memcpy(&a, "abcd");
    @memcpy(&b, "abcd");

    try testing.expect(slices.equal(u8, &a, &b));
}

// equalAll //

test "ntz.types.slices.equalAll" {
    try testing.expect(slices.equalAll(u8, "asd", &.{ "asd", "asd", "asd" }));
    try testing.expect(!slices.equalAll(u8, "asd", &.{ "qwe", "asd", "asd" }));
    try testing.expect(!slices.equalAll(u8, "asd", &.{ "asd", "qwe", "asd" }));
    try testing.expect(!slices.equalAll(u8, "asd", &.{ "asd", "asd", "qwe" }));
}

test "ntz.types.slices.equalAll: empty slices" {
    try testing.expect(!slices.equalAll(u8, "asd", &.{ "", "", "" }));
}

test "ntz.types.slices.equalAll: no slices" {
    try testing.expect(!slices.equalAll(u8, "asd", &.{}));
}

// equalAny //

test "ntz.types.slices.equalAny" {
    try testing.expect(slices.equalAny(u8, "asd", &.{ "asd", "asd", "asd" }));
    try testing.expect(slices.equalAny(u8, "asd", &.{ "qwe", "asd", "asd" }));
    try testing.expect(slices.equalAny(u8, "asd", &.{ "qwe", "qwe", "asd" }));
    try testing.expect(!slices.equalAny(u8, "asd", &.{ "qwe", "qwe", "qwe" }));
}

test "ntz.types.slices.equalAny: empty slices" {
    try testing.expect(!slices.equalAny(u8, "asd", &.{ "", "", "" }));
}

test "ntz.types.slices.equalAny: no slices" {
    try testing.expect(!slices.equalAny(u8, "asd", &.{}));
}

// find //

test "ntz.types.slices.find" {
    try testing.expectEql(slices.find(u8, "asd", 'a'), 0);
    try testing.expectEql(slices.find(u8, "asd", 's'), 1);
    try testing.expectEql(slices.find(u8, "asd", 'd'), 2);
    try testing.expectEql(slices.find(u8, "asd", 'f'), null);

    try testing.expectEql(slices.findAt(u8, 1, "asd", 'a'), null);
    try testing.expectEql(slices.findAt(u8, 3, "asd", 'd'), null);
    try testing.expectEql(slices.findAt(u8, 0, "asd", 'f'), null);
    try testing.expectEql(slices.findAt(u8, 3, "asd", 'f'), null);
}

// findSeq //

test "ntz.types.slices.findSeq" {
    try testing.expectEql(slices.findSeq(u8, "asd", "a"), 0);
    try testing.expectEql(slices.findSeq(u8, "asd", "as"), 0);
    try testing.expectEql(slices.findSeq(u8, "asd", "asd"), 0);
    try testing.expectEql(slices.findSeq(u8, "asd", "s"), 1);
    try testing.expectEql(slices.findSeq(u8, "asd", "sd"), 1);
    try testing.expectEql(slices.findSeq(u8, "asd", "d"), 2);
    try testing.expectEql(slices.findSeq(u8, "asd", "f"), null);

    try testing.expectEql(slices.findSeqAt(u8, 1, "asd", "a"), null);
    try testing.expectEql(slices.findSeqAt(u8, 1, "asd", "as"), null);
    try testing.expectEql(slices.findSeqAt(u8, 3, "asd", "d"), null);
    try testing.expectEql(slices.findSeqAt(u8, 0, "asd", "f"), null);
    try testing.expectEql(slices.findSeqAt(u8, 3, "asd", "f"), null);
}

// split //

test "ntz.types.slices.split" {
    var first, var rest = slices.split(u8, "asd", 'a');
    try testing.expectEqlSlcs(u8, first, "");
    try testing.expectEqlSlcs(u8, rest, "sd");

    first, rest = slices.split(u8, "asd", 's');
    try testing.expectEqlSlcs(u8, first, "a");
    try testing.expectEqlSlcs(u8, rest, "d");

    first, rest = slices.split(u8, "asd", 'd');
    try testing.expectEqlSlcs(u8, first, "as");
    try testing.expectEqlSlcs(u8, rest, "");

    first, rest = slices.split(u8, "asd", 'f');
    try testing.expectEqlSlcs(u8, first, "asd");
    try testing.expectEqlSlcs(u8, rest, "");

    first, rest = slices.splitAt(u8, 1, "asd", 'a');
    try testing.expectEqlSlcs(u8, first, "sd");
    try testing.expectEqlSlcs(u8, rest, "");

    first, rest = slices.splitAt(u8, 2, "asd", 'd');
    try testing.expectEqlSlcs(u8, first, "");
    try testing.expectEqlSlcs(u8, rest, "");

    first, rest = slices.splitAt(u8, 0, "asd", 'f');
    try testing.expectEqlSlcs(u8, first, "asd");
    try testing.expectEqlSlcs(u8, rest, "");
}

// splitCount //

test "ntz.types.slices.splitCount" {
    try testing.expectEql(slices.splitCount(u8, "asd", 'a'), 2);
    try testing.expectEql(slices.splitCount(u8, "asd", 's'), 2);
    try testing.expectEql(slices.splitCount(u8, "asd", 'd'), 2);
    try testing.expectEql(slices.splitCount(u8, "asd", 'f'), 1);
    try testing.expectEql(slices.splitCount(u8, "awswd", 'w'), 3);
    try testing.expectEql(slices.splitCount(u8, "wawswd", 'w'), 4);
    try testing.expectEql(slices.splitCount(u8, "awswdw", 'w'), 4);
    try testing.expectEql(slices.splitCount(u8, "awswdwf", 'w'), 4);
    try testing.expectEql(slices.splitCount(u8, "www", 'w'), 4);
    try testing.expectEql(slices.splitCount(u8, "", 'a'), 1);
}

// splitn //

test "ntz.types.slices.splitn" {
    var out: [4][]const u8 = undefined;

    var got = try slices.splitn(u8, 1, &out, "asd", 'a');
    var want: []const []const u8 = &.{ "", "sd" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 2);

    got = try slices.splitn(u8, 1, &out, "asd", 's');
    want = &.{ "a", "d" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 2);

    got = try slices.splitn(u8, 1, &out, "asd", 'd');
    want = &.{ "as", "" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 2);

    got = try slices.splitn(u8, 1, &out, "asd", 'f');
    want = &.{"asd"};
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 1);

    got = try slices.splitn(u8, 2, &out, "awswd", 'w');
    want = &.{ "a", "s", "d" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 3);

    got = try slices.splitn(u8, 3, &out, "wawswd", 'w');
    want = &.{ "", "a", "s", "d" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 4);

    got = try slices.splitn(u8, 3, &out, "awswdw", 'w');
    want = &.{ "a", "s", "d", "" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 4);

    got = try slices.splitn(u8, 1, &out, "awswd", 'w');
    want = &.{ "a", "swd" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 2);

    got = try slices.splitn(u8, 2, &out, "awswdwf", 'w');
    want = &.{ "a", "s", "dwf" };
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 3);

    got = try slices.splitn(u8, 0, &out, "www", 'w');
    want = &.{"www"};
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 1);

    got = try slices.splitn(u8, 1, &out, "", 'w');
    want = &.{""};
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 1);

    try testing.expectErr(
        slices.splitn(u8, 0, out[0..0], "asd", 's'),
        slices.SplitError.OutOfSpace,
    );

    try testing.expectErr(
        slices.splitn(u8, 1, out[0..1], "asd", 's'),
        slices.SplitError.OutOfSpace,
    );

    try testing.expectErr(
        slices.splitn(u8, 1, out[0..1], "asdf", 's'),
        slices.SplitError.OutOfSpace,
    );

    got = try slices.splitnAt(u8, 2, 1, &out, "asdf", 's');
    want = &.{"df"};
    for (0..want.len) |i| try testing.expectEqlSlcs(u8, got[i], want[i]);
    try testing.expectEql(got.len, 1);
}

// startsWith //

test "ntz.types.slices.startsWith" {
    try testing.expect(slices.startsWith(u8, "asd", "a"));
    try testing.expect(slices.startsWith(u8, "asd", "as"));
    try testing.expect(slices.startsWith(u8, "asd", "asd"));
    try testing.expect(!slices.startsWith(u8, "asd", ""));
    try testing.expect(!slices.startsWith(u8, "asd", "q"));
    try testing.expect(!slices.startsWith(u8, "asd", "qwer"));
}
