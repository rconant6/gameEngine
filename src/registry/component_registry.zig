const std = @import("std");
const ecs = @import("ecs");
const Components = ecs.comps;
const Type = std.builtin.Type;

pub const ComponentData = blk: {
    const registry = ComponentRegistry;

    var enum_fields: [registry.component_types.len]Type.EnumField = undefined;
    for (registry.component_names, 0..) |name, i| {
        enum_fields[i] = .{
            .name = name[0..name.len :0],
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
            .name = name[0..name.len :0],
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
        const decls = @typeInfo(Components).@"struct".decls;
        var types: [decls.len]type = undefined;
        for (decls, 0..) |decl, i| {
            types[i] = @field(Components, decl.name);
        }
        break :blk types;
    };

    pub const component_names = blk: {
        const decls = @typeInfo(Components).@"struct".decls;
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

    pub fn createComponentUnion(comptime ComponentType: type, component: ComponentType) ComponentData {
        inline for (component_names, 0..) |name, i| {
            if (ComponentType == component_types[i]) {
                return @unionInit(ComponentData, name, component);
            }
        }
        @compileError("Unknown component type: " ++ @typeName(ComponentType));
    }
};
