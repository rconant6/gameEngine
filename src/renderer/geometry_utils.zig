const std = @import("std");
const core = @import("math");
const Color = @import("../renderer/color.zig").Color;
const WorldPoint = core.WorldPoint;
const ScreenPoint = core.ScreenPoint;
const WorldBounds = core.WorldBounds;
const V2 = core.V2;
const RenderContext = @import("../renderer/RenderContext.zig");

pub const Transform = struct {
    offset: ?WorldPoint = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
};

pub fn scalePt(point: WorldPoint, scale: f32) WorldPoint {
    return .{ .x = point.x * scale, .y = point.y * scale };
}

pub fn rotatePt(point: WorldPoint, rot: f32) WorldPoint {
    const cos_r = std.math.cos(rot);
    const sin_r = std.math.sin(rot);
    const oldX = point.x;

    return .{
        .x = oldX * cos_r - point.y * sin_r,
        .y = oldX * sin_r + point.y * cos_r,
    };
}

pub fn movePt(point: WorldPoint, pos: WorldPoint) WorldPoint {
    return .{
        .x = point.x + pos.x,
        .y = point.y + pos.y,
    };
}

pub fn transformPoint(point: WorldPoint, transform: Transform) WorldPoint {
    var result = point;

    if (transform.scale) |s| result = scalePt(result, s);

    if (transform.rotation) |rot| result = rotatePt(result, rot);

    if (transform.offset) |pos| result = movePt(result, pos);

    return result;
}

/// Converts a world position to screen pixel coordinates (f32).
/// Accounts for camera position and zoom.
/// Useful for positioning UI elements relative to world objects.
pub fn worldToScreen(point: WorldPoint, ctx: RenderContext) V2 {
    const fw: f32 = @floatFromInt(ctx.width);
    const fh: f32 = @floatFromInt(ctx.height);
    const aspect = fw / fh;

    const relative_x = point.x - ctx.camera_loc.x;
    const relative_y = point.y - ctx.camera_loc.y;

    const clip_x = relative_x / (ctx.ortho_size * aspect);
    const clip_y = relative_y / ctx.ortho_size;

    const screen_x = (clip_x + 1.0) * fw / 2.0;
    const screen_y = (1.0 - clip_y) * fh / 2.0;

    return .{ .x = screen_x, .y = screen_y };
}

/// Converts a world position to screen pixel coordinates (i32).
/// Integer wrapper around worldToScreen for convenience.
pub fn worldToScreenInt(point: WorldPoint, ctx: RenderContext) ScreenPoint {
    const f = worldToScreen(point, ctx);
    return .{ .x = @intFromFloat(f.x), .y = @intFromFloat(f.y) };
}

/// Converts screen pixel coordinates to world position.
/// Accounts for camera position and zoom.
/// Useful for mouse picking: click on screen, get world position.
pub fn screenToWorld(screen: ScreenPoint, ctx: RenderContext) WorldPoint {
    const fw: f32 = @floatFromInt(ctx.width);
    const fh: f32 = @floatFromInt(ctx.height);
    const fx: f32 = @floatFromInt(screen.x);
    const fy: f32 = @floatFromInt(screen.y);
    const aspect = fw / fh;

    const clip_x = (fx / fw) * 2.0 - 1.0;
    const clip_y = 1.0 - (fy / fh) * 2.0;

    const relative_x = clip_x * (ctx.ortho_size * aspect);
    const relative_y = clip_y * ctx.ortho_size;

    const world_x = relative_x + ctx.camera_loc.x;
    const world_y = relative_y + ctx.camera_loc.y;

    return .{ .x = world_x, .y = world_y };
}

/// Converts screen pixel coordinates to clip space [-1, 1].
/// Used for UI rendering (screen space, camera-independent).
pub fn screenToClipSpace(screen: ScreenPoint, ctx: RenderContext) [2]f32 {
    const fw: f32 = @floatFromInt(ctx.width);
    const fh: f32 = @floatFromInt(ctx.height);
    const fx: f32 = @floatFromInt(screen.x);
    const fy: f32 = @floatFromInt(screen.y);

    const clip_x = (fx / fw) * 2.0 - 1.0;
    const clip_y = 1.0 - (fy / fh) * 2.0;

    return .{ clip_x, clip_y };
}

pub fn worldToClipSpace(point: WorldPoint, ctx: RenderContext) [2]f32 {
    const aspect = ctx.aspectRatio();

    const relative_x = point.x - ctx.camera_loc.x;
    const relative_y = point.y - ctx.camera_loc.y;

    const clip_x = relative_x / (ctx.ortho_size * aspect);
    const clip_y = relative_y / ctx.ortho_size;

    return .{ clip_x, clip_y };
}

pub fn colorToFloat(color: Color) [4]f32 {
    const r: f32 = @floatFromInt(color.r);
    const g: f32 = @floatFromInt(color.g);
    const b: f32 = @floatFromInt(color.b);
    const a: f32 = @floatFromInt(color.a);

    return .{ r / 255.0, g / 255.0, b / 255.0, a / 255.0 };
}
