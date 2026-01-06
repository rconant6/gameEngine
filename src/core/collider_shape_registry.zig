const std = @import("std");
const ecs = @import("entity");
const ColliderShape = ecs.ColliderShape;
const Type = std.builtin.Type;
pub const ColliderData = blk: {
    const registry = ColliderShapeRegistry;

    var enum_fields: [registry.shape_types.len]Type.EnumField = undefined;
    for (registry.shape_names, 0..) |name, i| {
        enum_fields[i] = .{
            .name = name,
            .value = i,
        };
    }
    const TagEnum = @Type(.{
        .@"enum" = .{
            .tag_type = u8,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });

    var union_fields: [registry.shape_types.len]Type.UnionField = undefined;
    for (registry.shape_types, registry.shape_names, 0..) |shape_type, name, i| {
        union_fields[i] = .{
            .name = name,
            .type = shape_type,
            .alignment = @alignOf(shape_type),
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

pub const ColliderShapeRegistry = struct {
    pub const shape_types = blk: {
        const union_fields = @typeInfo(ColliderShape).@"union".fields;
        var types: [union_fields.len]type = undefined;
        for (union_fields, 0..) |field, i| {
            types[i] = field.type;
        }
        break :blk types;
    };

    pub const shape_names = blk: {
        const union_fields = @typeInfo(ColliderShape).@"union".fields;
        var names: [union_fields.len][]const u8 = undefined;
        for (union_fields, 0..) |field, i| {
            names[i] = field.name;
        }
        break :blk names;
    };

    pub fn getShapeIndex(name: []const u8) ?usize {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.ascii.eqlIgnoreCase(name, shape_name)) {
                return i;
            }
        }
        return null;
    }

    pub fn getShapeType(comptime name: []const u8) ?type {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.mem.eql(u8, shape_name, name)) {
                return shape_types[i];
            }
        }
        return null;
    }
};
