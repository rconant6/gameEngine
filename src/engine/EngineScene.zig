const Engine = @import("engine.zig").Engine;
const scene = @import("scene");

pub fn loadScene(
    self: *Engine,
    scene_name: []const u8,
    filename: []const u8,
) !void {
    if (self.scene_manager.scenes.contains(scene_name)) {
        return;
    }

    self.scene_manager.loadScene(scene_name, filename) catch |err| {
        return err;
    };
}

pub fn loadTemplates(
    self: *Engine,
    dir_path: []const u8,
) !void {
    self.template_manager.loadTemplatesFromDirectory(dir_path) catch |err| {
        return err;
    };
}

pub fn setActiveScene(self: *Engine, scene_name: []const u8) !void {
    self.scene_manager.setActiveScene(scene_name) catch |err| {
        return err;
    };
}

pub fn instantiateActiveScene(self: *Engine) !void {
    const scene_file = self.scene_manager.getActiveScene() orelse return error.NoActiveScene;
    self.instantiator.instantiate(scene_file) catch |err| {
        return err;
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
