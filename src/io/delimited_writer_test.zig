// Copyright 2023 Miguel Angel Rivera Notararigo. All rights reserved.
// This source code was released under the MIT license.

const ntz = @import("ntz");
const testing = ntz.testing;
const types = ntz.types;
const bytes = types.bytes;

const io = ntz.io;

test "ntz.io.delimited_writer" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var dw = io.delimitedWriter(&cw, ally, "\n");
    defer dw.deinit();

    const in = "hello\nworld";
    var n = try dw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "hello\n");
    try testing.expectEql(n, 11);
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 6);

    n = try dw.write("\n");
    try testing.expectEqlStrs(buf.bytes(), in ++ "\n");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 2);
    try testing.expectEql(cw.byte_count, 12);
}

test "ntz.io.delimited_writer: exclude delimiter" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var dw = io.delimitedWriter(&cw, ally, "\n");
    dw.include = false;
    defer dw.deinit();

    const in = "hello\nworld\n!";
    var n = try dw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "helloworld");
    try testing.expectEql(n, 13);
    try testing.expectEql(cw.write_count, 2);
    try testing.expectEql(cw.byte_count, 10);

    n = try dw.write("\n");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);
}

test "ntz.io.delimited_writer: empty delimiter" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var dw = io.delimitedWriter(&cw, ally, "");
    defer dw.deinit();

    const in = "hello, world!";
    const n = try dw.write(in);
    try testing.expectEqlStrs(buf.bytes(), in);
    try testing.expectEql(in.len, n);
    try testing.expectEql(cw.write_count, 13);
    try testing.expectEql(cw.byte_count, 13);
}

test "ntz.io.delimited_writer: byte sequence delimiter" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var dw = io.delimitedWriter(&cw, ally, "--");
    defer dw.deinit();

    const in = "hello--world--!";
    var n = try dw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "hello--world--");
    try testing.expectEql(n, 15);
    try testing.expectEql(cw.write_count, 2);
    try testing.expectEql(cw.byte_count, 14);

    n = try dw.write("--");
    try testing.expectEqlStrs(buf.bytes(), in ++ "--");
    try testing.expectEql(n, 2);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 17);
}

test "ntz.io.delimited_writer: partially written sequence delimiter" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var dw = io.delimitedWriter(&cw, ally, "---");
    defer dw.deinit();

    const in = "hello---world--";
    var n = try dw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "hello---");
    try testing.expectEql(n, 15);
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 8);

    n = try dw.write("-!");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-");
    try testing.expectEql(n, 2);
    try testing.expectEql(cw.write_count, 2);
    try testing.expectEql(cw.byte_count, 16);

    try dw.flush();
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!");
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 17);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 17);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 17);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!---");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 4);
    try testing.expectEql(cw.byte_count, 20);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!---");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 4);
    try testing.expectEql(cw.byte_count, 20);

    n = try dw.write("_");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!---");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 4);
    try testing.expectEql(cw.byte_count, 20);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!---");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 4);
    try testing.expectEql(cw.byte_count, 20);

    try dw.flush();
    try testing.expectEqlStrs(buf.bytes(), in ++ "-!----_-");
    try testing.expectEql(cw.write_count, 5);
    try testing.expectEql(cw.byte_count, 23);
}

test "ntz.io.delimited_writer: remove partially written sequence delimiter" {
    const ally = testing.allocator;

    var buf = bytes.buffer(ally);
    defer buf.deinit();
    var cw = io.countingWriter(&buf);

    var dw = io.delimitedWriter(&cw, ally, "---");
    dw.include = false;
    defer dw.deinit();

    const in = "hello---world--";
    var n = try dw.write(in);
    try testing.expectEqlStrs(buf.bytes(), "hello");
    try testing.expectEql(n, 15);
    try testing.expectEql(cw.write_count, 1);
    try testing.expectEql(cw.byte_count, 5);

    n = try dw.write("-!");
    try testing.expectEqlStrs(buf.bytes(), "helloworld");
    try testing.expectEql(n, 2);
    try testing.expectEql(cw.write_count, 2);
    try testing.expectEql(cw.byte_count, 10);

    try dw.flush();
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    n = try dw.write("_");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    n = try dw.write("-");
    try testing.expectEqlStrs(buf.bytes(), "helloworld!");
    try testing.expectEql(n, 1);
    try testing.expectEql(cw.write_count, 3);
    try testing.expectEql(cw.byte_count, 11);

    try dw.flush();
    try testing.expectEqlStrs(buf.bytes(), "helloworld!-_-");
    try testing.expectEql(cw.write_count, 4);
    try testing.expectEql(cw.byte_count, 14);
}
