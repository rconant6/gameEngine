const Rect = @import("../Rect.zig");
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
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

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const size: Size = switch (self.widget) {
        inline else => |*w| w.layout(li),
    };
    self.bounds = .{
        .x = li.pos.x,
        .y = li.pos.y,
        .width = size.width,
        .height = size.height,
    };
    return size;
}

pub fn render(self: *Self, ri: RenderInfo) void {
    switch (self.widget) {
        inline else => |*w| w.render(ri),
    }
}
