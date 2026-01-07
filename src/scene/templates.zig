const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Type = std.builtin.Type;
const core = @import("core");
const V2 = core.V2;
const ComponentData = core.ComponentData;
const ecs = @import("entity");
const Entity = ecs.Entity;
const World = ecs.World;
const load = @import("loader.zig");
const scene_format = @import("scene-format");
const SceneFile = scene_format.SceneFile;
const TemplateDeclaration = scene_format.TemplateDeclaration;

const TemplateError = error{
    TemplateAlreadyLoaded,
};

pub const Template = struct {
    name: []const u8,
    declaration: TemplateDeclaration,
};

pub const TemplateManager = struct {
    allocator: Allocator,
    template_files: std.ArrayList(*SceneFile),
    templates: std.StringHashMap(Template),

    pub fn init(allocator: Allocator) TemplateManager {
        return .{
            .allocator = allocator,
            .templates = std.StringHashMap(Template).init(allocator),
            .template_files = .empty,
        };
    }

    pub fn deinit(self: *TemplateManager) void {
        var iter = self.templates.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.templates.deinit();

        for (self.template_files.items) |file| {
            file.deinit(self.allocator);
            self.allocator.destroy(file);
        }
        self.template_files.deinit(self.allocator);
    }

    pub fn instantiate(
        // NOTE: this is creating entities from the list of delcartion data
        self: *TemplateManager,
        name: []const u8,
        position: V2,
        world: *World,
    ) !Entity {
        _ = name;
        _ = self;
        _ = position;
        _ = world;
        return .{ .id = 0 };
    }

    pub fn loadTemplateFile(self: *TemplateManager, name: []const u8) !void {
        if (self.templates.contains(name)) return TemplateError.TemplateAlreadyLoaded;

        const owned_file = try self.allocator.create(SceneFile);
        errdefer self.allocator.destroy(owned_file);
        owned_file.* = try load.loadTemplateFile(self.allocator, name);

        try self.template_files.append(self.allocator, owned_file);

        for (owned_file.decls) |decl| {
            switch (decl) {
                .template => |t| {
                    const owned_name = try self.allocator.dupe(u8, t.name);
                    errdefer self.allocator.free(owned_name);
                    const template: Template = .{
                        .declaration = t,
                        .name = owned_name,
                    };
                    try self.templates.put(owned_name, template);
                },
                else => {},
            }
        }
    }

    pub fn loadTemplatesFromDirectory(self: *TemplateManager, dir_path: []const u8) !void {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            switch (entry.kind) {
                .file => {
                    if (std.mem.endsWith(u8, entry.name, ".template")) {
                        const full_path = try std.fmt.allocPrint(
                            self.allocator,
                            "{s}{s}",
                            .{ dir_path, entry.name },
                        );
                        errdefer self.allocator.free(full_path);
                        defer self.allocator.free(full_path);
                        try self.loadTemplateFile(full_path);
                    }
                },
                else => continue,
            }
        }
    }
    pub fn hasTemplate(self: *const TemplateManager, name: []const u8) bool {
        return self.templates.contains(name);
    }

    pub fn getTemplate(self: *const TemplateManager, name: []const u8) ?Template {
        return self.templates.get(name);
    }
};
