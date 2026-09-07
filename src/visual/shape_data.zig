const std = @import("std");
const Shapes = @import("shapes");
const math = @import("math");
const V2 = math.V2;

pub const ShapeData = blk: {
    const registry = ShapeRegistry;
    const len = ShapeRegistry.shape_types.len;

    var enum_names: [len][]const u8 = undefined;
    var enum_values: [len]u8 = undefined;
    var union_names: [len][]const u8 = undefined;
    var union_types: [len]type = undefined;
    var union_attrs: [len]std.builtin.Type.UnionField.Attributes = undefined;

    for (registry.shape_types, registry.shape_names, 0..) |shape_type, name, i| {
        enum_names[i] = name;
        enum_values[i] = i;
        union_types[i] = shape_type;
        union_names[i] = name;
        union_attrs[i] = .{};
    }

    const TagEnum = @Enum(u8, .exhaustive, &enum_names, &enum_values);
    break :blk @Union(.auto, TagEnum, &union_names, &union_types, &union_attrs);
};

pub const ShapeRegistry = struct {
    pub const shape_types = blk: {
        const decls = @typeInfo(Shapes).@"struct".decls;
        const decls_len = decls.len;
        var types: [decls_len]type = undefined;
        for (decls, 0..) |decl, i| {
            types[i] = @field(Shapes, decl.name);
        }
        break :blk types;
    };

    pub const shape_names = blk: {
        const decls = @typeInfo(Shapes).@"struct".decls;
        const decls_len = decls.len;
        var names: [decls_len][]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            names[i] = decl.name;
        }
        break :blk names;
    };

    pub fn getShapeIndex(name: []const u8) ?usize {
        inline for (shape_names, 0..) |shape_name, i| {
            if (std.ascii.eqlIgnoreCase(shape_name, name))
                return i;
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

    pub fn createShapeUnion(
        comptime ShapeType: type,
        shape: ShapeType,
    ) ShapeData {
        inline for (shape_names, 0..) |name, i| {
            if (ShapeType == shape_types[i]) {
                return @unionInit(ShapeData, name, shape);
            }
        }
        @compileError("Unknown shape type: " ++ @typeName(ShapeType));
    }
};
