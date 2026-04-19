const std = @import("std");
const math = @import("math");
const V2 = math.V2;
const Allocator = std.mem.Allocator;
const scene = @import("scene");
const scene_fmt = @import("scene-format");
pub const SceneFile = scene_fmt.SceneFile;
const EntityDeclaration = scene_fmt.EntityDeclaration;

const EntityRef = struct {
    scene_idx: ?usize,
    entity_idx: usize,
};

const Self = @This();

gpa: Allocator,
scene_file: ?*SceneFile,
scene_path: []const u8,
selected: ?EntityRef,
dirty: bool,
camera_pos: V2,
camera_zoom: f32,

pub fn init(gpa: Allocator) Self {
    return .{
        .gpa = gpa,
        .scene_file = null,
        .scene_path = "",
        .selected = null,
        .dirty = false,
        .camera_pos = .ZERO,
        .camera_zoom = 1.0,
    };
}
pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn loadFile(self: *Self, path: []const u8) !void {
    _ = self;
    _ = path;
}

pub fn save(self: *Self) !void {
    _ = self;
}

pub fn getSelectedEntity(self: *const Self) ?*EntityDeclaration {
    _ = self;
}
