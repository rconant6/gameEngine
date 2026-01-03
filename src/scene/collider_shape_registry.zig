const std = @import("std");
const ecs = @import("entity");
const ColliderShape = ecs.ColliderShape;

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
