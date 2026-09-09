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

fn buildEmptyState(
    ui_arena: std.mem.Allocator,
) *WidgetNode {
    return make.label(
        ui_arena,
        "Nothing Selected",
        .{
            .color = Colors.LIGHT_GRAY,
            .font_scale = 32,
        },
    );
}

/// Stable, unique widget id for one property of one entity. Entity-qualified
/// so a pending `changed` can never land on a newly selected entity's
/// same-named property. main.zig's flushInspector uses the same recipe.
pub fn propertyId(
    buf: []u8,
    entity_name: []const u8,
    component_name: []const u8,
    prop_name: []const u8,
) ?[]const u8 {
    return std.fmt.bufPrint(buf, "p:{s}:{s}:{s}", .{ entity_name, component_name, prop_name }) catch null;
}

/// The name a component is listed under (generic block name, or the sprite /
/// collider block's name).
pub fn componentName(comp: scene_fmt.ComponentDeclaration) []const u8 {
    return switch (comp) {
        inline else => |b| b.name,
    };
}

pub fn componentProperties(comp: scene_fmt.ComponentDeclaration) []Property {
    return switch (comp) {
        inline else => |b| b.properties orelse &.{},
    };
}

fn buildPropertyRow(
    ui_arena: Allocator,
    entity_name: []const u8,
    component_name: []const u8,
    prop: Property,
) *WidgetNode {
    const title_txt = std.fmt.allocPrint(
        ui_arena,
        "{s}: ",
        .{prop.name},
    ) catch "XXXXXX";
    const title_label = make.label(ui_arena, title_txt, .{
        .color = Colors.UI_TEXT_SECONDARY,
        .font_scale = 16,
    });

    var id_buf: [256]u8 = undefined;
    const id: ?[]const u8 = if (propertyId(&id_buf, entity_name, component_name, prop.name)) |tmp|
        ui_arena.dupe(u8, tmp) catch null
    else
        null;

    // Editable kinds get a typed editor; everything else stays a read-only label.
    if (id) |wid| switch (prop.value) {
        .boolean => |b| return make.hstack(ui_arena, &.{
            title_label,
            make.checkbox(ui_arena, wid, "", b, .{}),
        }, .{}),
        .number => |n| return make.hstack(ui_arena, &.{
            title_label,
            make.textInput(
                ui_arena,
                wid,
                std.fmt.allocPrint(ui_arena, "{d}", .{n}) catch "???",
                .{ .width = 90 },
            ),
        }, .{}),
        .string => |str| return make.hstack(ui_arena, &.{
            title_label,
            make.textInput(ui_arena, wid, str, .{}),
        }, .{}),
        else => {},
    };

    const value_txt: []const u8 = switch (prop.value) {
        .number => |n| std.fmt.allocPrint(ui_arena, "{d}", .{n}) catch "???",
        .boolean => |b| if (b) "true" else "false",
        .string, .assetRef => |str| str,
        .color => |c| std.fmt.allocPrint(ui_arena, "#{x:0>6}", .{c}) catch "#???????",
        .array => |arr| std.fmt.allocPrint(ui_arena, "...{d}", .{arr.len}) catch "???",
        .vector => |v| switch (v.len) {
            2 => std.fmt.allocPrint(
                ui_arena,
                "[{d}, {d}]",
                .{ v[0], v[1] },
            ) catch "[??, ??]",
            3 => std.fmt.allocPrint(
                ui_arena,
                "[{d}, {d}, {d}]",
                .{ v[0], v[1], v[2] },
            ) catch "[??, ??, ??]",
            else => "vec[???]",
        },
    };

    const value_label = make.label(ui_arena, value_txt, .{
        .color = Colors.UI_TEXT_PRIMARY,
        .font_scale = 16,
    });

    return make.hstack(ui_arena, &.{ title_label, value_label }, .{});
}

pub fn buildTree(
    ui_arena: Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const EditorState = @ptrCast(@alignCast(raw_state));

    const content: *WidgetNode = blk: {
        const entity = state.getSelectedEntity() orelse break :blk buildEmptyState(ui_arena);

        var rows: std.ArrayList(*WidgetNode) = .empty;
        rows.append(ui_arena, make.label(ui_arena, entity.name, .{
            .color = Colors.UI_TEXT_PRIMARY,
            .font_scale = 22,
        })) catch {};
        for (entity.components) |comp| {
            const comp_name = componentName(comp);
            rows.append(ui_arena, make.hdivider(ui_arena, .{ .size = 1 })) catch {};
            rows.append(ui_arena, make.label(ui_arena, comp_name, .{
                .color = Colors.UI_TEXT_INFO,
                .font_scale = 16,
            })) catch {};
            for (componentProperties(comp)) |prop| {
                rows.append(
                    ui_arena,
                    buildPropertyRow(ui_arena, entity.name, comp_name, prop),
                ) catch {};
            }
        }
        break :blk make.scrollView(
            ui_arena,
            "inspector_scroll",
            make.vstack(ui_arena, rows.items, .{ .spacing = 4 }),
            .{},
        );
    };

    return make.panel(ui_arena, content, .{
        .padding = .all(8),
        .fill = true,
    });
}
