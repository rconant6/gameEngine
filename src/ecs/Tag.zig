const std = @import("std");
const Self = @This();

tags: []const u8,

pub fn hasTag(self: Self, tag_in: []const u8) bool {
    var iter = std.mem.tokenizeAny(u8, self.tags, ", ");
    while (iter.next()) |tag| {
        if (std.mem.eql(u8, tag, tag_in)) return true;
    }
    return false;
}
pub fn matchesPattern(self: Self, pattern: []const u8) bool {
    if (pattern.len == 0) return false;

    // Exact match
    if (self.hasTag(pattern)) return true;

    // Prefix wildcard: "enemy*"
    if (pattern[pattern.len - 1] == '*') {
        const prefix = pattern[0 .. pattern.len - 1];
        var iter = std.mem.tokenizeAny(u8, self.tags, ", ");
        while (iter.next()) |tag| {
            if (std.mem.startsWith(u8, tag, prefix)) return true;
        }
    }

    // Suffix wildcard: "*_boss"
    if (pattern[0] == '*') {
        const suffix = pattern[1..];
        var iter = std.mem.tokenizeAny(u8, self.tags, ", ");
        while (iter.next()) |tag| {
            if (std.mem.endsWith(u8, tag, suffix)) return true;
        }
    }

    return false;
}
