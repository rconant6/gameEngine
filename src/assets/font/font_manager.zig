const std = @import("std");
pub const Font = @import("font.zig").Font;

pub const FontHandle = struct {
    id: usize,
};

const FontEntry = struct {
    normalized_path: [:0]const u8,
    font: *Font,
};

pub const FontManager = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    fonts: std.ArrayList(FontEntry),
    path_to_handle: std.StringHashMap(FontHandle),
    font_path: []const u8,

    pub fn init(gpa: std.mem.Allocator, io: std.Io) FontManager {
        return .{
            .gpa = gpa,
            .io = io,
            .fonts = std.ArrayList(FontEntry).empty,
            .path_to_handle = std.StringHashMap(FontHandle).init(gpa),
            .font_path = "",
        };
    }
    pub fn deinit(self: *FontManager) void {
        for (self.fonts.items) |*entry| {
            entry.font.deinit();
            self.gpa.destroy(entry.font);
            self.gpa.free(entry.normalized_path);
        }
        self.fonts.deinit(self.gpa);
        self.path_to_handle.deinit();

        if (self.font_path.len > 0) self.gpa.free(self.font_path);
    }

    pub fn setFontPath(self: *FontManager, path: []const u8) !void {
        if (self.font_path.len > 0) self.gpa.free(self.font_path);
        self.font_path = try self.gpa.dupe(u8, path);
    }
    pub fn loadFont(self: *FontManager, name: []const u8) !FontHandle {
        const normalized_path = try self.normalizePath(self.font_path, name);
        errdefer self.gpa.free(normalized_path);

        return self.load(normalized_path);
    }
    pub fn loadFontFromPath(self: *FontManager, path: []const u8) !FontHandle {
        const normalized_path = try std.Io.Dir.cwd().realPathFileAlloc(self.io, path, self.gpa);
        errdefer self.gpa.free(normalized_path);

        return self.load(normalized_path);
    }

    pub fn loadFontFromMemory(self: *FontManager, name: []const u8, data: []const u8) !FontHandle {
        // Use a synthetic path name for embedded fonts
        const synthetic_path = try std.fmt.allocPrintSentinel(self.gpa, "<embedded:{s}>", .{name}, 0);
        errdefer self.gpa.free(synthetic_path);

        // Check if already loaded
        if (self.path_to_handle.get(synthetic_path)) |handle| {
            self.gpa.free(synthetic_path);
            return handle;
        }

        const font_ptr = try self.gpa.create(Font);
        errdefer self.gpa.destroy(font_ptr);
        font_ptr.* = try Font.initFromMemory(self.gpa, data);

        const entry = FontEntry{
            .font = font_ptr,
            .normalized_path = synthetic_path,
        };
        try self.fonts.append(self.gpa, entry);

        const new_handle = FontHandle{ .id = self.fonts.items.len - 1 };
        try self.path_to_handle.put(synthetic_path, new_handle);

        return new_handle;
    }

    fn load(self: *FontManager, normalized_path: [:0]const u8) !FontHandle {
        if (self.path_to_handle.get(normalized_path)) |handle| {
            self.gpa.free(normalized_path);
            return handle;
        }

        const font_ptr = try self.gpa.create(Font);
        errdefer self.gpa.destroy(font_ptr);
        font_ptr.* = try Font.init(self.gpa, self.io, normalized_path);

        const entry = FontEntry{
            .font = font_ptr,
            .normalized_path = normalized_path,
        };
        try self.fonts.append(self.gpa, entry);

        const new_handle = FontHandle{ .id = self.fonts.items.len - 1 };
        try self.path_to_handle.put(normalized_path, new_handle);

        return new_handle;
    }

    pub fn getFont(self: *FontManager, handle: FontHandle) ?*Font {
        if (handle.id >= self.fonts.items.len) return null;
        return self.fonts.items[handle.id].font;
    }

    fn normalizePath(
        self: *FontManager,
        base_path: []const u8,
        name: []const u8,
    ) ![:0]const u8 {
        const joined = try std.fs.path.join(self.gpa, &[_][]const u8{ base_path, name });
        defer self.gpa.free(joined);

        const absolute = try std.Io.Dir.cwd().realPathFileAlloc(self.io, joined, self.gpa);

        return absolute;
    }
};
