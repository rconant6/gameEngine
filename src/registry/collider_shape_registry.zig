const std = @import("std");
const ecs = @import("ecs");
const Colliders = ecs.colliders;
const Type = std.builtin.Type;

pub const ColliderData = blk: {
    const registry = ColliderRegistry;

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

pub const ColliderRegistry = struct {
    pub const shape_types = blk: {
        const decls = @typeInfo(Colliders).@"struct".decls;
        var types: [decls.len]type = undefined;
        for (decls, 0..) |decl, i| {
            types[i] = @field(Colliders, decl.name);
        }
        break :blk types;
    };

    pub const shape_names = blk: {
        const decls = @typeInfo(Colliders).@"struct".decls;
        var names: [decls.len][:0]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            names[i] = decl.name;
        }
        break :blk names;
    };

    pub fn getColliderIndex(name: []const u8) ?usize {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.ascii.startsWithIgnoreCase(shape_name, name)) {
                return i;
            }
        }
        return null;
    }

    pub fn getColliderType(comptime name: []const u8) ?type {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.mem.eql(u8, shape_name, name)) {
                return shape_types[i];
            }
        }
        return null;
    }

    pub fn createColliderUnion(comptime ColliderType: type, shape: ColliderType) ColliderData {
        inline for (shape_names, 0..) |name, i| {
            if (ColliderType == shape_types[i]) {
                return @unionInit(ColliderData, name, shape);
            }
        }
        @compileError("Unknown collider shape type: " ++ @typeName(ColliderType));
    }
};
