const std = @import("std");
const Allocator = std.mem.Allocator;
const scene_format = @import("scene-format");
const SceneFile = scene_format.SceneFile;
const load = @import("loader.zig");

pub const SceneManager = struct {
    allocator: Allocator,
    scenes: std.StringHashMap(*SceneFile),
    active_scene_name: ?[]const u8,

    pub fn init(allocator: Allocator) SceneManager {
        return .{
            .allocator = allocator,
            .scenes = .init(allocator),
            .active_scene_name = null,
        };
    }
    pub fn deinit(self: *SceneManager) void {
        var iter = self.scenes.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.scenes.deinit();

        if (self.active_scene_name) |as| self.allocator.free(as);
    }

    pub fn loadScene(
        self: *SceneManager,
        name: []const u8,
        file_path: []const u8,
    ) !void {
        if (self.scenes.contains(name)) return SceneManagerError.SceneAlreadyLoaded;

        const scene = load.loadSceneFile(self.allocator, file_path) catch |err| {
            std.log.err(
                "[SCENEMANAGER] - unable to load {s} from {s}: {}",
                .{ name, file_path, err },
            );
            return err;
        };

        const owned_scene = try self.allocator.create(SceneFile);
        errdefer self.allocator.destroy(owned_scene);
        owned_scene.* = scene;

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        try self.scenes.put(owned_name, owned_scene);
    }
    pub fn unloadScene(self: *SceneManager, name: []const u8) !void {
        if (self.active_scene_name) |as|
            if (std.mem.eql(u8, as, name))
                return SceneManagerError.CannotUnloadActiveScene;

        const scene_entry = self.scenes.fetchRemove(name) orelse
            return SceneManagerError.SceneNotFound;

        scene_entry.value.deinit(self.allocator);
        self.allocator.destroy(scene_entry.value);
        self.allocator.free(scene_entry.key);
    }
    pub fn reloadActiveScene(self: *SceneManager) void {
        std.log.info("Trying to re-load the scene", .{});
        _ = self;
        std.log.info("Did re-load the scene", .{});
    }

    pub fn setActiveScene(self: *SceneManager, name: []const u8) !void {
        if (!self.scenes.contains(name)) return SceneManagerError.SceneNotFound;

        if (self.active_scene_name) |old_name| self.allocator.free(old_name);
        self.active_scene_name = try self.allocator.dupe(u8, name);
    }
    pub fn getActiveScene(self: *SceneManager) ?*SceneFile {
        if (self.active_scene_name) |active_scene|
            return self.scenes.get(active_scene);
        return null;
    }

    pub fn getScene(self: *SceneManager, name: []const u8) ?*SceneFile {
        return self.scenes.get(name);
    }
};
pub const SceneManagerError = error{
    SceneAlreadyLoaded,
    SceneNotFound,
    CannotUnloadActiveScene,
};
