const std = @import("std");
const Allocator = std.mem.Allocator;
const zxl = @import("zxl");
const ZxlImage = zxl.ZxlImage;
const ZxlReader = zxl.ZxlReader;
const rend = @import("renderer");
const Renderer = rend.Renderer;
const Texture = Renderer.Texture;
const debug = @import("debug");
const log = debug.log;

pub const TextureAsset = struct {
    image: ZxlImage,
    frame_textures: std.ArrayList(?*Texture), // null = not yet uploaded, populated lazily
    source_path: []const u8, // absolute path on disk
    last_modified: i96, // nanoseconds mtime from stat
};

pub const TextureManager = struct {
    gpa: Allocator,
    io: std.Io,
    renderer: *Renderer,
    assets: std.StringHashMap(TextureAsset),

    pub fn init(gpa: Allocator, io: std.Io, renderer: *Renderer) TextureManager {
        return .{
            .gpa = gpa,
            .io = io,
            .renderer = renderer,
            .assets = std.StringHashMap(TextureAsset).init(gpa),
        };
    }

    pub fn deinit(self: *TextureManager) void {
        var iter = self.assets.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.image.deinit();
            entry.value_ptr.frame_textures.deinit(self.gpa);
            self.gpa.free(entry.value_ptr.source_path);
            self.gpa.free(entry.key_ptr.*);
        }
        self.assets.deinit();
    }

    pub fn load(self: *TextureManager, name: []const u8, path: []const u8) !void {
        const abs_path = try std.Io.Dir.cwd().realPathFileAlloc(self.io, path, self.gpa);
        errdefer self.gpa.free(abs_path);

        const mtime = statMtime(self.io, abs_path);

        var image = try ZxlReader.fromFile(self.gpa, self.io, abs_path);
        errdefer image.deinit();

        var frame_textures: std.ArrayList(?*Texture) = .empty;
        errdefer frame_textures.deinit(self.gpa);
        for (0..image.frames.items.len) |_| {
            try frame_textures.append(self.gpa, null);
        }

        try self.store(name, image, frame_textures, abs_path, mtime);
    }

    pub fn get(self: *TextureManager, name: []const u8) ?*TextureAsset {
        return self.assets.getPtr(name);
    }

    // Return cached GPU texture for frame_index, uploading it if not yet done
    pub fn getFrameTexture(self: *TextureManager, asset: *TextureAsset, frame_index: usize) !*Texture {
        if (asset.frame_textures.items[frame_index]) |tex| return tex;

        const frame = asset.image.getFrame(frame_index) orelse return error.InvalidFrame;
        const rgba_data = try asset.image.toRgbaBuffer(frame_index);
        defer asset.image.gpa.free(rgba_data);

        const texture = try self.renderer.createTexture(frame.width, frame.height);
        self.renderer.uploadTextureData(texture, frame.width, frame.height, rgba_data.ptr, @as(u32, frame.width) * 4);

        asset.frame_textures.items[frame_index] = texture;
        return texture;
    }

    // Re-read .zxl from disk; null out cached GPU textures so they're re-uploaded next render
    pub fn reload(self: *TextureManager, name: []const u8) !void {
        const entry = self.assets.getPtr(name) orelse return error.AssetNotFound;

        var new_image = try ZxlReader.fromFile(self.gpa, self.io, entry.source_path);
        errdefer new_image.deinit();

        // Null out all cached textures (GPU textures will be re-created lazily)
        for (entry.frame_textures.items) |*slot| slot.* = null;

        // Resize frame_textures if the new image has a different frame count
        const new_count = new_image.frames.items.len;
        entry.frame_textures.clearRetainingCapacity();
        for (0..new_count) |_| {
            try entry.frame_textures.append(self.gpa, null);
        }

        entry.image.deinit();
        entry.image = new_image;
        entry.last_modified = statMtime(self.io, entry.source_path);

        log.info(.assets, "Hot-reloaded texture: {s}", .{name});
    }

    // Stat every tracked file; reload any whose mtime changed
    pub fn checkForChanges(self: *TextureManager) !void {
        var iter = self.assets.iterator();
        while (iter.next()) |entry| {
            const current_mtime = statMtime(self.io, entry.value_ptr.source_path);
            if (current_mtime > entry.value_ptr.last_modified) {
                self.reload(entry.key_ptr.*) catch |err| {
                    log.warn(.assets, "Failed to reload texture {s}: {}", .{ entry.key_ptr.*, err });
                };
            }
        }
    }

    // --- internals ---

    fn store(
        self: *TextureManager,
        name: []const u8,
        image: ZxlImage,
        frame_textures: std.ArrayList(?*Texture),
        source_path: []const u8,
        mtime: i96,
    ) !void {
        const gop = try self.assets.getOrPut(name);
        if (gop.found_existing) {
            gop.value_ptr.image.deinit();
            gop.value_ptr.frame_textures.deinit(self.gpa);
            self.gpa.free(gop.value_ptr.source_path);
        } else {
            gop.key_ptr.* = try self.gpa.dupe(u8, name);
        }
        gop.value_ptr.* = .{
            .image = image,
            .frame_textures = frame_textures,
            .source_path = source_path,
            .last_modified = mtime,
        };
    }
};

fn statMtime(io: std.Io, path: []const u8) i96 {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return stat.mtime.nanoseconds;
}
