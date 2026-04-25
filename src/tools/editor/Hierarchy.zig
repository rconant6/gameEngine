const std = @import("std");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const Colors = @import("renderer").Colors;
const scene_fmt = @import("scene-format");
const EditorState = @import("EditorState.zig");

const section_label_color = Colors.UI_TEXT_MUTED;
const entity_label_color = Colors.UI_TEXT_PRIMARY;
const empty_label_color = Colors.UI_TEXT_MUTED;
const font_scale: f32 = 18.0;
const section_font_scale: f32 = 14.0;

pub fn buildTree(
    arena: std.mem.Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const EditorState = @ptrCast(@alignCast(raw_state));

    const content = if (state.scene_file) |sf|
        buildSceneContent(arena, sf)
    else
        buildEmptyState(arena);

    return make.panel(arena, content, .{
        .padding = .all(8),
        .fill = true,
    });
}

fn buildEmptyState(arena: std.mem.Allocator) *WidgetNode {
    return make.vstack(arena, &.{
        make.label(arena, "No scene loaded", .{
            .color = empty_label_color,
            .font_scale = font_scale,
        }),
    }, .{ .spacing = 4 });
}

fn collectDecls(
    arena: std.mem.Allocator,
    decls: []const scene_fmt.Declaration,
    entities: *[64]*WidgetNode,
    entity_count: *usize,
    templates: *[32]*WidgetNode,
    template_count: *usize,
    assets: *[32]*WidgetNode,
    asset_count: *usize,
) void {
    for (decls) |decl| {
        switch (decl) {
            .entity => |e| {
                if (entity_count.* < entities.len) {
                    entities[entity_count.*] = make.label(arena, e.name, .{
                        .color = entity_label_color,
                        .font_scale = font_scale,
                    });
                    entity_count.* += 1;
                }
            },
            .template => |t| {
                if (template_count.* < templates.len) {
                    templates[template_count.*] = make.label(arena, t.name, .{
                        .color = entity_label_color,
                        .font_scale = font_scale,
                    });
                    template_count.* += 1;
                }
            },
            .asset => |a| {
                if (asset_count.* < assets.len) {
                    assets[asset_count.*] = make.label(arena, a.name, .{
                        .color = entity_label_color,
                        .font_scale = font_scale,
                    });
                    asset_count.* += 1;
                }
            },
            .scene => |s| collectDecls(
                arena,
                s.decls,
                entities,
                entity_count,
                templates,
                template_count,
                assets,
                asset_count,
            ),
            .component => {},
        }
    }
}

fn buildSceneContent(
    arena: std.mem.Allocator,
    sf: *const scene_fmt.SceneFile,
) *WidgetNode {
    var entities: [64]*WidgetNode = undefined;
    var entity_count: usize = 0;

    var templates: [32]*WidgetNode = undefined;
    var template_count: usize = 0;

    var assets: [32]*WidgetNode = undefined;
    var asset_count: usize = 0;

    collectDecls(
        arena,
        sf.decls,
        &entities,
        &entity_count,
        &templates,
        &template_count,
        &assets,
        &asset_count,
    );

    var sections: [8]*WidgetNode = undefined;
    var section_count: usize = 0;

    if (entity_count > 0) {
        sections[section_count] = buildSection(arena, "ENTITIES", entities[0..entity_count]);
        section_count += 1;
    }

    if (template_count > 0) {
        sections[section_count] = buildSection(arena, "TEMPLATES", templates[0..template_count]);
        section_count += 1;
    }

    if (asset_count > 0) {
        sections[section_count] = buildSection(arena, "ASSETS", assets[0..asset_count]);
        section_count += 1;
    }

    if (section_count == 0) {
        return buildEmptyState(arena);
    }

    return make.vstack(arena, sections[0..section_count], .{ .spacing = 12 });
}

fn buildSection(
    arena: std.mem.Allocator,
    title: []const u8,
    items: []*WidgetNode,
) *WidgetNode {

    // header + divider + N items
    const child_count = 2 + items.len;
    const children = arena.alloc(*WidgetNode, child_count) catch @panic("UI: out of memory");

    children[0] = make.label(arena, title, .{
        .color = section_label_color,
        .font_scale = section_font_scale,
    });
    children[1] = make.hdivider(arena, .{ .size = 1 });
    for (items, 0..) |item, i| {
        children[2 + i] = item;
    }

    return make.vstack(arena, children, .{ .spacing = 4 });
}
