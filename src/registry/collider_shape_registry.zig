const std = @import("std");
const ecs = @import("ecs");
const Colliders = ecs.colliders;

pub const ColliderData = blk: {
    const registry = ColliderRegistry;
    const len = registry.shape_types.len;

    var enum_names: [len][]const u8 = undefined;
    var enum_values: [len]u8 = undefined;
    for (registry.shape_names, 0..) |name, i| {
        enum_names[i] = name;
        enum_values[i] = i;
    }
    const TagEnum = @Enum(u8, .exhaustive, &enum_names, &enum_values);

    var union_names: [len][]const u8 = undefined;
    var union_types: [len]type = undefined;
    var union_attrs: [len]std.builtin.Type.UnionField.Attributes = undefined;
    for (registry.shape_types, registry.shape_names, 0..) |shape_type, name, i| {
        union_names[i] = name;
        union_types[i] = shape_type;
        union_attrs[i] = .{};
    }

    break :blk @Union(.auto, TagEnum, &union_names, &union_types, &union_attrs);
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
