const l_out = @import("../layout.zig");
const Axis = l_out.Axis;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Size = l_out.Size;

const Self = @This();

axis: Axis = .vertical,
min_size: ?f32 = null,

pub fn layout(self: *Self, info: LayoutInfo) Size {
    _ = self;
    return Size.zero.constrain(info.constraints);
}

pub fn render(self: *Self, ri: RenderInfo) void {
    _ = self;
    _ = ri;
}
