const std = @import("std");
const renderer = @import("renderer");
const Shapes = renderer.Shapes;
const Type = std.builtin.Type;
const math = @import("math");
const WorldPoint = math.WorldPoint;
const ScreenPoint = math.ScreenPoint;

pub const CoordinateSpace = enum { WorldSpace, ScreenSpace };
pub const point_types = .{ WorldPoint, ScreenPoint };
pub const point_type_names = .{ "World", "Screen" };

pub const ShapeData = blk: {
    const registry = ShapeRegistry;

    var enum_fields: [ShapeRegistry.shape_types.len]Type.EnumField = undefined;
    for (registry.shape_names, 0..) |name, i| {
        enum_fields[i] = .{
            .name = name[0..name.len :0],
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
            .name = name[0..name.len :0],
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
        const decls = @typeInfo(Shapes).@"struct".decls;
        const decls_len = decls.len;
        const point_types_count = point_types.len;
        const total_size = decls_len * point_types_count;
        var types: [total_size]type = undefined;
        for (decls, 0..) |decl, i| {
            if (@typeInfo(@TypeOf(@field(Shapes, decl.name))) == .@"fn") {
                for (point_types, 0..) |point_type, j| {
                    types[i * point_types_count + j] = @field(Shapes, decl.name)(point_type);
                }
            }
        }
        break :blk types;
    };

    pub const shape_names = blk: {
        const decls = @typeInfo(Shapes).@"struct".decls;
        const decls_len = decls.len;
        const point_types_count = point_types.len;
        const total_size = decls_len * point_types_count;
        var names: [total_size][]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            if (@typeInfo(@TypeOf(@field(Shapes, decl.name))) == .@"fn") {
                for (point_type_names, 0..) |type_name, j| {
                    names[i * point_types_count + j] = decl.name ++ type_name;
                }
            }
        }
        break :blk names;
    };

    pub fn getShapeIndex(name: []const u8, coord_space: CoordinateSpace) ?usize {
        return switch (coord_space) {
            .WorldSpace => getWorldShapeIndex(name),
            .ScreenSpace => getScreenShapeIndex(name),
        };
    }
    fn getWorldShapeIndex(name: []const u8) ?usize {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.ascii.startsWithIgnoreCase(shape_name, name) and
                std.mem.endsWith(u8, shape_name, "World"))
            {
                return i;
            }
        }
        return null;
    }
    fn getScreenShapeIndex(name: []const u8) ?usize {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.ascii.startsWithIgnoreCase(shape_name, name) and
                std.mem.endsWith(u8, shape_name, "Screen"))
            {
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

    pub fn createShapeUnion(comptime ShapeType: type, shape: ShapeType) ShapeData {
        inline for (shape_names, 0..) |name, i| {
            if (ShapeType == shape_types[i]) {
                return @unionInit(ShapeData, name, shape);
            }
        }
        @compileError("Unknown shape type: " ++ @typeName(ShapeType));
    }
};
