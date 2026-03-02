const std = @import("std");
const Widgets = @import("widgets.zig");
const Type = std.builtin.Type;

pub const WidgetData = blk: {
    const registry = WidgetRegistry;

    var enum_fields: [registry.widget_types.len]Type.EnumField = undefined;
    for (registry.widget_names, 0..) |name, i| {
        enum_fields[i] = .{
            .name = name[0..name.len :0],
            .value = i,
        };
    }
    const TagEnum = @Type(.{
        .@"enum" = .{
            .tag_type = u16,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });

    var union_fields: [registry.widget_types.len]Type.UnionField = undefined;
    for (registry.widget_types, registry.widget_names, 0..) |widget_type, name, i| {
        union_fields[i] = .{
            .name = name[0..name.len :0],
            .type = widget_type,
            .alignment = @alignOf(widget_type),
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
