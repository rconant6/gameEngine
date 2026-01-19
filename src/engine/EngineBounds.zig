const Engine = @import("../engine.zig").Engine;
const core = @import("math");
const V2 = core.V2;
const renderer = @import("renderer");
const RenderContext = renderer.RenderContext;

pub fn getGameBounds(ctx: RenderContext) struct { width: f32, height: f32 } {
    const aspect = @as(f32, @floatFromInt(ctx.width)) / @as(f32, @floatFromInt(ctx.height));
    return .{
        .width = 10.0 * aspect * 2.0, // Full width
        .height = 20.0, // Full height
    };
}

pub fn getGameWidth(self: *const Engine) f32 {
    const aspect = @as(f32, @floatFromInt(self.renderer.width)) /
        @as(f32, @floatFromInt(self.renderer.height));
    return 20.0 * aspect;
}

pub fn getGameHeight(self: *const Engine) f32 {
    _ = self;
    return 20.0;
}

pub fn getTopLeft(self: *const Engine) V2 {
    return .{ .x = self.getLeftEdge(), .y = self.getTopEdge() };
}

pub fn getTopRight(self: *const Engine) V2 {
    return .{ .x = self.getRightEdge(), .y = self.getTopEdge() };
}

pub fn getBottomLeft(self: *const Engine) V2 {
    return .{ .x = self.getLeftEdge(), .y = self.getBottomEdge() };
}

pub fn getBottomRight(self: *const Engine) V2 {
    return .{ .x = self.getRightEdge(), .y = self.getBottomEdge() };
}

pub fn getCenter(self: *const Engine) V2 {
    _ = self;
    return .{ .x = 0.0, .y = 0.0 };
}

pub fn getLeftEdge(self: *const Engine) f32 {
    return -self.getGameWidth() / 2.0;
}

pub fn getRightEdge(self: *const Engine) f32 {
    return self.getGameWidth() / 2.0;
}

pub fn getTopEdge(self: *const Engine) f32 {
    _ = self;
    return 10.0;
}

pub fn getBottomEdge(self: *const Engine) f32 {
    _ = self;
    return -10.0;
}

pub fn isInBounds(self: *const Engine, point: V2) bool {
    return point.x >= self.getLeftEdge() and
        point.x <= self.getRightEdge() and
        point.y >= self.getBottomEdge() and
        point.y <= self.getTopEdge();
}

pub fn wrapPosition(self: *const Engine, point: V2) V2 {
    var wrapped = point;
    const width = self.getGameWidth();
    const left = self.getLeftEdge();
    const right = self.getRightEdge();
    const top = self.getTopEdge();
    const bottom = self.getBottomEdge();

    if (wrapped.x < left) wrapped.x += width;
    if (wrapped.x > right) wrapped.x -= width;

    if (wrapped.y < bottom) wrapped.y += 20.0;
    if (wrapped.y > top) wrapped.y -= 20.0;

    return wrapped;
}
