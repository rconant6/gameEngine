const std = @import("std");
const Allocator = std.mem.Allocator;
pub const Font = @import("font.zig").Font;
const debug = @import("debug");
const log = debug.log;

const FontAsset = struct {
    font: *Font,
    source_path: []const u8, // absolute path, or "<embedded:name>" for in-memory fonts
    last_modified: i96, // nanoseconds mtime from stat; 0 = embedded, never reloaded
};

pub const FontManager = struct {
    gpa: Allocator,
    io: std.Io,
    assets: std.StringHashMap(FontAsset),
    font_path: []const u8,

    pub fn init(gpa: Allocator, io: std.Io) FontManager {
        return .{
            .gpa = gpa,
            .io = io,
            .assets = std.StringHashMap(FontAsset).init(gpa),
            .font_path = "",
        };
    }

    pub fn deinit(self: *FontManager) void {
        var iter = self.assets.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.font.deinit();
            self.gpa.destroy(entry.value_ptr.font);
            self.gpa.free(entry.value_ptr.source_path);
            self.gpa.free(entry.key_ptr.*);
        }
        self.assets.deinit();
        if (self.font_path.len > 0) self.gpa.free(self.font_path);
    }

    pub fn setFontPath(self: *FontManager, path: []const u8) !void {
        if (self.font_path.len > 0) self.gpa.free(self.font_path);
        self.font_path = try self.gpa.dupe(u8, path);
    }

    // Load a font by filename, resolved relative to font_path
    pub fn load(self: *FontManager, name: []const u8, filename: []const u8) !void {
        const joined = try std.fs.path.join(self.gpa, &.{ self.font_path, filename });
        defer self.gpa.free(joined);
        try self.loadFromPath(name, joined);
    }

    // Load a font from an explicit path (relative or absolute)
    pub fn loadFromPath(self: *FontManager, name: []const u8, path: []const u8) !void {
        const abs_path = try std.Io.Dir.cwd().realPathFileAlloc(self.io, path, self.gpa);
        errdefer self.gpa.free(abs_path);

        const mtime = statMtime(self.io, abs_path);

        const font_ptr = try self.gpa.create(Font);
        errdefer self.gpa.destroy(font_ptr);
        font_ptr.* = try Font.init(self.gpa, self.io, abs_path);

        try self.store(name, font_ptr, abs_path, mtime);
    }

    // Load a font from an in-memory buffer (e.g. @embedFile)
    pub fn loadFromMemory(self: *FontManager, name: []const u8, data: []const u8) !void {
        const source_path = try std.fmt.allocPrint(self.gpa, "<embedded:{s}>", .{name});
        errdefer self.gpa.free(source_path);

        const font_ptr = try self.gpa.create(Font);
        errdefer self.gpa.destroy(font_ptr);
        font_ptr.* = try Font.initFromMemory(self.gpa, data);

        try self.store(name, font_ptr, source_path, 0);
    }

    pub fn get(self: *FontManager, name: []const u8) ?*Font {
        const entry = self.assets.get(name) orelse return null;
        return entry.font;
    }

    // Re-read from source_path, swap out the Font, preserve the name key
    pub fn reload(self: *FontManager, name: []const u8) !void {
        const entry = self.assets.getPtr(name) orelse return error.AssetNotFound;

        // Embedded fonts cannot be reloaded
        if (entry.last_modified == 0) return;

        const new_font = try self.gpa.create(Font);
        errdefer self.gpa.destroy(new_font);
        new_font.* = try Font.init(self.gpa, self.io, entry.source_path);

        entry.font.deinit();
        self.gpa.destroy(entry.font);
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

    fn store(self: *FontManager, name: []const u8, font_ptr: *Font, source_path: []const u8, mtime: i96) !void {
        const gop = try self.assets.getOrPut(name);
        if (gop.found_existing) {
            // Replace: deinit old font and free old source_path
            gop.value_ptr.font.deinit();
            self.gpa.destroy(gop.value_ptr.font);
            self.gpa.free(gop.value_ptr.source_path);
            // key is already owned, no need to re-dupe
        } else {
            gop.key_ptr.* = try self.gpa.dupe(u8, name);
        }
        gop.value_ptr.* = .{
            .font = font_ptr,
            .source_path = source_path,
            .last_modified = mtime,
        };
    }
};

fn statMtime(io: std.Io, path: []const u8) i96 {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return stat.mtime.nanoseconds;
}
