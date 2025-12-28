const std = @import("std");
const core = @import("core");
const V2 = core.V2;
const V2I = core.V2I;
const V2U = core.V2U;
const ecs = @import("entity");
const Components = ecs.comps;
const scene_format = @import("scene-format");
const BaseTypes = scene_format.BaseType;

pub const ComponentRegistry = struct {
    pub const component_types = blk: {
        const names = std.meta.declarations(Components);
        var types: [names.len]type = undefined;
        for (names, 0..) |name, i| {
            types[i] = @field(Components, name.name);
        }
        break :blk types;
    };

    pub const component_names = blk: {
        const decls = std.meta.declarations(Components);
        var names: [decls.len][]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            names[i] = decl.name;
        }
        break :blk names;
    };

    pub fn getComponentIndex(name: []const u8) ?usize {
        inline for (component_names, 0..) |comp_name, i| {
            if (std.mem.eql(u8, name, comp_name)) {
                return i;
            }
        }
        return null;
    }

    pub fn getComponentType(comptime name: []const u8) ?type {
        inline for (component_names, 0..) |comp_name, i| {
            if (std.mem.eql(u8, name, comp_name)) {
                return component_types[i];
            }
        }
        return null;
    }
};
