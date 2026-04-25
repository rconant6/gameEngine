const std = @import("std");
const math = @import("math");
const V2 = math.V2;
const Allocator = std.mem.Allocator;
const scene = @import("scene");
const scene_fmt = @import("scene-format");
pub const SceneFile = scene_fmt.SceneFile;
const EntityDeclaration = scene_fmt.EntityDeclaration;

pub const EditorCommand = union(enum) {
    open_file,
    save_file,
    close_file,
    select_entity,
    deselect,
};

pub const EntityRef = struct {
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
// TODO: do we want to keep a quick list of the entities vice scanning every rebuild?

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
    if (self.scene_file) |sf| {
        sf.deinit(self.gpa);
        self.gpa.destroy(sf);
    }
    if (self.scene_path.len > 0) self.gpa.free(self.scene_path);
}

pub fn loadFileFromPath(self: *Self, path: []const u8) !void {
    self.scene_path = try self.gpa.dupe(path);
    errdefer self.gpa.free(self.scene_path);

    // actually read in the file from the path
}

pub fn save(self: *Self) !void {
    if (!self.dirty) return;
    // actually write out the file
}

pub fn closeFile(self: *Self) !void {
    if (self.dirty) self.save();
}

pub fn getSelectedEntity(self: *const Self) ?*EntityDeclaration {
    _ = self;
}
