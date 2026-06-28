const std = @import("std");
const ecs = @import("ecs");
const Components = ecs.comps;

pub const ComponentData = blk: {
    const registry = ComponentRegistry;
    const len = registry.component_types.len;

    var enum_names: [len][]const u8 = undefined;
    var enum_values: [len]u16 = undefined;
    for (registry.component_names, 0..) |name, i| {
        enum_names[i] = name;
        enum_values[i] = i;
    }
    const TagEnum = @Enum(u16, .exhaustive, &enum_names, &enum_values);

    var union_names: [len][]const u8 = undefined;
    var union_types: [len]type = undefined;
    var union_attrs: [len]std.builtin.Type.UnionField.Attributes = undefined;
    for (registry.component_types, registry.component_names, 0..) |comp_type, name, i| {
        union_names[i] = name;
        union_types[i] = comp_type;
        union_attrs[i] = .{};
    }

    break :blk @Union(.auto, TagEnum, &union_names, &union_types, &union_attrs);
};

pub const ComponentRegistry = struct {
    // A component is a STRUCT decl in Components. The module also holds field-type
    // helpers (e.g. the TextAlign enum used by Text.alignment) — those are NOT
    // components and must be skipped, or they pollute the union/tag enum below.
    fn isComponentDecl(comptime name: []const u8) bool {
        const field = @field(Components, name);
        if (@TypeOf(field) != type) return false; // not a type at all
        return @typeInfo(field) == .@"struct";
    }

    const component_count = blk: {
        var n = 0;
        for (@typeInfo(Components).@"struct".decls) |decl| {
            if (isComponentDecl(decl.name)) n += 1;
        }
        break :blk n;
    };

    pub const component_types = blk: {
        var types: [component_count]type = undefined;
        var i = 0;
        for (@typeInfo(Components).@"struct".decls) |decl| {
            if (!isComponentDecl(decl.name)) continue;
            types[i] = @field(Components, decl.name);
            i += 1;
        }
        break :blk types;
    };

    pub const component_names = blk: {
        var names: [component_count][]const u8 = undefined;
        var i = 0;
        for (@typeInfo(Components).@"struct".decls) |decl| {
            if (!isComponentDecl(decl.name)) continue;
            names[i] = decl.name;
            i += 1;
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
