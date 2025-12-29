const std = @import("std");
pub const Font = @import("font.zig").Font;

pub const FontHandle = struct {
    id: usize,
};

const FontEntry = struct {
    normalized_path: []const u8,
    font: Font,
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

    fn load(self: *FontManager, normalized_path: []const u8) !FontHandle {
        if (self.path_to_handle.get(normalized_path)) |handle| {
            self.allocator.free(normalized_path);
            return handle;
        }

        const font = try Font.init(self.allocator, normalized_path);
        const entry = FontEntry{
            .font = font,
            .normalized_path = normalized_path,
        };
        try self.fonts.append(self.allocator, entry);

        const new_handle = FontHandle{ .id = self.fonts.items.len - 1 };
        try self.path_to_handle.put(normalized_path, new_handle);

        return new_handle;
    }

    pub fn getFont(self: *FontManager, handle: FontHandle) ?*const Font {
        if (handle.id >= self.fonts.items.len) return null;
        return &self.fonts.items[handle.id].font;
    }

    fn normalizePath(
        alloc: std.mem.Allocator,
        base_path: []const u8,
        name: []const u8,
    ) ![]const u8 {
        const joined = try std.fs.path.join(alloc, &[_][]const u8{ base_path, name });
        defer alloc.free(joined);
        // std.log.debug("Joined path: {s}", .{joined});

        // Caller owns this memory
        const absolute = try std.fs.cwd().realpathAlloc(alloc, joined);
        // std.log.debug("Absolute path: {s}", .{absolute});

        return absolute;
    }
};
