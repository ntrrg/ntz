// Copyright 2024 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const test_options = @import("test_options");

const ntz = @import("ntz");
const encoding = ntz.encoding;
const unicode = encoding.unicode;
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const utf8 = unicode.utf8;

// Codepoints:
// - $ \x24 \u{0024}
// - ¢ \xC2\xA2 \u{00A2}
// - € \xE2\x82\xAC \u{20AC}
// - 💰 \xF0\x9F\x92\xB0 \u{1F4B0}

test "ntz.encoding.unicode.utf8" {}

test "ntz.encoding.unicode.utf8: all codepoints" {
    if (!test_options.run_slow) return testing.skip();

    for (0..0x10FFFF) |i| {
        if (unicode.isSurrogateCharacter(i)) continue;

        var buf: [4]u8 = undefined;

        const want = try unicode.Codepoint.init(@intCast(i));
        const n = try utf8.encode(buf[0..], want);

        var got = unicode.Codepoint{ .value = 0 };
        _ = try utf8.decode(&got, buf[0..n]);

        try testing.expectEql(got, want);
    }
}

// ///////////
// Encoding //
// ///////////

// encode //

test "ntz.encoding.unicode.utf8.encode: one byte" {
    const in = try unicode.Codepoint.init('$');
    const want = "$";

    var got: [1]u8 = undefined;
    const n = try utf8.encode(&got, in);

    try testing.expectEqlStrs(&got, want);
    try testing.expectEql(n, 1);
}

test "ntz.encoding.unicode.utf8.encode: two bytes" {
    const in = try unicode.Codepoint.init('¢');
    const want = "¢";

    var got: [2]u8 = undefined;
    const n = try utf8.encode(&got, in);

    try testing.expectEqlStrs(&got, want);
    try testing.expectEql(n, 2);
}

test "ntz.encoding.unicode.utf8.encode: three bytes" {
    const in = try unicode.Codepoint.init('€');
    const want = "€";

    var got: [3]u8 = undefined;
    const n = try utf8.encode(&got, in);

    try testing.expectEqlStrs(&got, want);
    try testing.expectEql(n, 3);
}

test "ntz.encoding.unicode.utf8.encode: four bytes" {
    const in = try unicode.Codepoint.init('💰');
    const want = "💰";

    var got: [4]u8 = undefined;
    const n = try utf8.encode(&got, in);

    try testing.expectEqlStrs(&got, want);
    try testing.expectEql(n, 4);
}

test "ntz.encoding.unicode.utf8.encode: small buffer" {
    const in = try unicode.Codepoint.init('$');
    var got: [0]u8 = undefined;

    try testing.expectErr(
        utf8.encode(&got, in),
        utf8.EncodeError.OutOfSpace,
    );
}

// encodeLen //

test "ntz.encoding.unicode.utf8.encodeLen" {
    // One byte.

    var in = try unicode.Codepoint.init(0);
    try testing.expectEql(utf8.encodeLen(in), 1);

    in = try unicode.Codepoint.init('$');
    try testing.expectEql(utf8.encodeLen(in), 1);

    in = try unicode.Codepoint.init(0b0111_1111);
    try testing.expectEql(utf8.encodeLen(in), 1);

    // Two bytes.

    in = try unicode.Codepoint.init(0b1000_0000);
    try testing.expectEql(utf8.encodeLen(in), 2);

    in = try unicode.Codepoint.init('¢');
    try testing.expectEql(utf8.encodeLen(in), 2);

    in = try unicode.Codepoint.init(0b0111_1111_1111);
    try testing.expectEql(utf8.encodeLen(in), 2);

    // Three bytes.

    in = try unicode.Codepoint.init(0b1000_0000_0000);
    try testing.expectEql(utf8.encodeLen(in), 3);

    in = try unicode.Codepoint.init('€');
    try testing.expectEql(utf8.encodeLen(in), 3);

    in = try unicode.Codepoint.init(0b1111_1111_1111_1111);
    try testing.expectEql(utf8.encodeLen(in), 3);

    // Four bytes.

    in = try unicode.Codepoint.init(0b0001_0000_0000_0000_0000);
    try testing.expectEql(utf8.encodeLen(in), 4);

    in = try unicode.Codepoint.init('💰');
    try testing.expectEql(utf8.encodeLen(in), 4);

    in = try unicode.Codepoint.init(0x10FFFF);
    try testing.expectEql(utf8.encodeLen(in), 4);
}

// ///////////
// Decoding //
// ///////////

// clear //

test "ntz.encoding.unicode.utf8.clear" {
    var in = "\xF0\x24\x80 \x80\xC2\xA2 \xC2\xE2\x82\xAC\xB0 \xF0\x9F\x92\xB0";
    const want = "\x24 \xC2\xA2 \xE2\x82\xAC \xF0\x9F\x92\xB0";
    var buf: [want.len]u8 = undefined;
    const got = try utf8.clear(&buf, in[0..]);
    try testing.expectEqlStrs(got, want);

    try testing.expectEqlStrs(try utf8.clear(buf[0..0], ""), "");
    try testing.expectEqlStrs(try utf8.clear(buf[0..4], "\xFF"), "");

    try testing.expectErr(
        utf8.clear(buf[0..1], "\xF0\x9F\x92\xB0"),
        utf8.ClearError.OutOfSpace,
    );
}

// clearIn //

test "ntz.encoding.unicode.utf8.clearIn" {
    var in = bytes.mut("\xF0\x24\x80 \x80\xC2\xA2 \xC2\xE2\x82\xAC\xB0 \xF0\x9F\x92\xB0");
    const want = "\x24 \xC2\xA2 \xE2\x82\xAC \xF0\x9F\x92\xB0";
    const got = utf8.clearIn(in[0..]);
    try testing.expectEqlStrs(got, want);
}

// countBytes //

test "ntz.encoding.unicode.utf8.countBytes" {
    try testing.expectEql(utf8.countBytes("\xFF\x24"), 1);
    try testing.expectEql(utf8.countBytes("\xFF\xC2\xA2"), 2);
    try testing.expectEql(utf8.countBytes("\xFF\xE2\x82\xAC"), 3);
    try testing.expectEql(utf8.countBytes("\xFF\xF0\x9F\x92\xB0"), 4);

    try testing.expectEql(
        utf8.countBytes("\x24 \xC2\xA2 \xE2\x82\xAC \xF0\x9F\x92\xB0"),
        13,
    );

    try testing.expectEql(utf8.countBytes("\xF0"), 0);
    try testing.expectEql(utf8.countBytes("\xFF\xFF\xFF\xFF"), 0);
    try testing.expectEql(utf8.countBytes("\xF0\xFF\xFF\xFF"), 0);
}

// decode //

test "ntz.encoding.unicode.utf8.decode: one byte" {
    const in = "$";
    const want = try unicode.Codepoint.init('$');

    var got = unicode.Codepoint{ .value = 0 };
    const n = try utf8.decode(&got, in);

    try testing.expectEql(got, want);
    try testing.expectEql(n, 1);
}

test "ntz.encoding.unicode.utf8.decode: two bytes" {
    const in = "¢";
    const want = try unicode.Codepoint.init('¢');

    var got = unicode.Codepoint{ .value = 0 };
    const n = try utf8.decode(&got, in);

    try testing.expectEql(got, want);
    try testing.expectEql(n, 2);
}

test "ntz.encoding.unicode.utf8.decode: three bytes" {
    const in = "€";
    const want = try unicode.Codepoint.init('€');

    var got = unicode.Codepoint{ .value = 0 };
    const n = try utf8.decode(&got, in);

    try testing.expectEql(got, want);
    try testing.expectEql(n, 3);
}

test "ntz.encoding.unicode.utf8.decode: four bytes" {
    const in = "💰";
    const want = try unicode.Codepoint.init('💰');

    var got = unicode.Codepoint{ .value = 0 };
    const n = try utf8.decode(&got, in);

    try testing.expectEql(got, want);
    try testing.expectEql(n, 4);
}

test "ntz.encoding.unicode.utf8.decode: empty" {
    var got = unicode.Codepoint{ .value = 0 };
    try testing.expectErr(utf8.decode(&got, ""), utf8.DecodeError.EmptyInput);
}

// decodeLen //

test "ntz.encoding.unicode.utf8.decodeLen" {
    try testing.expectEql(try utf8.decodeLen(""), 0);
    try testing.expectEql(try utf8.decodeLen("$"), 1);
    try testing.expectEql(try utf8.decodeLen("¢"), 2);
    try testing.expectEql(try utf8.decodeLen("€"), 3);
    try testing.expectEql(try utf8.decodeLen("\u{1F4B0}"), 4);

    try testing.expectEql(try utf8.decodeLen("$¢€\u{1F4B0}"), 1);
    try testing.expectEql(try utf8.decodeLen("¢€\u{1F4B0}$"), 2);
    try testing.expectEql(try utf8.decodeLen("€\u{1F4B0}$¢"), 3);
    try testing.expectEql(try utf8.decodeLen("\u{1F4B0}$¢€"), 4);
}

// decodeLenFb //

test "ntz.encoding.unicode.utf8.decodeLenFb" {
    try testing.expectEql(try utf8.decodeLenFb(0), 1);
    try testing.expectEql(try utf8.decodeLenFb(0x24), 1);
    try testing.expectEql(try utf8.decodeLenFb(0b0111_1111), 1);

    try testing.expectEql(try utf8.decodeLenFb(0b110_00000), 2);
    try testing.expectEql(try utf8.decodeLenFb(0xC2), 2);
    try testing.expectEql(try utf8.decodeLenFb(0b110_11111), 2);

    try testing.expectEql(try utf8.decodeLenFb(0b1110_0000), 3);
    try testing.expectEql(try utf8.decodeLenFb(0xE2), 3);
    try testing.expectEql(try utf8.decodeLenFb(0b1110_1111), 3);

    try testing.expectEql(try utf8.decodeLenFb(0b11110_000), 4);
    try testing.expectEql(try utf8.decodeLenFb(0xF0), 4);
    try testing.expectEql(try utf8.decodeLenFb(0b11110_111), 4);

    try testing.expectErr(
        utf8.decodeLenFb(0b111110_11),
        utf8.DecodeLenFBError.InvalidFirstByte,
    );

    try testing.expectErr(
        utf8.decodeLenFb(0b1111110_1),
        utf8.DecodeLenFBError.InvalidFirstByte,
    );

    try testing.expectErr(
        utf8.decodeLenFb(0b1111_1110),
        utf8.DecodeLenFBError.InvalidFirstByte,
    );

    try testing.expectErr(
        utf8.decodeLenFb(0b1111_1111),
        utf8.DecodeLenFBError.InvalidFirstByte,
    );
}

// isFirstByte //

test "ntz.encoding.unicode.utf8.isFirstByte" {
    try testing.expect(utf8.isFirstByte(0));
    try testing.expect(utf8.isFirstByte(0x24));
    try testing.expect(utf8.isFirstByte(0b0111_1111));

    try testing.expect(utf8.isFirstByte(0b110_00000));
    try testing.expect(utf8.isFirstByte(0xC2));
    try testing.expect(utf8.isFirstByte(0b110_11111));

    try testing.expect(utf8.isFirstByte(0b1110_0000));
    try testing.expect(utf8.isFirstByte(0xE2));
    try testing.expect(utf8.isFirstByte(0b1110_1111));

    try testing.expect(utf8.isFirstByte(0b11110_000));
    try testing.expect(utf8.isFirstByte(0xF0));
    try testing.expect(utf8.isFirstByte(0b11110_111));

    try testing.expect(!utf8.isFirstByte(0b10_000000));
    try testing.expect(!utf8.isFirstByte(0b111110_11));
    try testing.expect(!utf8.isFirstByte(0b1111110_1));
    try testing.expect(!utf8.isFirstByte(0b1111_1110));
    try testing.expect(!utf8.isFirstByte(0b1111_1111));
}

// isIntermediateByte //

test "ntz.encoding.unicode.utf8.isIntermediateByte" {
    try testing.expect(!utf8.isIntermediateByte(0b0111_1111));
    try testing.expect(utf8.isIntermediateByte(0b10_000000));
    try testing.expect(utf8.isIntermediateByte(0b10_111111));
    try testing.expect(!utf8.isIntermediateByte(0b11_000000));
}

// isValid //

test "ntz.encoding.unicode.utf8.isValid" {
    try testing.expect(utf8.isValid(""));
    try testing.expect(utf8.isValid("$"));
    try testing.expect(utf8.isValid("¢"));
    try testing.expect(utf8.isValid("€"));
    try testing.expect(utf8.isValid("\u{1F4B0}"));
    try testing.expect(utf8.isValid("$¢€\u{1F4B0}"));
    try testing.expect(utf8.isValid("\x24 \xC2\xA2 \xE2\x82\xAC \xF0\x9F\x92\xB0"));
    try testing.expect(!utf8.isValid("\x80\x80\x80\x80\x80"));
}

// len //

test "ntz.encoding.unicode.utf8.len" {
    try testing.expectEql(try utf8.len(""), 0);
    try testing.expectEql(try utf8.len("$"), 1);
    try testing.expectEql(try utf8.len("¢"), 1);
    try testing.expectEql(try utf8.len("€"), 1);
    try testing.expectEql(try utf8.len("💰"), 1);
    try testing.expectEql(try utf8.len("$¢€\u{1F4B0}"), 4);

    try testing.expectEql(try utf8.len("hello, world $!"), 15);
    try testing.expectEql(try utf8.len("hello, world ¢!"), 15);
    try testing.expectEql(try utf8.len("hello, world €!"), 15);
    try testing.expectEql(try utf8.len("hello, world \u{1F4B0}!"), 15);
}

// nextValidPos //
// nextValidPosFrom //

test "ntz.encoding.unicode.utf8.nextValidPos" {
    try testing.expectEql(utf8.nextValidPos(""), null);
    try testing.expectEql(utf8.nextValidPos("\x24"), .{ .i = 0, .j = 1 });
    try testing.expectEql(utf8.nextValidPos("\xC2\xA2"), .{ .i = 0, .j = 2 });
    try testing.expectEql(utf8.nextValidPos("\xE2\x82\xAC"), .{ .i = 0, .j = 3 });
    try testing.expectEql(utf8.nextValidPos("\xF0\x9F\x92\xB0"), .{ .i = 0, .j = 4 });
    try testing.expectEql(utf8.nextValidPos("\x80\x80\x80\x80\x80"), null);

    const in = "\xF0\x24\x80\x80\xC2\xA2\xC2\xE2\x82\xAC\xB0\xF0\x9F\x92\xB0";
    try testing.expectEql(utf8.nextValidPos(in), .{ .i = 1, .j = 2 });
    try testing.expectEql(utf8.nextValidPosFrom(2, in), .{ .i = 4, .j = 6 });
    try testing.expectEql(utf8.nextValidPosFrom(5, in), .{ .i = 7, .j = 10 });
    try testing.expectEql(utf8.nextValidPosFrom(8, in), .{ .i = 11, .j = 15 });
    try testing.expectEql(utf8.nextValidPosFrom(12, in), null);
}

// validate //

test "ntz.encoding.unicode.utf8.validate" {
    try testing.expectEql(try utf8.validate(null, "\x24"), 1);
    try testing.expectEql(try utf8.validate(null, "\xC2\xA2"), 2);
    try testing.expectEql(try utf8.validate(null, "\xE2\x82\xAC"), 3);
    try testing.expectEql(try utf8.validate(null, "\xF0\x9F\x92\xB0"), 4);

    try testing.expectEql(
        try utf8.validate(null, "\x24 \xC2\xA2 \xE2\x82\xAC \xF0\x9F\x92\xB0"),
        1,
    );
}

test "ntz.encoding.unicode.utf8.validate: invalid bytes" {
    var diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validate(&diag, ""),
        utf8.ValidateError.EmptyInput,
    );

    try testing.expectEql(diag.index, 0);
    try testing.expectEql(diag.expected_len, 0);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validate(&diag, "\xFF\x0F\x0F\x0F"),
        utf8.ValidateError.InvalidFirstByte,
    );

    try testing.expectEql(diag.index, 0);
    try testing.expectEql(diag.expected_len, 0);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validate(&diag, "\xF0"),
        utf8.ValidateError.IncompleteInput,
    );

    try testing.expectEql(diag.index, 0);
    try testing.expectEql(diag.expected_len, 4);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validate(&diag, "\xF0\x0F\x0F\x0F"),
        utf8.ValidateError.InvalidIntermediateByte,
    );

    try testing.expectEql(diag.index, 1);
    try testing.expectEql(diag.expected_len, 4);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validate(&diag, "\xF0\x9F\x0F\x0F"),
        utf8.ValidateError.InvalidIntermediateByte,
    );

    try testing.expectEql(diag.index, 2);
    try testing.expectEql(diag.expected_len, 4);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validate(&diag, "\xF0\x9F\x92\x0F"),
        utf8.ValidateError.InvalidIntermediateByte,
    );

    try testing.expectEql(diag.index, 3);
    try testing.expectEql(diag.expected_len, 4);
}

// validateAll //

test "ntz.encoding.unicode.utf8.validateAll" {
    try testing.expectEql(try utf8.validateAll(null, ""), 0);
    try testing.expectEql(try utf8.validateAll(null, "\x24"), 1);
    try testing.expectEql(try utf8.validateAll(null, "\xC2\xA2"), 1);
    try testing.expectEql(try utf8.validateAll(null, "\xE2\x82\xAC"), 1);
    try testing.expectEql(try utf8.validateAll(null, "\xF0\x9F\x92\xB0"), 1);

    try testing.expectEql(
        try utf8.validateAll(null, "\x24 \xC2\xA2 \xE2\x82\xAC \xF0\x9F\x92\xB0"),
        7,
    );
}

test "ntz.encoding.unicode.utf8.validateAll: invalid bytes" {
    var diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validateAll(&diag, " \xFF\x0F\x0F\x0F"),
        utf8.ValidateAllError.InvalidFirstByte,
    );

    try testing.expectEql(diag.index, 1);
    try testing.expectEql(diag.expected_len, 0);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validateAll(&diag, " \xF0"),
        utf8.ValidateAllError.IncompleteInput,
    );

    try testing.expectEql(diag.index, 1);
    try testing.expectEql(diag.expected_len, 4);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validateAll(&diag, " \xF0\x0F\x0F\x0F"),
        utf8.ValidateAllError.InvalidIntermediateByte,
    );

    try testing.expectEql(diag.index, 2);
    try testing.expectEql(diag.expected_len, 4);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validateAll(&diag, " \xF0\x9F\x0F\x0F"),
        utf8.ValidateAllError.InvalidIntermediateByte,
    );

    try testing.expectEql(diag.index, 3);
    try testing.expectEql(diag.expected_len, 4);

    diag = utf8.Diagnostic{};

    try testing.expectErr(
        utf8.validateAll(&diag, " \xF0\x9F\x92\x0F"),
        utf8.ValidateAllError.InvalidIntermediateByte,
    );

    try testing.expectEql(diag.index, 4);
    try testing.expectEql(diag.expected_len, 4);
}

// ///////////
// Iterator //
// ///////////

//test "ntz.encoding.unicode.utf8.Iterator.get" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try testing.expectEql(try it.get(3), try unicode.Codepoint.init('💰'));
//    try testing.expectEql(try it.get(2), try unicode.Codepoint.init('€'));
//    try testing.expectEql(try it.get(1), try unicode.Codepoint.init('¢'));
//    try testing.expectEql(try it.get(0), try unicode.Codepoint.init('$'));
//
//    try testing.expectEql(
//        try utf8.get("$\xFF", 0),
//        try unicode.Codepoint.init('$'),
//    );
//
//    try testing.expectErr(
//        utf8.get("$\xFF", 1),
//        utf8.Iterator.GetError.InvalidFirstByte,
//    );
//
//    try testing.expectEql(
//        try utf8.get("$\xF0", 0),
//        try unicode.Codepoint.init('$'),
//    );
//
//    try testing.expectErr(
//        utf8.get("$\xF0", 1),
//        utf8.Iterator.GetError.IncompleteInput,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.getBytes" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try testing.expectEqlStrs(try it.getBytes(3), "💰");
//    try testing.expectEqlStrs(try it.getBytes(2), "€");
//    try testing.expectEqlStrs(try it.getBytes(1), "¢");
//    try testing.expectEqlStrs(try it.getBytes(0), "$");
//    try testing.expectEqlStrs(try it.nextBytes(), "$");
//
//    try testing.expectEqlStrs(try utf8.getBytes("$\xFF", 0), "$");
//
//    try testing.expectErr(
//        utf8.getBytes("$\xFF", 1),
//        utf8.Iterator.GetBytesError.InvalidFirstByte,
//    );
//
//    try testing.expectEqlStrs(try utf8.getBytes("$\xF0", 0), "$");
//
//    try testing.expectErr(
//        utf8.getBytes("$\xF0", 1),
//        utf8.Iterator.GetBytesError.IncompleteInput,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.index" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try testing.expectEql(try it.index(0), .{ .i = 0, .j = 1 });
//    try testing.expectEql(try it.index(1), .{ .i = 1, .j = 3 });
//    try testing.expectEql(try it.index(2), .{ .i = 3, .j = 6 });
//    try testing.expectEql(try it.index(3), .{ .i = 6, .j = 10 });
//
//    try testing.expectEql(try utf8.index("$\xFF", 0), .{ .i = 0, .j = 1 });
//
//    try testing.expectErr(
//        utf8.index("$\xFF", 1),
//        utf8.Iterator.IndexError.InvalidFirstByte,
//    );
//
//    try testing.expectEql(try utf8.index("$\xF0", 0), .{ .i = 0, .j = 1 });
//
//    try testing.expectErr(
//        utf8.index("$\xF0", 1),
//        utf8.Iterator.IndexError.IncompleteInput,
//    );
//
//    try testing.expectErr(
//        utf8.index("", 0),
//        utf8.Iterator.IndexError.OutOfBounds,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.next" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try testing.expectEql(try it.next(), try unicode.Codepoint.init('$'));
//    try testing.expectEql(try it.next(), try unicode.Codepoint.init('¢'));
//    try testing.expectEql(try it.next(), try unicode.Codepoint.init('€'));
//    try testing.expectEql(try it.next(), try unicode.Codepoint.init('💰'));
//
//    try testing.expectErr(
//        it.next(),
//        utf8.Iterator.NextError.EndOfIteration,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xFF")).next(),
//        utf8.Iterator.NextBytesError.InvalidFirstByte,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xF0")).next(),
//        utf8.Iterator.NextBytesError.IncompleteInput,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.nextByte" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try testing.expectEql(try it.nextByte(), '$');
//
//    try testing.expectEqlStrs(&.{
//        try it.nextByte(),
//        try it.nextByte(),
//    }, "¢");
//
//    try testing.expectEqlStrs(&.{
//        try it.nextByte(),
//        try it.nextByte(),
//        try it.nextByte(),
//    }, "€");
//
//    try testing.expectEqlStrs(&.{
//        try it.nextByte(),
//        try it.nextByte(),
//        try it.nextByte(),
//        try it.nextByte(),
//    }, "💰");
//
//    try testing.expectErr(
//        it.nextByte(),
//        utf8.Iterator.NextBytesError.EndOfIteration,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.nextBytes" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try testing.expectEqlStrs(try it.nextBytes(), "$");
//    try testing.expectEqlStrs(try it.nextBytes(), "¢");
//    try testing.expectEqlStrs(try it.nextBytes(), "€");
//    try testing.expectEqlStrs(try it.nextBytes(), "💰");
//
//    try testing.expectErr(
//        it.nextBytes(),
//        utf8.Iterator.NextBytesError.EndOfIteration,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xFF")).nextBytes(),
//        utf8.Iterator.NextBytesError.InvalidFirstByte,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xF0")).nextBytes(),
//        utf8.Iterator.NextBytesError.IncompleteInput,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.nextIndex" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    var got = try it.nextIndex(null);
//    try testing.expectEql(got, 1);
//    it.i = got;
//
//    got = try it.nextIndex(null);
//    try testing.expectEql(got, 3);
//    it.i = got;
//
//    got = try it.nextIndex(null);
//    try testing.expectEql(got, 6);
//    it.i = got;
//
//    got = try it.nextIndex(null);
//    try testing.expectEql(got, 10);
//    it.i = got;
//
//    try testing.expectErr(
//        it.nextIndex(null),
//        utf8.Iterator.NextIndexError.EndOfIteration,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("")).nextIndex(null),
//        utf8.Iterator.NextIndexError.EndOfIteration,
//    );
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.nextIndex: invalid" {
//    // Incomplete input.
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xF0")).nextIndex(null),
//        utf8.Iterator.NextIndexError.IncompleteInput,
//    );
//
//    // Codepoint first byte.
//
//    var it = utf8.Iterator.init("$\xFF");
//    it.i = try it.nextIndex(null);
//    try testing.expectEql(it.i, 1);
//
//    var diag = utf8.Diagnostic{};
//
//    try testing.expectErr(
//        it.nextIndex(&diag),
//        utf8.Iterator.NextIndexError.InvalidFirstByte,
//    );
//
//    try testing.expectEql(diag.index, 1);
//    try testing.expectEql(diag.expected_len, 0);
//
//    // Codepoint intermediate byte.
//
//    it = utf8.Iterator.init("$\xF0\x9F\x92\xFF@\xE2\xFF\xAC");
//    it.i = try it.nextIndex(null);
//    try testing.expectEql(it.i, 1);
//
//    diag = utf8.Diagnostic{};
//
//    try testing.expectErr(
//        it.nextIndex(&diag),
//        utf8.Iterator.NextIndexError.InvalidIntermediateByte,
//    );
//
//    try testing.expectEql(diag.index, 4);
//    try testing.expectEql(diag.expected_len, 4);
//
//    it.i = 6;
//
//    diag = utf8.Diagnostic{};
//
//    try testing.expectErr(
//        it.nextIndex(&diag),
//        utf8.Iterator.NextIndexError.InvalidIntermediateByte,
//    );
//
//    try testing.expectEql(diag.index, 7);
//    try testing.expectEql(diag.expected_len, 3);
//}
//
//test "ntz.encoding.unicode.utf8.Iterator.skip" {
//    var it = utf8.Iterator.init("$¢€💰");
//
//    try it.skip();
//    try testing.expectEqlStrs(try it.nextBytes(), "¢");
//    try it.skip();
//    try testing.expectEqlStrs(try it.nextBytes(), "💰");
//
//    try testing.expectErr(
//        it.skip(),
//        utf8.Iterator.SkipError.EndOfIteration,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xFF")).skip(),
//        utf8.Iterator.SkipError.InvalidFirstByte,
//    );
//
//    try testing.expectErr(
//        @constCast(&utf8.Iterator.init("\xF0")).skip(),
//        utf8.Iterator.SkipError.IncompleteInput,
//    );
//}
