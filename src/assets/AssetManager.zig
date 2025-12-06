const std = @import("std");

const font_mgr = @import("font/font_manager.zig");
const FontHandle = font_mgr.FontHandle;
const FontManager = font_mgr.FontManager;
const Font = font_mgr.Font;

const Self = @This();

allocator: std.mem.Allocator,
fonts: FontManager,

pub fn setFontPath(self: *Self, path: []const u8) void {
    self.fonts.setFontPath(path);
}

pub fn loadFont(self: *Self, name: []const u8) !FontHandle {
    return try self.fonts.loadFont(name);
}

pub fn init(alloc: std.mem.Allocator) !Self {
    return Self{
        .allocator = alloc,
        .fonts = FontManager.init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.fonts.deinit();
}
