const std = @import("std");
const Allocator = std.mem.Allocator;
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const Colors = @import("renderer").Colors;
const scene_fmt = @import("scene-format");
const EditorState = @import("EditorState.zig");
const EntityRef = EditorState.EntityRef;

const section_label_color = Colors.UI_TEXT_MUTED;
const empty_label_color = Colors.UI_TEXT_MUTED;
const font_scale: f32 = 18.0;
const section_font_scale: f32 = 14.0;

const item_colors: ui.ListItem.ListItemColors = .{
    .normal = Colors.UI_PANEL_BG,
    .hovered = Colors.UI_BUTTON_HOVER,
    .selected = Colors.UI_BUTTON_PRESSED,
    .text = Colors.UI_TEXT_PRIMARY,
    .text_selected = Colors.WHITE,
};

var g_state: *EditorState = undefined;
pub fn setState(state: *EditorState) void {
    g_state = state;
}

pub fn buildTree(
    arena: Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const EditorState = @ptrCast(@alignCast(raw_state));

    const content = if (state.scene_file) |sf|
        buildSceneContent(arena, sf, state.selected)
    else
        buildEmptyState(arena);

    return make.panel(arena, content, .{
        .padding = .all(8),
        .fill = true,
    });
}

fn buildEmptyState(arena: Allocator) *WidgetNode {
    return make.vstack(arena, &.{
        make.label(arena, "No scene loaded", .{
            .color = empty_label_color,
            .font_scale = font_scale,
        }),
    }, .{ .spacing = 4 });
}

fn isSelected(scene_name: ?[]const u8, entity_name: []const u8, selected: ?EntityRef) bool {
    const ref = selected orelse return false;
    const scene_match = if (ref.scene_name) |rsn|
        if (scene_name) |sn| std.mem.eql(u8, rsn, sn) else false
    else
        scene_name == null;
    return scene_match and std.mem.eql(u8, ref.entity_name, entity_name);
}

// Collects entity and scene widgets only (assets/templates handled separately).
fn collectDecls(
    arena: Allocator,
    decls: []const scene_fmt.Declaration,
    scene_name: ?[]const u8,
    indent: u8,
    selected: ?EntityRef,
    out: []*WidgetNode,
    out_count: *usize,
) void {
    for (decls) |decl| {
        switch (decl) {
            .entity => |e| {
                if (out_count.* >= out.len) return;
                const id = std.fmt.allocPrint(
                    arena,
                    "e:{s}:{s}",
                    .{ scene_name orelse "", e.name },
                ) catch @panic("Hierarchy: out of memory");
                out[out_count.*] = make.listItem(arena, id, e.name, .{
                    .colors = item_colors,
                    .indent = indent,
                    .selected = isSelected(scene_name, e.name, selected),
                    .font_scale = font_scale,
                });
                out_count.* += 1;
            },
            .scene => |s| {
                if (out_count.* >= out.len) return;
                out[out_count.*] = make.label(arena, s.name, .{
                    .color = section_label_color,
                    .font_scale = section_font_scale,
                });
                out_count.* += 1;
                collectDecls(arena, s.decls, s.name, indent + 1, selected, out, out_count);
            },
            .asset, .template, .component => {},
        }
    }
}

fn buildSection(arena: Allocator, title: []const u8, items: []*WidgetNode, out: []*WidgetNode, out_count: *usize) void {
    if (out_count.* + 2 + items.len > out.len) return;
    out[out_count.*] = make.label(arena, title, .{ .color = section_label_color, .font_scale = section_font_scale });
    out_count.* += 1;
    out[out_count.*] = make.hdivider(arena, .{ .size = 1 });
    out_count.* += 1;
    for (items) |item| {
        out[out_count.*] = item;
        out_count.* += 1;
    }
}

fn buildSceneContent(
    arena: Allocator,
    sf: *const scene_fmt.SceneFile,
    selected: ?EntityRef,
) *WidgetNode {
    // Collect assets and templates first
    var asset_nodes: [32]*WidgetNode = undefined;
    var asset_count: usize = 0;
    var template_nodes: [32]*WidgetNode = undefined;
    var template_count: usize = 0;

    for (sf.decls) |decl| {
        switch (decl) {
            .asset => |a| {
                if (asset_count < asset_nodes.len) {
                    asset_nodes[asset_count] = make.label(arena, a.name, .{
                        .color = section_label_color,
                        .font_scale = font_scale,
                    });
                    asset_count += 1;
                }
            },
            .template => |t| {
                if (template_count < template_nodes.len) {
                    template_nodes[template_count] = make.label(arena, t.name, .{
                        .color = section_label_color,
                        .font_scale = font_scale,
                    });
                    template_count += 1;
                }
            },
            else => {},
        }
    }

    var items: [128]*WidgetNode = undefined;
    var item_count: usize = 0;

    if (asset_count > 0)
        buildSection(arena, "ASSETS", asset_nodes[0..asset_count], &items, &item_count);
    if (template_count > 0)
        buildSection(arena, "TEMPLATES", template_nodes[0..template_count], &items, &item_count);

    // Entities/scenes
    if (asset_count > 0 or template_count > 0) {
        // divider before entities
        if (item_count < items.len) {
            items[item_count] = make.hdivider(arena, .{ .size = 1 });
            item_count += 1;
        }
    }
    collectDecls(arena, sf.decls, null, 0, selected, &items, &item_count);

    if (item_count == 0) return buildEmptyState(arena);

    return make.vstack(arena, items[0..item_count], .{ .spacing = 2 });
}
