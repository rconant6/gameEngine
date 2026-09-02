const std = @import("std");
const Allocator = std.mem.Allocator;
const Docs = std.StringHashMapUnmanaged(Document);
const LineIndex = @import("LineIndex.zig");

pub const Document = struct {
    uri: []const u8,
    version: i64,
    src: [:0]const u8,
    lines: LineIndex,
};

pub const DocStore = struct {
    gpa: Allocator,
    docs: Docs = .empty,

    pub fn upsert(
        self: *DocStore,
        uri: []const u8,
        version: i64,
        text: []const u8,
    ) !*Document {
        const src = try self.gpa.dupeZ(u8, text);
        errdefer self.gpa.free(src);

        const lines = try LineIndex.build(self.gpa, src);
        errdefer lines.deinit(self.gpa);

        const gop = try self.docs.getOrPut(self.gpa, uri);
        if (gop.found_existing) {
            self.gpa.free(gop.value_ptr.src);
            gop.value_ptr.lines.deinit(self.gpa);

            gop.value_ptr.* = .{
                .uri = gop.key_ptr.*,
                .version = version,
                .src = src,
                .lines = lines,
            };
        } else {
            errdefer self.docs.removeByPtr(gop.key_ptr);

            const name = try self.gpa.dupe(u8, uri);
            gop.key_ptr.* = name;

            gop.value_ptr.* = .{
                .src = src,
                .lines = lines,
                .version = version,
                .uri = name,
            };
        }

        return gop.value_ptr;
    }

    pub fn get(self: *DocStore, uri: []const u8) ?*Document {
        return self.docs.getPtr(uri);
    }

    pub fn close(self: *DocStore, uri: []const u8) void {
        const kv = self.docs.fetchRemove(uri) orelse return;
        self.gpa.free(kv.value.src);
        self.gpa.free(kv.value.uri);
        kv.value.lines.deinit(self.gpa);
    }

    pub fn deinit(self: *DocStore) void {
        var it = self.docs.iterator();
        while (it.next()) |entry| {
            const doc = entry.value_ptr;
            self.gpa.free(doc.uri);
            self.gpa.free(doc.src);
            doc.lines.deinit(self.gpa);
        }
        self.docs.deinit(self.gpa);
    }
};

// ============================================================================
// Tests
// ============================================================================
const testing = std.testing;

test "upsert then get returns the stored document" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    const doc = try store.upsert("file:///a.scene", 1, "Ball : circle { radius 1 }");
    try testing.expectEqualStrings("file:///a.scene", doc.uri);
    try testing.expectEqual(@as(i64, 1), doc.version);
    try testing.expectEqualStrings("Ball : circle { radius 1 }", doc.src);

    // get returns a pointer to the SAME stored document
    const fetched = store.get("file:///a.scene").?;
    try testing.expectEqual(doc, fetched);
}

test "get returns null for an unknown uri" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    try testing.expectEqual(@as(?*Document, null), store.get("file:///missing.scene"));
}

test "stored src is NUL-terminated and independent of the input text" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    var input = [_]u8{ 'a', 'b', 'c' };
    const doc = try store.upsert("file:///x.scene", 1, &input);

    // the store owns its own copy — mutating the caller's buffer must not change it
    input[0] = 'Z';
    try testing.expectEqualStrings("abc", doc.src);
    // and it is a valid [:0] slice (sentinel present)
    try testing.expectEqual(@as(u8, 0), doc.src.ptr[doc.src.len]);
}

test "re-upsert same uri updates version and text (frees the old)" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    _ = try store.upsert("file:///a.scene", 1, "old text");
    const doc = try store.upsert("file:///a.scene", 2, "new longer text");

    try testing.expectEqual(@as(i64, 2), doc.version);
    try testing.expectEqualStrings("new longer text", doc.src);

    // still exactly one entry
    try testing.expectEqual(@as(usize, 1), store.docs.count());
    // testing allocator asserts the old "old text" src + its LineIndex were freed
}

test "re-upsert rebuilds the line index for the new text" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    // one line → line_starts = {0}
    _ = try store.upsert("file:///a.scene", 1, "one line");
    // two lines → line_starts = {0, 4}
    const doc = try store.upsert("file:///a.scene", 2, "ab\ncd");

    try testing.expectEqual(@as(usize, 2), doc.lines.line_starts.len);
}

test "close removes the entry so a later get is null" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    _ = try store.upsert("file:///a.scene", 1, "Ball : circle { radius 1 }");
    store.close("file:///a.scene");

    try testing.expectEqual(@as(?*Document, null), store.get("file:///a.scene"));
    try testing.expectEqual(@as(usize, 0), store.docs.count());
    // testing allocator asserts no leak and no double-free at deinit
}

test "close on an unknown uri is a no-op" {
    var store = DocStore{ .gpa = testing.allocator };
    defer store.deinit();

    store.close("file:///never-opened.scene"); // must not crash or free anything
    try testing.expectEqual(@as(usize, 0), store.docs.count());
}

test "deinit cleans a store holding several documents" {
    var store = DocStore{ .gpa = testing.allocator };
    // no defer — deinit is the thing under test; call it explicitly

    _ = try store.upsert("file:///a.scene", 1, "aaa");
    _ = try store.upsert("file:///b.scene", 1, "bbbb");
    _ = try store.upsert("file:///c.scene", 1, "ccccc");
    try testing.expectEqual(@as(usize, 3), store.docs.count());

    store.deinit(); // testing allocator fails the test if any doc leaks
}
