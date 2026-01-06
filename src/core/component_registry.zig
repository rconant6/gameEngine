const std = @import("std");
const ecs = @import("entity");
const Components = ecs.comps;
const Type = std.builtin.Type;

pub const ComponentData = blk: {
    const registry = ComponentRegistry;

    var enum_fields: [registry.component_types.len]Type.EnumField = undefined;
    for (registry.component_names, 0..) |name, i| {
        enum_fields[i] = .{
            .name = name,
            .value = i,
        };
    }
    const TagEnum = @Type(.{
        .@"enum" = .{
            .tag_type = u16,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });

    var union_fields: [registry.component_types.len]Type.UnionField = undefined;
    for (registry.component_types, registry.component_names, 0..) |comp_type, name, i| {
        union_fields[i] = .{
            .name = name,
            .type = comp_type,
            .alignment = @alignOf(comp_type),
        };
    }

    break :blk @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = TagEnum,
            .fields = &union_fields,
            .decls = &.{},
        },
    });
};

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
