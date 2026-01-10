const std = @import("std");
const testing = std.testing;

const scene = @import("scene-format");
const Parser = scene.Parser;
const SceneFile = scene.SceneFile;
const Declaration = scene.Declaration;
const Value = scene.Value;

fn parseSource(allocator: std.mem.Allocator, src: [:0]const u8) !SceneFile {
    var parser = try Parser.init(allocator, src, "test.scene");
    return try parser.parse();
}

fn freeSceneFile(scene_file: *SceneFile, allocator: std.mem.Allocator) void {
    scene_file.deinit(allocator);
}

// All tests removed - these were testing the old property-based action system
// with keywords: action, action_target, key, mouse
// The new system uses nested blocks: [trigger] and [action] as identifiers
