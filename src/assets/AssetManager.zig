const std = @import("std");
const debug = @import("debug");
const log = debug.log;
const font_mgr = @import("font/font_manager.zig");
pub const FontManager = font_mgr.FontManager;
const Font = font_mgr.Font;
const tex_mgr = @import("textures/TextureManager.zig");
pub const TextureManager = tex_mgr.TextureManager;
pub const TextureAsset = tex_mgr.TextureAsset;
const rend = @import("renderer");
const Renderer = rend.Renderer;
const Texture = Renderer.Texture;

const Self = @This();

// Embed the default font at compile time (relative to this file)
const embedded_orbitron_font = @embedFile("default_orbitron.ttf");

gpa: std.mem.Allocator,
fonts: FontManager,
textures: TextureManager,

pub fn init(gpa: std.mem.Allocator, io: std.Io, renderer: *Renderer) !Self {
    var fonts = FontManager.init(gpa, io);
    try fonts.setFontPath("assets/fonts/");
    try fonts.loadFromMemory("__default__", embedded_orbitron_font);

    return Self{
        .gpa = gpa,
        .fonts = fonts,
        .textures = TextureManager.init(gpa, io, renderer),
    };
}

pub fn deinit(self: *Self) void {
    log.info(.assets, "Asset Manager shutting down...", .{});
    self.fonts.deinit();
    self.textures.deinit();
}

// MARK: Fonts

pub fn loadFont(self: *Self, name: []const u8, filename: []const u8) !void {
    try self.fonts.load(name, filename);
}

pub fn loadFontFromPath(self: *Self, name: []const u8, path: []const u8) !void {
    try self.fonts.loadFromPath(name, path);
}

pub fn getFont(self: *Self, name: []const u8) ?*Font {
    return self.fonts.get(name);
}

// MARK: Textures

pub fn loadZxl(self: *Self, name: []const u8, path: []const u8) !void {
    try self.textures.load(name, path);
}

pub fn getZxlAsset(self: *Self, name: []const u8) ?*TextureAsset {
    return self.textures.get(name);
}

pub fn getOrCreateFrameTexture(self: *Self, asset: *TextureAsset, frame_index: usize) !*Texture {
    return self.textures.getFrameTexture(asset, frame_index);
}

// MARK: Hot Reload

pub fn checkForChanges(self: *Self) !void {
    try self.fonts.checkForChanges();
    try self.textures.checkForChanges();
}
