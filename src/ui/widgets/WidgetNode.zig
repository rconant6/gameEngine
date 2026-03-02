const Rect = @import("../Rect.zig");
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const Size = l_out.Size;
const widgets = @import("widget_registry.zig");
const WidgetData = widgets.WidgetData;
const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const assets = @import("assets");
const Font = assets.Font;

const Self = @This();

widget: WidgetData,
bounds: Rect,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    const size: Size = switch (self.widget) {
        inline else => |*w| w.layout(constraints, origin_x, origin_y),
    };
    self.bounds = .{
        .x = origin_x,
        .y = origin_y,
        .width = size.width,
        .height = size.height,
    };

    return size;
}

pub fn render(self: *const Self, renderer: *Renderer, font: *const Font, ctx: RenderContext) void {
    switch (self.widget) {
        inline else => |*w| w.render(renderer, font, self.bounds, ctx),
    }
}
