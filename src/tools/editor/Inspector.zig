const std = @import("std");
const Allocator = std.mem.Allocator;
const ui = @import("ui");
const Label = ui.Label;
const Spacer = ui.Spacer;
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const scene_fmt = @import("scene-format");
const EditorState = @import("EditorState.zig");
const EntityRef = EditorState.EntityRef;
const Property = scene_fmt.Property;

const dummy_loc: scene_fmt.SourceLocation = .{ .line = 0, .col = 0, .len = 0 };

const dummy_component: scene_fmt.ComponentDeclaration = .{
    .generic = .{
        .name = "Transform",
        .properties = &.{
            .{ .name = "position", .type_annotation = .{
                .base_type = .vec3,
                .is_array = false,
            }, .value = .{
                .vector = &.{ 1.0, 2.0, 0.0 },
            }, .location = dummy_loc },
            .{ .name = "rotation", .type_annotation = .{
                .base_type = .f32,
                .is_array = false,
            }, .value = .{ .number = 0.0 }, .location = dummy_loc },
            .{ .name = "scale", .type_annotation = .{
                .base_type = .f32,
                .is_array = false,
            }, .value = .{ .number = 1.0 }, .location = dummy_loc },
        },
        .nested_blocks = null,
        .location = dummy_loc,
    },
};

const dummy_entity: scene_fmt.EntityDeclaration = .{
    .name = "Player",
    .location = dummy_loc,
    .components = &.{
        dummy_component,
        .{
            .sprite = .{
                .name = "Sprite",
                .shape_type = "circle",
                .properties = &.{
                    .{ .name = "radius", .type_annotation = .{
                        .base_type = .f32,
                        .is_array = false,
                    }, .value = .{ .number = 1.0 }, .location = dummy_loc },
                    .{ .name = "fill_color", .type_annotation = .{
                        .base_type = .color,
                        .is_array = false,
                    }, .value = .{ .color = 0x00FF00 }, .location = dummy_loc },
                    .{ .name = "visible", .type_annotation = .{
                        .base_type = .bool,
                        .is_array = false,
                    }, .value = .{ .boolean = true }, .location = dummy_loc },
                },
                .location = dummy_loc,
            },
        },
    },
};

fn buildEmptyState(
    arena: std.mem.Allocator,
) *WidgetNode {
    return make.label(
        arena,
        "Nothing Selected",
        .{
            .color = Colors.LIGHT_GRAY,
            .font_scale = 32,
        },
    );
}

fn buildPropertyRow(arena: Allocator, prop: Property) *WidgetNode {
    const title_txt = std.fmt.allocPrint(
        arena,
        "{s}: ",
        .{prop.name},
    ) catch "XXXXXX";
    const title_label = make.label(arena, title_txt, .{
        .color = Colors.ABYSS_BLUE,
    });

    const value_txt: []const u8 = switch (prop.value) {
        .number => |n| std.fmt.allocPrint(arena, "{d}", .{n}) catch "???",
        .boolean => |b| if (b) "true" else "false",
        .string, .assetRef => |s| s,
        .color => |c| std.fmt.allocPrint(arena, "#{x:0>6}", .{c}) catch "#???????",
        .array => |a| std.fmt.allocPrint(arena, "...{d}", .{a.len}) catch "???",
        .vector => |v| switch (v.len) {
            2 => std.fmt.allocPrint(
                arena,
                "[{d}, {d}]",
                .{ v[0], v[1] },
            ) catch "[??, ??]",
            3 => std.fmt.allocPrint(
                arena,
                "[{d}, {d}, {d}]",
                .{ v[0], v[1], v[2] },
            ) catch "[??, ??, ??]",
            else => "vec[???]",
        },
    };

    const value_label = make.label(arena, value_txt, .{
        .color = Colors.ABYSS_BLUE,
    });

    return make.hstack(arena, &.{ title_label, value_label }, .{});
}

pub fn buildTree(
    arena: Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const EditorState = @ptrCast(@alignCast(raw_state));
    _ = state;

    const bg = make.colorRect(arena, Colors.ABYSS_BLUE, .{
        .border_color = Colors.BLACK,
        .border_width = 1,
    });
    return make.vstack(arena, &.{ buildPropertyRow(
        arena,
        Property{
            .location = .{ .col = 0, .len = 0, .line = 0 },
            .name = "dummy",
            .type_annotation = .{ .base_type = .f32, .is_array = false },
            .value = .{ .number = 12.0 },
        },
    ), bg }, .{});
}
