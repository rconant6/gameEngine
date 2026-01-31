const std = @import("std");
pub const Font = @import("font.zig").Font;

pub const FontHandle = struct {
    id: usize,
};

const FontEntry = struct {
    normalized_path: []const u8,
    font: *Font,
};

pub const FontManager = struct {
    allocator: std.mem.Allocator,
    fonts: std.ArrayList(FontEntry),
    path_to_handle: std.StringHashMap(FontHandle),
    font_path: []const u8,

    pub fn init(alloc: std.mem.Allocator) FontManager {
        return .{
            .allocator = alloc,
            .fonts = std.ArrayList(FontEntry).empty,
            .path_to_handle = std.StringHashMap(FontHandle).init(alloc),
            .font_path = "",
        };
    }
    pub fn deinit(self: *FontManager) void {
        for (self.fonts.items) |*entry| {
            entry.font.deinit();
            self.allocator.destroy(entry.font);
            self.allocator.free(entry.normalized_path);
        }
        self.fonts.deinit(self.allocator);
        self.path_to_handle.deinit();

        if (self.font_path.len > 0) self.allocator.free(self.font_path);
    }

    pub fn setFontPath(self: *FontManager, path: []const u8) !void {
        if (self.font_path.len > 0) self.allocator.free(self.font_path);
        self.font_path = try self.allocator.dupe(u8, path);
    }
    pub fn loadFont(self: *FontManager, name: []const u8) !FontHandle {
        const normalized_path = try normalizePath(self.allocator, self.font_path, name);
        errdefer self.allocator.free(normalized_path);

        return self.load(normalized_path);
    }
    pub fn loadFontFromPath(self: *FontManager, path: []const u8) !FontHandle {
        const normalized_path = try std.fs.cwd().realpathAlloc(self.allocator, path);
        errdefer self.allocator.free(normalized_path);

        return self.load(normalized_path);
    }

    pub fn loadFontFromMemory(self: *FontManager, name: []const u8, data: []const u8) !FontHandle {
        // Use a synthetic path name for embedded fonts
        const synthetic_path = try std.fmt.allocPrint(self.allocator, "<embedded:{s}>", .{name});
        errdefer self.allocator.free(synthetic_path);

        // Check if already loaded
        if (self.path_to_handle.get(synthetic_path)) |handle| {
            self.allocator.free(synthetic_path);
            return handle;
        }

        const font_ptr = try self.allocator.create(Font);
        errdefer self.allocator.destroy(font_ptr);
        font_ptr.* = try Font.initFromMemory(self.allocator, data);

        const entry = FontEntry{
            .font = font_ptr,
            .normalized_path = synthetic_path,
        };
        try self.fonts.append(self.allocator, entry);

        const new_handle = FontHandle{ .id = self.fonts.items.len - 1 };
        try self.path_to_handle.put(synthetic_path, new_handle);

        return new_handle;
    }

    fn load(self: *FontManager, normalized_path: []const u8) !FontHandle {
        if (self.path_to_handle.get(normalized_path)) |handle| {
            self.allocator.free(normalized_path);
            return handle;
        }

        const font_ptr = try self.allocator.create(Font);
        errdefer self.allocator.destroy(font_ptr);
        font_ptr.* = try Font.init(self.allocator, normalized_path);

        const entry = FontEntry{
            .font = font_ptr,
            .normalized_path = normalized_path,
        };
        try self.fonts.append(self.allocator, entry);

        const new_handle = FontHandle{ .id = self.fonts.items.len - 1 };
        try self.path_to_handle.put(normalized_path, new_handle);

        return new_handle;
    }

    pub fn getFont(self: *FontManager, handle: FontHandle) ?*Font {
        if (handle.id >= self.fonts.items.len) return null;
        return self.fonts.items[handle.id].font;
    }

    fn normalizePath(
        alloc: std.mem.Allocator,
        base_path: []const u8,
        name: []const u8,
    ) ![]const u8 {
        const joined = try std.fs.path.join(alloc, &[_][]const u8{ base_path, name });
        defer alloc.free(joined);

        const absolute = try std.fs.cwd().realpathAlloc(alloc, joined);

        return absolute;
    }
};
