const std = @import("std");
const log = @import("debug").log;
const Self = @This();

// Tags are stored inline: they're short, hot, and created both from scene
// strings (borrowed AST slices) and from code literals. Owning a fixed buffer
// removes the lifetime question entirely — a Tag is always self-contained and
// safe to copy/store without tracking who frees the string.
buf: [96]u8 = undefined,
len: u8 = 0,

// Copy `s` into the inline buffer, truncating (with a warning) if it doesn't fit.
pub fn init(s: []const u8) Self {
    var self: Self = .{};
    const n = @min(s.len, self.buf.len);
    if (s.len > self.buf.len) {
        log.warn(.ecs, "Tag '{s}' exceeds {d} bytes, truncating", .{ s, self.buf.len });
    }
    @memcpy(self.buf[0..n], s[0..n]);
    self.len = @intCast(n);
    return self;
}

pub fn tags(self: *const Self) []const u8 {
    return self.buf[0..self.len];
}

pub fn hasTag(self: *const Self, tag_in: []const u8) bool {
    var iter = std.mem.tokenizeAny(u8, self.tags(), ", ");
    while (iter.next()) |tag| {
        if (std.mem.eql(u8, tag, tag_in)) return true;
    }
    return false;
}
pub fn matchesPattern(self: *const Self, pattern: []const u8) bool {
    if (pattern.len == 0) return false;

    // Exact match
    if (self.hasTag(pattern)) return true;

    // Prefix wildcard: "enemy*"
    if (pattern[pattern.len - 1] == '*') {
        const prefix = pattern[0 .. pattern.len - 1];
        var iter = std.mem.tokenizeAny(u8, self.tags(), ", ");
        while (iter.next()) |tag| {
            if (std.mem.startsWith(u8, tag, prefix)) return true;
        }
    }

    // Suffix wildcard: "*_boss"
    if (pattern[0] == '*') {
        const suffix = pattern[1..];
        var iter = std.mem.tokenizeAny(u8, self.tags(), ", ");
        while (iter.next()) |tag| {
            if (std.mem.endsWith(u8, tag, suffix)) return true;
        }
    }

    return false;
}
