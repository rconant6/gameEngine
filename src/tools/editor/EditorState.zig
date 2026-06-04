const std = @import("std");
const math = @import("math");
const V2 = math.V2;
const Allocator = std.mem.Allocator;
const scene = @import("scene");
const scene_fmt = @import("scene-format");
pub const SceneFile = scene_fmt.SceneFile;
const EntityDeclaration = scene_fmt.EntityDeclaration;
const log = @import("debug").log;

pub const EditorCommand = union(enum) {
    open_file,
    save_file,
    close_file,
    select_entity,
    deselect,
};

pub const EntityRef = struct {
    scene_name: ?[]const u8,
    entity_name: []const u8,
};

const Self = @This();

persistent: Allocator,
scene_file: ?*SceneFile,
scene_path: []const u8,
selected: ?EntityRef,
dirty: bool,
camera_pos: V2,
camera_zoom: f32,
// TODO: do we want to keep a quick list of the entities vice scanning every rebuild?

pub fn init(gpa: Allocator) Self {
    return .{
        .persistent = gpa,
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
        sf.deinit(self.persistent);
        self.persistent.destroy(sf);
    }
    if (self.scene_path.len > 0) self.persistent.free(self.scene_path);
}

pub fn loadFileFromPath(self: *Self, path: []const u8) !void {
    self.scene_path = try self.persistent.dupe(path);
    errdefer self.persistent.free(self.scene_path);

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
    const sf = self.scene_file orelse return null;
    const ref = self.selected orelse return null;
    if (findEntity(sf.decls, ref)) |e| return e;
    log.warn(
        .application,
        "Scene does not have entity: {?s}:{s}",
        .{ ref.scene_name, ref.entity_name },
    );
    return null;
}

fn findEntity(decls: []const scene_fmt.Declaration, ref: EntityRef) ?*EntityDeclaration {
    for (decls) |*decl| {
        switch (decl.*) {
            .entity => |*e| {
                if (ref.scene_name == null and std.mem.eql(u8, e.name, ref.entity_name))
                    return e;
            },
            .scene => |*s| {
                if (ref.scene_name) |sn| {
                    if (std.mem.eql(u8, s.name, sn)) {
                        for (s.decls) |*child| {
                            switch (child.*) {
                                .entity => |*e| {
                                    if (std.mem.eql(u8, e.name, ref.entity_name))
                                        return e;
                                },
                                else => {},
                            }
                        }
                    }
                }
            },
            else => {},
        }
    }
    return null;
}
