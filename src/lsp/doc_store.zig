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

            gop.value_ptr = .{
                .src = src,
                .version = version,
                .lines = lines,
                .uri = gop.key_ptr.*,
            };
        } else {
            errdefer self.docs.removeByPtr(gop.key_ptr);

            const name = try self.gpa.dupe(u8, uri);
            gop.key_ptr.* = name;

            gop.value_ptr = .{
                .src = src,
                .lines = lines,
                .version = version,
                .uri = name,
            };
        }

        return gop.value_ptr;
    }

    pub fn get(self: *DocStore, uri: []const u8) ?*Document {
        return &self.docs.get(uri);
    }

    pub fn close(self: *DocStore, uri: []const u8) void {
        const doc = self.get(uri) orelse return;
        self.gpa.free(doc.src);
        self.gpa.free(doc.uri);
        doc.lines.deinit(self.gpa);
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
