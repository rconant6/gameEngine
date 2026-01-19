const Engine = @import("engine.zig").Engine;
const scene = @import("scene");

pub fn loadScene(
    self: *Engine,
    scene_name: []const u8,
    filename: []const u8,
) !void {
    if (self.scene_manager.scenes.contains(scene_name)) {
        self.logInfo(.scene, "Scene {s} is already loaded", .{scene_name});
        return;
    }

    self.scene_manager.loadScene(scene_name, filename) catch |err| {
        self.logError(
            .scene,
            "Failed to load scene '{s}' from '{s}': {any}",
            .{ scene_name, filename, err },
        );
        return;
    };

    self.logInfo(.scene, "Loaded scene '{s}' from '{s}'", .{ scene_name, filename });
}

pub fn loadTemplates(
    self: *Engine,
    dir_path: []const u8,
) !void {
    self.template_manager.loadTemplatesFromDirectory(dir_path) catch |err| {
        self.logError(
            .scene,
            "Failed to load template(s) from '{s}': {any}",
            .{ dir_path, err },
        );
        return;
    };

    self.logInfo(
        .scene,
        "Loaded template(s) from '{s}'",
        .{dir_path},
    );
}

pub fn setActiveScene(self: *Engine, scene_name: []const u8) !void {
    self.scene_manager.setActiveScene(scene_name) catch |err| {
        self.logError(.scene, "Failed to set the active scene: {any}", .{err});
        return {};
    };
}

pub fn instantiateActiveScene(self: *Engine) !void {
    const scene_file = self.scene_manager.getActiveScene() orelse return error.NoActiveScene;
    self.instantiator.instantiate(scene_file) catch |err| {
        self.logError(.scene, "Failed to instantiate scene: {any}", .{err});
        return err;
    };
}

pub fn reloadActiveScene(self: *Engine) !void {
    self.logInfo(.scene, "Reloading active scene...", .{});

    self.instantiator.clearLastInstantiated(&self.world);

    self.scene_manager.reloadActiveScene() catch |err| {
        self.logError(.scene, "Failed to reload scene: {any}", .{err});
        self.logWarning(.scene, "Keeping previous scene state", .{});

        try self.instantiateActiveScene();
        return;
    };

    try self.instantiateActiveScene();

    self.logInfo(.scene, "Scene reloaded successfully", .{});
}
