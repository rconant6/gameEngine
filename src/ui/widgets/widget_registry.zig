const std = @import("std");
const Widgets = @import("widgets.zig");

pub const WidgetData = blk: {
    const registry = WidgetRegistry;
    const len = registry.widget_types.len;

    var enum_names: [len][]const u8 = undefined;
    var enum_values: [len]u16 = undefined;
    for (registry.widget_names, 0..) |name, i| {
        enum_names[i] = name;
        enum_values[i] = i;
    }
    const TagEnum = @Enum(u16, .exhaustive, &enum_names, &enum_values);

    var union_names: [len][]const u8 = undefined;
    var union_types: [len]type = undefined;
    var union_attrs: [len]std.builtin.Type.UnionField.Attributes = undefined;
    for (registry.widget_types, registry.widget_names, 0..) |widget_type, name, i| {
        union_names[i] = name;
        union_types[i] = widget_type;
        union_attrs[i] = .{};
    }

    break :blk @Union(.auto, TagEnum, &union_names, &union_types, &union_attrs);
};

pub const WidgetRegistry = struct {
    pub const widget_types = blk: {
        const decls = @typeInfo(Widgets).@"struct".decls;
        var types: [decls.len]type = undefined;
        for (decls, 0..) |decl, i| {
            types[i] = @field(Widgets, decl.name);
        }
        break :blk types;
    };

    pub const widget_names = blk: {
        const decls = @typeInfo(Widgets).@"struct".decls;
        var names: [decls.len][]const u8 = undefined;
        for (decls, 0..) |decl, i| {
            names[i] = decl.name;
        }
        break :blk names;
    };

    pub fn getWidgetIndex(name: []const u8) ?usize {
        inline for (widget_names, 0..) |widget_name, i| {
            if (std.mem.eql(u8, name, widget_name)) {
                return i;
            }
        }
    }

    pub fn getWidgetType(comptime name: []const u8) ?type {
        inline for (widget_names, 0..) |widget_name, i| {
            if (std.mem.eql(u8, name, widget_name)) {
                return widget_types[i];
            }
        }
        return null;
    }

    pub fn createWidgetUnion(comptime WidgetType: type, widget: WidgetType) WidgetData {
        inline for (widget_names, 0..) |name, i| {
            if (WidgetType == widget_types[i]) {
                return @unionInit(WidgetData, name, widget);
            }
        }

        @compileError("Unknown widget type: " ++ @typeName(WidgetType));
    }
};
