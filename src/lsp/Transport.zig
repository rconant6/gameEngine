const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

in: *std.Io.Reader,
out: *std.Io.Writer,
gpa: Allocator,

pub fn readMessage(self: *Self) ReadError![]u8 {
    var content_len: ?usize = null;
    while (true) {
        const line = try self.in.takeDelimiterInclusive('\n');
        const trimmed = std.mem.trimEnd(u8, line, "\r\n");

        if (trimmed.len == 0) break;
        if (std.mem.startsWith(u8, trimmed, "Content-Length: ")) {
            const len_str = std.mem.trimStart(u8, trimmed, "Content-Length: ");
            content_len = try std.fmt.parseInt(
                usize,
                len_str,
                0,
            );
        }
    }

    if (content_len) |len| {
        const body = try self.gpa.alloc(u8, len);
        try self.in.readSliceAll(body);

        return body;
    }

    return ReadError.MalformedHeader;
}

pub fn writeMessage(self: *Self, body: []const u8) WriteError!void {
    try self.out.print("Content-Length: {d}\r\n\r\n", .{body.len});
    try self.out.writeAll(body);
    try self.out.flush();
}

pub const ReadError = error{
    EndOfStream,
    MalformedHeader,
    OutOfMemory,
    DelimitterError,
    StreamTooLong,
    Overflow,
    InvalidCharacter,
} || std.Io.Reader.Error;
pub const WriteError = std.Io.Writer.Error;

// ============================================================================
// Tests
// ============================================================================
const testing = std.testing;

test "writeMessage frames body with Content-Length + blank line" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    var t = Self{ .in = undefined, .out = &aw.writer, .gpa = testing.allocator };
    try t.writeMessage("{\"jsonrpc\":\"2.0\"}");

    try testing.expectEqualStrings(
        "Content-Length: 17\r\n\r\n{\"jsonrpc\":\"2.0\"}",
        aw.written(),
    );
}

test "writeMessage counts bytes, not characters (length is the byte length)" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    var t = Self{ .in = undefined, .out = &aw.writer, .gpa = testing.allocator };
    try t.writeMessage("hi"); // 2 bytes

    try testing.expectEqualStrings("Content-Length: 2\r\n\r\nhi", aw.written());
}

test "readMessage returns exactly the body after the header block" {
    const wire = "Content-Length: 17\r\n\r\n{\"jsonrpc\":\"2.0\"}";
    var r = std.Io.Reader.fixed(wire);

    var t = Self{ .in = &r, .out = undefined, .gpa = testing.allocator };
    const body = try t.readMessage();
    defer testing.allocator.free(body);

    try testing.expectEqualStrings("{\"jsonrpc\":\"2.0\"}", body);
}

test "readMessage skips unknown headers and reads the declared length" {
    // Content-Type appears first and must be ignored; only Content-Length counts.
    const wire =
        "Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n" ++
        "Content-Length: 2\r\n" ++
        "\r\n" ++
        "hi";
    var r = std.Io.Reader.fixed(wire);

    var t = Self{ .in = &r, .out = undefined, .gpa = testing.allocator };
    const body = try t.readMessage();
    defer testing.allocator.free(body);

    try testing.expectEqualStrings("hi", body);
}

test "readMessage reads only Content-Length bytes, leaving the next message" {
    // Two back-to-back messages on one stream: the first read must consume
    // exactly its own body and stop, so the second is still readable.
    const wire =
        "Content-Length: 2\r\n\r\naa" ++
        "Content-Length: 3\r\n\r\nbbb";
    var r = std.Io.Reader.fixed(wire);

    var t = Self{ .in = &r, .out = undefined, .gpa = testing.allocator };

    const first = try t.readMessage();
    defer testing.allocator.free(first);
    try testing.expectEqualStrings("aa", first);

    const second = try t.readMessage();
    defer testing.allocator.free(second);
    try testing.expectEqualStrings("bbb", second);
}

test "readMessage errors on a header block with no Content-Length" {
    const wire = "Content-Type: text/plain\r\n\r\nbody";
    var r = std.Io.Reader.fixed(wire);

    var t = Self{ .in = &r, .out = undefined, .gpa = testing.allocator };
    try testing.expectError(ReadError.MalformedHeader, t.readMessage());
}
