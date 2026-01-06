const std = @import("std");
const rend = @import("renderer");
const Shapes = rend.cs;
const Shape = rend.Shape;
const Type = std.builtin.Type;

pub const ShapeData = blk: {
    const registry = ShapeRegistry;

    var enum_fields: [ShapeRegistry.shape_types.len]Type.EnumField = undefined;
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

pub const ShapeRegistry = struct {
    pub const shape_types = blk: {
        const names = @typeInfo(Shapes).@"struct".decls;
        var types: [names.len]type = undefined;
        for (names, 0..) |name, i| {
            types[i] = @field(Shapes, name.name);
        }
        break :blk types;
    };

    pub const shape_names = blk: {
        const decls = @typeInfo(Shapes).@"struct".decls;
        var names: [decls.len][]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            names[i] = decl.name;
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

    pub fn createShapeUnion(comptime ShapeType: type, shape: ShapeType) Shape {
        if (ShapeType == Shapes.Circle) {
            return .{ .circle = shape };
        } else if (ShapeType == Shapes.Rectangle) {
            return .{ .rectangle = shape };
        } else if (ShapeType == Shapes.Triangle) {
            return .{ .triangle = shape };
        } else if (ShapeType == Shapes.Line) {
            return .{ .line = shape };
        } else if (ShapeType == Shapes.Polygon) {
            return .{ .polygon = shape };
        } else if (ShapeType == Shapes.Ellipse) {
            return .{ .ellipse = shape };
        } else {
            @compileError("Unknown shape type: " ++ @typeName(ShapeType));
        }
    }
};
