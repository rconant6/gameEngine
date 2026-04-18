const std = @import("std");
const Allocator = std.mem.Allocator;
const assets = @import("assets");
const Font = assets.Font;
const V2 = @import("math").V2;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const log = @import("debug").log;
const WidgetNode = @import("widgets/WidgetNode.zig");
const Registry = @import("widgets/widget_registry.zig");
const Rect = @import("Rect.zig");
const widgets = @import("widgets/widgets.zig");
const Button = widgets.Button;
const Chicklet = widgets.Chicklet;
const ColorRect = widgets.ColorRect;
const Divider = widgets.Divider;
const Grid = widgets.Grid;
const HStack = widgets.HStack;
const Label = widgets.Label;
const Panel = widgets.Panel;
const Slider = widgets.Slider;
const Spacer = widgets.Spacer;
const VStack = widgets.VStack;
const TextBlock = @import("TextBlock.zig");
const lo = @import("layout.zig");
const Size = lo.Size;
const EdgeInsets = lo.EdgeInsets;
const Alignment = @import("alignment.zig").Alignment;

fn alloc(gpa: Allocator, widget_data: anytype) *WidgetNode {
    const node = gpa.create(WidgetNode) catch |err| {
        log.fatal(.ui, "Unable to create widget: {any}", .{err});
        @panic("UI: out of memory");
    };

    node.* = .{
        .widget = Registry.WidgetRegistry.createWidgetUnion(
            @TypeOf(widget_data),
            widget_data,
        ),
        .bounds = .zero,
    };

    return node;
}

const LabelOpts = struct {
    font: ?*Font = null,
    font_scale: f32 = 24.0,
    color: Color = Colors.WHITE,
};

pub fn label(gpa: Allocator, text: []const u8, opts: LabelOpts) *WidgetNode {
    const raw_size: V2 = if (opts.font) |f| f.measureText(
        text,
        opts.font_scale,
    ) else .{ .x = 0, .y = 0 };

    const size: Size = .{ .width = raw_size.x, .height = raw_size.y };
    return alloc(gpa, Label{
        .tb = .{
            .text = text,
            .font = opts.font,
            .font_scale = opts.font_scale,
            .cached_size = size,
        },
        .color = opts.color,
    });
}

const PanelOpts = struct {
    background: Color = Colors.CHARCOAL,
    border_color: Color = Colors.WHITE,
    border_width: f32 = 1,
    padding: EdgeInsets = .all(0),
};
pub fn panel(gpa: Allocator, child: *WidgetNode, opts: PanelOpts) *WidgetNode {
    return alloc(gpa, Panel{
        .background = opts.background,
        .border_color = opts.border_color,
        .border_width = opts.border_width,
        .padding = opts.padding,
        .child = child,
    });
}

// ── HStack ──

pub const HStackOpts = struct {
    spacing: f32 = 10,
    cross_axis: Alignment.Vertical = .center,
};

pub fn hstack(gpa: Allocator, children: []const *WidgetNode, opts: HStackOpts) *WidgetNode {
    const nodes = allocChildren(gpa, children);
    return alloc(gpa, HStack{
        .children = nodes,
        .spacing = opts.spacing,
        .cross_axis = opts.cross_axis,
    });
}

// ── VStack ──

pub const VStackOpts = struct {
    spacing: f32 = 6,
    cross_axis: Alignment.Horizontal = .start,
};

pub fn vstack(gpa: Allocator, children: []const *WidgetNode, opts: VStackOpts) *WidgetNode {
    const nodes = allocChildren(gpa, children);
    return alloc(gpa, VStack{
        .children = nodes,
        .spacing = opts.spacing,
        .cross_axis = opts.cross_axis,
    });
}

// ── ColorRect ──

pub const ColorRectOpts = struct {
    border_color: ?Color = null,
    border_width: f32 = 0,
};

pub fn colorRect(gpa: Allocator, color: Color, opts: ColorRectOpts) *WidgetNode {
    return alloc(gpa, ColorRect{
        .color = color,
        .border_color = opts.border_color,
        .border_width = opts.border_width,
    });
}

// ── Chicklet ──

pub const ChickletOpts = struct {
    colors: Chicklet.ChickletColors = .{
        .not_selected = Colors.UI_BUTTON_NORMAL,
        .selected = Colors.UI_BUTTON_PRESSED,
    },
    size: V2 = .{ .x = 24, .y = 24 },
    is_selected: bool = false,
    on_click: ?*const fn () void = null,
};

pub fn chicklet(gpa: Allocator, name: []const u8, opts: ChickletOpts) *WidgetNode {
    return alloc(gpa, Chicklet{
        .colors = opts.colors,
        .id = name,
        .selected = opts.is_selected,
        .on_click = opts.on_click,
        .size = opts.size,
    });
}

// ── Button ──

pub const ButtonOpts = struct {
    colors: Button.ButtonColors = .{
        .normal = Colors.UI_BUTTON_NORMAL,
        .hovered = Colors.UI_BUTTON_HOVER,
        .pressed = Colors.UI_BUTTON_PRESSED,
        .text = Colors.UI_BUTTON_TEXT,
    },
    font_scale: f32 = 24.0,
    on_click: ?*const fn () void = null,
};

pub fn button(
    gpa: Allocator,
    id: []const u8,
    text: []const u8,
    opts: ButtonOpts,
) *WidgetNode {
    return alloc(gpa, Button{
        .id = id,
        .text_info = .{
            .text = text,
            .font_scale = opts.font_scale,
        },
        .colors = opts.colors,
        .on_click = opts.on_click,
    });
}

// ── Slider ──

pub const SliderOpts = struct {
    min: f32 = 0.0,
    max: f32 = 1.0,
    track_color: Color = Colors.CHARCOAL,
    fill_color: Color = Colors.WHITE,
    thumb_color: Color = Colors.WHITE,
};

pub fn slider(gpa: Allocator, id: []const u8, opts: SliderOpts) *WidgetNode {
    return alloc(gpa, Slider{
        .id = id,
        .min = opts.min,
        .max = opts.max,
        .track_color = opts.track_color,
        .fill_color = opts.fill_color,
        .thumb_color = opts.thumb_color,
    });
}

// ── Divider ──

pub const DividerOpts = struct {
    size: f32 = 2,
    color: Color = Colors.CHARCOAL,
};

pub fn divider(gpa: Allocator, opts: DividerOpts) *WidgetNode {
    return alloc(gpa, Divider{
        .size = opts.size,
        .color = opts.color,
    });
}

// ── Spacer ──

pub fn spacer(gpa: Allocator, min_size: ?f32) *WidgetNode {
    return alloc(gpa, Spacer{
        .min_size = min_size,
    });
}

// ── Grid ──

pub const GridOpts = struct {
    columns: u8 = 4,
    h_spacing: f32 = 4,
    v_spacing: f32 = 4,
};

pub fn grid(gpa: Allocator, children: []const *WidgetNode, opts: GridOpts) *WidgetNode {
    const nodes = allocChildren(gpa, children);
    return alloc(gpa, Grid{
        .children = nodes,
        .columns = opts.columns,
        .h_spacing = opts.h_spacing,
        .v_spacing = opts.v_spacing,
    });
}

// ── Internal helpers ──

fn allocChildren(gpa: Allocator, children: []const *WidgetNode) []WidgetNode {
    const nodes = gpa.alloc(WidgetNode, children.len) catch |err| {
        log.fatal(.ui, "Unable to allocate children: {any}", .{err});
        @panic("UI: out of memory");
    };
    for (children, 0..) |child_ptr, i| {
        nodes[i] = child_ptr.*;
    }
    return nodes;
}
