const Engine = @import("../Engine.zig").Engine;
const assets = @import("assets");
const Font = assets.Font;
const rend = @import("renderer");
const Texture = rend.Renderer.Texture;
const debug = @import("debug");
const log = debug.log;

pub fn getFont(self: *Engine, name: []const u8) !*const Font {
    return self.assets.getFont(name) orelse {
        log.err(.assets, "Font not found: {s}", .{name});
        return error.FontNotFound;
    };
}

pub fn getFontAtlasTexture(self: *Engine, name: []const u8) !*Texture {
    return (self.assets.getOrCreateAtlasTexture(name) catch |err| {
        log.err(.assets, "Font atlas texture failed: {s} {any}", .{ name, err });
        return error.FontNotFound;
    }) orelse error.FontNotFound;
}
