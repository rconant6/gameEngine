const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Type = std.builtin.Type;
const core = @import("math");
const V2 = core.V2;
const ComponentData = core.ComponentData;
const ecs = @import("ecs");
const Entity = ecs.Entity;
const World = ecs.World;
const Transform = ecs.Transform;
const load = @import("loader.zig");
const scene_format = @import("scene-format");
const SceneFile = scene_format.SceneFile;
const TemplateDeclaration = scene_format.TemplateDeclaration;
const Instantiator = @import("instantiator.zig").Instantiator;

const TemplateError = error{
    TemplateAlreadyLoaded,
    TemplateNotFound,
};

pub const Template = struct {
    name: []const u8,
    declaration: TemplateDeclaration,
};

pub const TemplateManager = struct {
    allocator: Allocator,
    template_files: std.ArrayList(*SceneFile),
    templates: std.StringHashMap(Template),
    instantiator: *Instantiator,

    pub fn init(
        allocator: Allocator,
        instantiator: *Instantiator,
    ) TemplateManager {
        return .{
            .allocator = allocator,
            .templates = std.StringHashMap(Template).init(allocator),
            .template_files = .empty,
            .instantiator = instantiator,
        };
    }

    pub fn deinit(self: *TemplateManager) void {
        var iter = self.templates.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*); // Free lowercase key
            self.allocator.free(entry.value_ptr.name); // Free original name
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
    ) !Entity {
        const instantiator = self.instantiator;
        const world = instantiator.world;
        var buf: [256]u8 = undefined;
        const lower = std.ascii.lowerString(&buf, name);
        const template = self.templates.get(lower) orelse return TemplateError.TemplateNotFound;
        const entity = try instantiator.world.createEntity();

        const components = template.declaration.components;
        for (components) |*comp| {
            try instantiator.addComponent(entity, comp);
        }

        if (world.getComponentMut(entity, Transform)) |transform| {
            transform.position = transform.position.add(position);
        }

        return entity;
    }

    pub fn loadTemplateFile(self: *TemplateManager, name: []const u8) !void {
        if (self.templates.contains(name)) {
            std.log.warn("{s} is already loaded, skipping...", .{name});
            return;
        }

        const owned_file = try self.allocator.create(SceneFile);
        errdefer self.allocator.destroy(owned_file);
        owned_file.* = try load.loadTemplateFile(self.allocator, name);
        try self.template_files.append(self.allocator, owned_file);

        for (owned_file.decls) |decl| {
            switch (decl) {
                .template => |t| {
                    const owned_name_lower = try std.ascii.allocLowerString(
                        self.allocator,
                        t.name,
                    );
                    errdefer self.allocator.free(owned_name_lower);

                    const owned_name = try self.allocator.dupe(u8, t.name);
                    errdefer self.allocator.free(owned_name);

                    const template: Template = .{
                        .declaration = t,
                        .name = owned_name,
                    };
                    try self.templates.put(owned_name_lower, template);
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
        var buf: [256]u8 = undefined;
        const lower = std.ascii.lowerString(&buf, name);
        return self.templates.contains(lower);
    }

    pub fn getTemplate(self: *const TemplateManager, name: []const u8) ?Template {
        var buf: [256]u8 = undefined;
        const lower = std.ascii.lowerString(&buf, name);
        return self.templates.get(lower);
    }
};
