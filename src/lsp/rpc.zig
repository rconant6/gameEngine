const std = @import("std");
const Allocator = std.mem.Allocator;
const Transport = @import("Transport.zig");

pub const Message = struct {
    id: ?Id,
    method: []const u8,
    params: std.json.Value,

    pub const Id = union(enum) {
        int: i64,
        str: []const u8,

        pub fn jsonStringify(self: Id, jw: anytype) !void {
            switch (self) {
                .int => |n| try jw.write(n),
                .str => |s| try jw.write(s),
            }
        }
    };
};

const Incoming = struct {
    parsed: std.json.Parsed(std.json.Value),
    msg: Message,

    pub fn deinit(self: *Incoming) void {
        self.parsed.deinit();
    }
};

pub fn parse(gpa: Allocator, body: []const u8) !Incoming {
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        gpa,
        body,
        .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        },
    );

    const root = parsed.value;
    if (root != .object) {
        parsed.deinit();
        return error.InvalidRequest;
    }
    const method_value = root.object.get("method") orelse {
        parsed.deinit();
        return error.InvalidRequest;
    };
    const method = switch (method_value) {
        .string => |txt| txt,
        else => {
            parsed.deinit();
            return error.InvalidRequest;
        },
    };
    // params is OPTIONAL per JSON-RPC — a notification like `exit` omits it.
    // Absent → a null value the handlers can parse an empty struct from.
    const params = root.object.get("params") orelse std.json.Value{ .null = {} };
    const id_val = root.object.get("id");
    const id = if (id_val == null) null else blk: {
        break :blk Message.Id{ .int = id_val.?.integer };
    };

    return .{
        .parsed = parsed,
        .msg = .{
            .method = method,
            .params = params,
            .id = id,
        },
    };
}

pub fn writeResponse(
    t: *Transport,
    gpa: Allocator,
    id: Message.Id,
    result: anytype,
) !void {
    const val = .{
        .jsonrpc = "2.0",
        .id = id,
        .result = result,
    };

    const bytes = try std.json.Stringify.valueAlloc(gpa, val, .{});
    defer gpa.free(bytes);

    try t.writeMessage(bytes);
}
pub fn writeNotification(
    t: *Transport,
    gpa: Allocator,
    method: []const u8,
    params: anytype,
) !void {
    const val = .{
        .jsonrpc = "2.0",
        .method = method,
        .params = params,
    };

    const bytes = try std.json.Stringify.valueAlloc(gpa, val, .{});
    defer gpa.free(bytes);

    try t.writeMessage(bytes);
}

pub fn writeError(
    t: *Transport,
    gpa: Allocator,
    id: ?Message.Id,
    code: i32,
    msg: []const u8,
) !void {
    const val = .{
        .jsonrpc = "2.0",
        .id = id,
        .code = code,
        .msg = msg,
    };

    const bytes = try std.json.Stringify.valueAlloc(gpa, val, .{});
    defer gpa.free(bytes);

    try t.writeMessage(bytes);
}

// ============================================================================
// Tests
// ============================================================================
const testing = std.testing;

// A Transport wired to an in-memory capturing writer; input side unused here.
fn captureTransport(aw: *std.Io.Writer.Allocating) Transport {
    return .{ .in = undefined, .out = &aw.writer, .gpa = testing.allocator };
}

// Pull just the JSON body out of framed "Content-Length: N\r\n\r\n<body>".
fn bodyOf(framed: []const u8) []const u8 {
    const sep = std.mem.indexOf(u8, framed, "\r\n\r\n").?;
    return framed[sep + 4 ..];
}

test "parse extracts method, params, and a request id" {
    const body =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"x\":2}}";
    var inc = try parse(testing.allocator, body);
    defer inc.deinit();

    try testing.expectEqualStrings("initialize", inc.msg.method);
    try testing.expect(inc.msg.id != null);
    try testing.expectEqual(@as(i64, 1), inc.msg.id.?.int);
    try testing.expect(inc.msg.params == .object);
    try testing.expectEqual(@as(i64, 2), inc.msg.params.object.get("x").?.integer);
}

test "parse leaves id null for a notification (no id field)" {
    const body =
        "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}";
    var inc = try parse(testing.allocator, body);
    defer inc.deinit();

    try testing.expectEqualStrings("initialized", inc.msg.method);
    try testing.expectEqual(@as(?Message.Id, null), inc.msg.id);
}

test "parse rejects a body that is not a JSON object" {
    try testing.expectError(error.InvalidRequest, parse(testing.allocator, "[1,2,3]"));
}

test "parse rejects an object with no method" {
    const body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"params\":{}}";
    try testing.expectError(error.InvalidRequest, parse(testing.allocator, body));
}

test "writeResponse emits {jsonrpc, id, result}" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var t = captureTransport(&aw);

    try writeResponse(&t, testing.allocator, .{ .int = 7 }, .{ .ok = true });

    try testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":7,\"result\":{\"ok\":true}}",
        bodyOf(aw.written()),
    );
}

test "writeNotification emits {jsonrpc, method, params} and no id" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var t = captureTransport(&aw);

    try writeNotification(
        &t,
        testing.allocator,
        "textDocument/publishDiagnostics",
        .{ .uri = "file:///a.scene" },
    );

    const body = bodyOf(aw.written());
    try testing.expect(std.mem.indexOf(u8, body, "\"method\":\"textDocument/publishDiagnostics\"") != null);
    try testing.expect(std.mem.indexOf(u8, body, "\"id\"") == null);
}

test "framed response is a valid Content-Length message" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var t = captureTransport(&aw);

    try writeResponse(&t, testing.allocator, .{ .int = 1 }, .{});

    const framed = aw.written();
    try testing.expect(std.mem.startsWith(u8, framed, "Content-Length: "));
    // the declared length must equal the actual body length
    const sep = std.mem.indexOf(u8, framed, "\r\n\r\n").?;
    const declared = try std.fmt.parseInt(usize, framed["Content-Length: ".len..sep], 10);
    try testing.expectEqual(declared, framed[sep + 4 ..].len);
}
