const std = @import("std");
const Allocator = std.mem.Allocator;
pub const Font = @import("font.zig").Font;
const debug = @import("debug");
const log = debug.log;
const Memory = @import("memory");
const rend = @import("renderer");
const Renderer = rend.Renderer;
const Texture = Renderer.Texture;

const FontAsset = struct {
    font: *Font,
    source_path: [:0]const u8, // absolute path, or "<embedded:name>" for in-memory fonts (sentinel-terminated to match allocator size)
    last_modified: i96, // nanoseconds mtime from stat; 0 = embedded, never reloaded
};

pub const FontManager = struct {
    fonts: Allocator,
    persistent: Allocator,
    io: std.Io,
    renderer: *Renderer, // for lazy atlas-texture upload (mirrors TextureManager)
    assets: std.StringHashMap(FontAsset),
    font_path: []const u8,

    pub fn init(mem: *Memory, io: std.Io, renderer: *Renderer) FontManager {
        return .{
            .fonts = mem.asset.fonts,
            .persistent = mem.persistent,
            .io = io,
            .renderer = renderer,
            .assets = std.StringHashMap(FontAsset).init(mem.asset.fonts),
            .font_path = "",
        };
    }

    pub fn deinit(self: *FontManager) void {
        var iter = self.assets.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.font.deinit();
            self.fonts.destroy(entry.value_ptr.font);
            self.fonts.free(entry.value_ptr.source_path);
            self.fonts.free(entry.key_ptr.*);
        }
        self.assets.deinit();
        if (self.font_path.len > 0) self.fonts.free(self.font_path);
    }

    pub fn setFontPath(self: *FontManager, path: []const u8) !void {
        if (self.font_path.len > 0) self.fonts.free(self.font_path);
        self.font_path = try self.fonts.dupe(u8, path);
    }

    // Load a font by filename, resolved relative to font_path
    pub fn load(self: *FontManager, name: []const u8, filename: []const u8) !void {
        const joined = try std.fs.path.join(self.fonts, &.{ self.font_path, filename });
        defer self.fonts.free(joined);
        try self.loadFromPath(name, joined);
    }

    // Load a font from an explicit path (relative or absolute)
    pub fn loadFromPath(self: *FontManager, name: []const u8, path: []const u8) !void {
        const abs_path = try std.Io.Dir.cwd().realPathFileAlloc(self.io, path, self.fonts);
        errdefer self.fonts.free(abs_path);

        const mtime = statMtime(self.io, abs_path);

        const font_ptr = try self.fonts.create(Font);
        errdefer self.fonts.destroy(font_ptr);
        font_ptr.* = try Font.init(self.fonts, self.io, abs_path);

        try self.store(name, font_ptr, abs_path, mtime);
    }

    // Load a font from an in-memory buffer (e.g. @embedFile)
    pub fn loadFromMemory(self: *FontManager, name: []const u8, data: []const u8) !void {
        const source_path_slice = try std.fmt.allocPrint(self.fonts, "<embedded:{s}>", .{name});
        defer self.fonts.free(source_path_slice);
        const source_path = try self.fonts.dupeZ(u8, source_path_slice);
        errdefer self.fonts.free(source_path);

        const font_ptr = try self.fonts.create(Font);
        errdefer self.fonts.destroy(font_ptr);
        font_ptr.* = try Font.initFromMemory(self.fonts, data);

        try self.store(name, font_ptr, source_path, 0);
    }

    // Read-only truth handle. Consumers measure/lay-out/draw against this; they
    // never mutate the font. The only post-load mutation (the lazy atlas texture)
    // goes through getOrCreateAtlasTexture, which holds the mutable font internally.
    pub fn get(self: *FontManager, name: []const u8) ?*const Font {
        const entry = self.assets.get(name) orelse return null;
        return entry.font;
    }

    // Lazy GPU atlas texture, cached on the atlas slot. Mirrors
    // TextureManager.getFrameTexture: the manager owns truth + its GPU projection
    // and writes the slot here — the ONE post-load mutation in the whole system.
    pub fn getOrCreateAtlasTexture(self: *FontManager, name: []const u8) !?*Texture {
        const entry = self.assets.get(name) orelse return null;
        return try atlasTexture(self.renderer, entry.font);
    }

    // Re-read from source_path, swap out the Font, preserve the name key
    pub fn reload(self: *FontManager, name: []const u8) !void {
        const entry = self.assets.getPtr(name) orelse return error.AssetNotFound;

        // Embedded fonts cannot be reloaded
        if (entry.last_modified == 0) return;

        const new_font = try self.fonts.create(Font);
        errdefer self.fonts.destroy(new_font);
        new_font.* = try Font.init(self.fonts, self.io, entry.source_path);

        entry.font.deinit();
        self.fonts.destroy(entry.font);
        entry.font = new_font;
        entry.last_modified = statMtime(self.io, entry.source_path);

        log.info(.assets, "Hot-reloaded font: {s}", .{name});
    }

    // Stat every tracked file; reload any whose mtime changed
    pub fn checkForChanges(self: *FontManager) !void {
        var iter = self.assets.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.last_modified == 0) continue; // embedded
            const current_mtime = statMtime(self.io, entry.value_ptr.source_path);
            if (current_mtime > entry.value_ptr.last_modified) {
                self.reload(entry.key_ptr.*) catch |err| {
                    log.warn(.assets, "Failed to reload font {s}: {}", .{ entry.key_ptr.*, err });
                };
            }
        }
    }

    // --- internals ---

    fn store(self: *FontManager, name: []const u8, font_ptr: *Font, source_path: [:0]const u8, mtime: i96) !void {
        const gop = try self.assets.getOrPut(name);
        if (gop.found_existing) {
            // Replace: deinit old font and free old source_path
            gop.value_ptr.font.deinit();
            self.fonts.destroy(gop.value_ptr.font);
            self.fonts.free(gop.value_ptr.source_path);
            // key is already owned, no need to re-dupe
        } else {
            gop.key_ptr.* = try self.fonts.dupe(u8, name);
        }
        gop.value_ptr.* = .{
            .font = font_ptr,
            .source_path = source_path,
            .last_modified = mtime,
        };
    }
};

// Lazily create+upload a font's R8 atlas texture, caching it on the atlas slot.
// The ONE post-load mutation. Free fn so both the manager (managed fonts) and
// app-owned bare fonts (UI) share one lazy-create path. Caller owns `font`.
pub fn atlasTexture(renderer: *Renderer, font: *Font) !*Texture {
    if (font.atlas.texture) |t| return @ptrCast(t);
    const tex = try renderer.createTexture(font.atlas.w, font.atlas.h, .r8);
    renderer.uploadTextureData(tex, font.atlas.w, font.atlas.h, font.atlas.pixels.ptr, font.atlas.w);
    font.atlas.texture = tex;
    return tex;
}

fn statMtime(io: std.Io, path: []const u8) i96 {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return stat.mtime.nanoseconds;
}
