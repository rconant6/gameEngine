const Engine = @import("engine.zig").Engine;
const scene = @import("scene");
const log = @import("debug").log;

pub fn loadScene(
    self: *Engine,
    scene_name: []const u8,
    filename: []const u8,
) !void {
    if (self.scene_manager.scenes.contains(scene_name)) {
        log.warn(.scene, "Already loaded {s} from {s}", .{ scene_name, filename });
        return;
    }

    self.scene_manager.loadScene(scene_name, filename) catch |err| {
        log.err(
            .scene,
            "Failed to load {s} from {s}: {any}",
            .{ scene_name, filename, err },
        );
        return err;
    };
}

pub fn loadTemplates(
    self: *Engine,
    dir_path: []const u8,
) !void {
    self.template_manager.loadTemplatesFromDirectory(dir_path) catch |err| {
        log.err(.scene, "Failed to load templates from {s}: {any}", .{ dir_path, err });
        return err;
    };
}

pub fn setActiveScene(self: *Engine, scene_name: []const u8) !void {
    self.scene_manager.setActiveScene(scene_name) catch |e| {
        return e;
    };
}

pub fn instantiateActiveScene(self: *Engine) !void {
    const scene_file = self.scene_manager.getActiveScene() orelse return error.NoActiveScene;

    self.instantiator.instantiate(scene_file) catch |e| {
        log.err(
            .scene,
            "Failed to instantiate {s}: {any}",
            .{ scene_file.source_file_name, e },
        );
        return e;
    };
}

pub fn reloadActiveScene(self: *Engine) !void {
    self.instantiator.clearLastInstantiated(&self.world);

    self.scene_manager.reloadActiveScene() catch |err| {
        try self.instantiateActiveScene();
        return err;
    };

    try self.instantiateActiveScene();
}
