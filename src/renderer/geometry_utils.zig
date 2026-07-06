const core = @import("math");
const WorldPoint = core.WorldPoint;
const V2 = core.V2;
const RenderContext = @import("../renderer/RenderContext.zig");

pub const Transform = struct {
    offset: ?WorldPoint = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
};

pub const ScreenAnchor = enum {
    TopLeft,
    TopCenter,
    TopRight,
    BottomLeft,
    BottomCenter,
    BottomRight,
    MiddleLeft,
    MiddleCenter,
    MiddleRight,
};
pub fn getAnchorPosition(anchor: ScreenAnchor, ctx: RenderContext) V2 {
    const f_width: f32 = @floatFromInt(ctx.width);
    const f_height: f32 = @floatFromInt(ctx.height);
    return switch (anchor) {
        .TopLeft => .{ .x = 0, .y = 0 },
        .TopCenter => .{ .x = f_width / 2, .y = 0 },
        .TopRight => .{ .x = f_width, .y = 0 },
        .BottomLeft => .{ .x = 0, .y = f_height },
        .BottomCenter => .{ .x = f_width / 2, .y = f_height },
        .BottomRight => .{ .x = f_width, .y = f_height },
        .MiddleLeft => .{ .x = 0, .y = f_height / 2 },
        .MiddleCenter => .{ .x = f_width / 2, .y = f_height / 2 },
        .MiddleRight => .{ .x = f_width, .y = f_height / 2 },
    };
}
