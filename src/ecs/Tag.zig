const std = @import("std");

const Self = @This();

names: []const []const u8,

pub fn hasTag(self: Self, tag: []const u8) bool {
    for (self.names) |name| {
        if (std.mem.eql(u8, name, tag)) return true;
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
        for (self.names) |name| {
            if (std.mem.startsWith(u8, name, prefix)) return true;
        }
    }

    // Suffix wildcard: "*_boss"
    if (pattern[0] == '*') {
        const suffix = pattern[1..];
        for (self.names) |name| {
            if (std.mem.endsWith(u8, name, suffix)) return true;
        }
    }

    return false;
}
