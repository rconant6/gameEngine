const std = @import("std");
const types = @import("core");
const Color = @import("../renderer/color.zig").Color;
const GamePoint = types.GamePoint;
const ScreenPoint = types.ScreenPoint;
const RenderContext = @import("../renderer/RenderContext.zig");

pub const Transform = struct {
    offset: ?GamePoint = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
};

pub fn scalePt(point: GamePoint, scale: f32) GamePoint {
    return .{ .x = point.x * scale, .y = point.y * scale };
}

pub fn rotatePt(point: GamePoint, rot: f32) GamePoint {
    const cos_r = std.math.cos(rot);
    const sin_r = std.math.sin(rot);
    const oldX = point.x;

    return .{
        .x = oldX * cos_r - point.y * sin_r,
        .y = oldX * sin_r + point.y * cos_r,
    };
}

pub fn movePt(point: GamePoint, pos: GamePoint) GamePoint {
    return .{
        .x = point.x + pos.x,
        .y = point.y + pos.y,
    };
}

pub fn transformPoint(point: GamePoint, transform: Transform) GamePoint {
    var result = point;

    if (transform.scale) |s| result = scalePt(result, s);

    if (transform.rotation) |rot| result = rotatePt(result, rot);

    if (transform.offset) |pos| result = movePt(result, pos);

    return result;
}

pub fn gameToScreen(point: GamePoint, ctx: RenderContext) ScreenPoint {
    const fw: f32 = @floatFromInt(ctx.width);
    const fh: f32 = @floatFromInt(ctx.height);

    const x: i32 = @intFromFloat((point.x + 10.0) * 0.05 * fw);
    const y: i32 = @intFromFloat((10.0 - point.y) * 0.05 * fh);

    return .{ .x = x, .y = y };
}

pub fn gameToScreenF32(point: GamePoint, ctx: RenderContext) [2]f32 {
    const fw: f32 = @floatFromInt(ctx.width);
    const fh: f32 = @floatFromInt(ctx.height);

    const x: f32 = (point.x + 10.0) * 0.05 * fw;
    const y: f32 = (10.0 - point.y) * 0.05 * fh;

    return .{ x, y };
}

pub fn screenToGame(screen: ScreenPoint, ctx: RenderContext) GamePoint {
    const fw: f32 = @floatFromInt(ctx.width);
    const fh: f32 = @floatFromInt(ctx.height);

    const fx: f32 = @floatFromInt(screen.x);
    const fy: f32 = @floatFromInt(screen.y);

    return .{
        .x = (fx * 20.0 / fw) - 10.0,
        .y = 10.0 - (fy * 20.0 / fh),
    };
}

pub fn screenToClip(screen_x: f32, screen_y: f32, ctx: *const RenderContext) [2]f32 {
    const x_clip = (screen_x / ctx.width) * 2.0 - 1.0;
    const y_clip = (screen_y / ctx.height) * 2.0 - 1.0;

    return .{ x_clip, y_clip };
}

pub fn toClip(point: GamePoint, ctx: *const RenderContext) [2]f32 {
    return ctx.screenToClip(point.x, point.y);
}

pub fn colorToFloat(color: Color) [4]f32 {
    const r: f32 = @floatFromInt(color.r);
    const g: f32 = @floatFromInt(color.g);
    const b: f32 = @floatFromInt(color.b);
    const a: f32 = @floatFromInt(color.a);

    return .{ r / 255.0, g / 255.0, b / 255.0, a / 255.0 };
}
