const std = @import("std");

const font_mgr = @import("font/font_manager.zig");
const FontHandle = font_mgr.FontHandle;
const FontManager = font_mgr.FontManager;
const Font = font_mgr.Font;

const Self = @This();

allocator: std.mem.Allocator,
fonts: FontManager,
name_to_font: std.StringHashMap(FontHandle),

pub fn init(alloc: std.mem.Allocator) !Self {
    var font_manager: FontManager = .init(alloc);
    try font_manager.setFontPath("assets/fonts/");

    return Self{
        .allocator = alloc,
        .fonts = font_manager,
        .name_to_font = std.StringHashMap(FontHandle).init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.fonts.deinit();
    self.name_to_font.deinit();
}

pub fn setFontPath(self: *Self, path: []const u8) !void {
    try self.fonts.setFontPath(path);
}

pub fn loadFont(self: *Self, name: []const u8) !FontHandle {
    return try self.fonts.loadFont(name);
}

pub fn loadFontFromPath(self: *Self, path: []const u8) !FontHandle {
    return try self.fonts.loadFontFromPath(path);
}

pub fn getFontHandle(self: *Self, name: []const u8) !FontHandle {
    if (self.name_to_font.get(name)) |handle| return handle;

    const handle = try self.loadFont(name);
    try self.name_to_font.put(name, handle);
    return handle;
}

pub fn getFont(self: *Self, handle: FontHandle) ?*const Font {
    return self.fonts.getFont(handle);
}

pub fn getFontByName(self: *Self, name: []const u8) !*const Font {
    const handle = try self.getFontHandle(name);
    return self.getFont(handle) orelse error.FontNotFound;
}

pub fn getFontAssetHandle(self: *Self, asset_name: []const u8) !FontHandle {
    return self.name_to_font.get(asset_name) orelse error.AssetNotFound;
}
pub fn registerFontAsset(self: *Self, asset_name: []const u8, handle: FontHandle) !void {
    try self.name_to_font.put(asset_name, handle);
}
