const std = @import("std");
const rend = @import("renderer");
const Shapes = rend.cs;
const Shape = rend.Shape;

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
