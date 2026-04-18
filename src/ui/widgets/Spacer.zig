const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const Colors = rend.Colors;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const WidgetNode = @import("WidgetNode.zig");

const Self = @This();

min_size: ?f32,

pub fn layout(
    self: *Self,
    info: LayoutInfo,
) Size {
    _ = self;
    const size: Size = .{ .width = 0, .height = 0 };
    return size.constrain(info.constraints);
}

pub fn render(self: *Self, ri: RenderInfo) void {
    _ = self;
    _ = ri;
    return;
}
