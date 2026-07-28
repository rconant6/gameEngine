const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const math = @import("math");
const V2 = math.V2;

pub const GlyphEntry = struct {
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    bearing: V2,
    size_px: V2,
    advance: f32,
};

pub const GlyphAtlas = struct {
    pub const CELL_PX: u16 = 32;
    pub const PAD: u16 = 6;
    pub const ATLAS_W: usize = 1024;
    pub const ATLAS_H: usize = 1024;

    texture: ?*anyopaque = null,
    pixels: []u8,
    w: u16,
    h: u16,
    entries: std.AutoHashMap(u16, GlyphEntry),

    pub fn init(persistant: Allocator) !GlyphAtlas {
        const pixels = try persistant.alloc(u8, ATLAS_W * ATLAS_H);
        @memset(pixels, 0); // unpacked regions must read as "outside", not garbage
        return .{
            .texture = null,
            .pixels = pixels,
            .w = @intCast(ATLAS_W),
            .h = @intCast(ATLAS_H),
            .entries = .init(persistant),
        };
    }

    pub fn uvFor(self: GlyphAtlas, glyph_id: u16) ?GlyphEntry {
        return self.entries.get(glyph_id);
    }

    pub fn deinit(self: *GlyphAtlas, persistant: Allocator) void {
        persistant.free(self.pixels);
        self.entries.deinit();
    }
};
