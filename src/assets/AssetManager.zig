const std = @import("std");
const StringHashMap = std.StringHashMap;
const debug = @import("debug");
const log = debug.log;
const font_mgr = @import("font/font_manager.zig");
const FontHandle = font_mgr.FontHandle;
const FontManager = font_mgr.FontManager;
const Font = font_mgr.Font;
const zxl = @import("zxl");
const ZxlImage = zxl.ZxlImage;
const ZxlReader = zxl.ZxlReader;
const ZxlAsset = @import("textures/zxlAsset.zig");
const rend = @import("renderer");
const Renderer = rend.Renderer;
const Device = Renderer.Device;
const Texture = Renderer.Texture;

const Self = @This();

// Embed the default font at compile time (relative to this file)
const embedded_orbitron_font = @embedFile("default_orbitron.ttf");

allocator: std.mem.Allocator,
fonts: FontManager,
name_to_font: StringHashMap(FontHandle),
name_to_zxl: StringHashMap(ZxlAsset),
renderer: *const Renderer,

pub fn init(alloc: std.mem.Allocator, io: std.Io) !Self {
    var font_manager: FontManager = .init(alloc, io);
    try font_manager.setFontPath("assets/fonts/");

    var name_to_font = StringHashMap(FontHandle).init(alloc);

    // Load the embedded default font
    const default_handle = try font_manager.loadFontFromMemory("default_orbitron", embedded_orbitron_font);
    try name_to_font.put(try alloc.dupe(u8, "__default__"), default_handle);

    return Self{
        .allocator = alloc,
        .fonts = font_manager,
        .name_to_font = name_to_font,
        .name_to_zxl = .init(alloc),
        .renderer = undefined,
    };
}
pub fn deinit(self: *Self) void {
    log.info(.assets, "Asset Manager shutting down...", .{});
    var font_iter = self.name_to_font.keyIterator();
    while (font_iter.next()) |key| {
        self.allocator.free(key.*);
    }
    self.fonts.deinit();
    self.name_to_font.deinit();

    var tex_iter = self.name_to_zxl.keyIterator();
    while (tex_iter.next()) |key| {
        self.allocator.free(key.*);
    }
    self.name_to_zxl.deinit();
}
// NOTE: do we want to handle this better?
pub fn setRenderer(self: *Self, renderer: *const Renderer) void {
    self.renderer = renderer;
}

// MARK: Textures
pub fn loadZxl(self: *Self, name: []const u8) !FontHandle {
    _ = self;
    _ = name;
}
pub fn loadZxlFromPath(self: *Self, path: []const u8) !FontHandle {
    _ = self;
    _ = path;
}

// MARK: Fonts
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
pub fn getFont(self: *Self, handle: FontHandle) ?*Font {
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
