// ============================================================================
// CPU RENDERER - CURRENTLY DISABLED
// ============================================================================
// This renderer has been disabled to focus development on GPU rendering.
// The code is kept for reference and potential future re-enabling.
//
// Issues that prevented continued support:
// - Different coordinate system (i32 ScreenPoint vs float clip space)
// - Manual software rasterization for all primitives
// - Integer overflow issues with font rendering (see geometry_utils.zig)
// - Maintenance burden of keeping in sync with Metal renderer changes
//
// To re-enable:
// 1. Remove the check in build.zig (line ~25)
// 2. Uncomment CpuRenderer import in renderer.zig (line ~26)
// 3. Uncomment BackendImpl switch case in renderer.zig (line ~56)
// 4. Fix any compilation errors from API changes
// ============================================================================

const std = @import("std");
const RenderConfig = @import("../../renderer/renderer.zig").RendererConfig;
const Circle = shapes.Circle;
const Color = @import("../color.zig").Color;
const Ellipse = shapes.Ellipse;
const Line = shapes.Line;
const Polygon = shapes.Polygon;
const Rectangle = shapes.Rectangle;
const Triangle = shapes.Triangle;
const core = @import("core");
const ShapeData = core.ShapeData;
const shapes = core.Shapes;
const GamePoint = core.GamePoint;
const ScreenPoint = core.ScreenPoint;
const utils = @import("../../renderer/geometry_utils.zig");
const Transform = utils.Transform;
const FrameBuffer = @import("../cpu/frameBuffer.zig").FrameBuffer;
const RenderContext = @import("../RenderContext.zig");

const CpuRenderer = @This();

frame_buffer: FrameBuffer,
width: u32,
height: u32,
fw: f32,
fh: f32,
allocator: std.mem.Allocator,
clear_color: Color,

pub fn init(allocator: std.mem.Allocator, config: RenderConfig) !CpuRenderer {
    const frame_buffer = try FrameBuffer.init(
        allocator,
        config.width,
        config.height,
    );

    return CpuRenderer{
        .frame_buffer = frame_buffer,
        .width = config.width,
        .height = config.height,
        .fw = @floatFromInt(config.width),
        .fh = @floatFromInt(config.height),
        .allocator = allocator,
        .clear_color = Color.init(0, 0, 0, 1),
    };
}
pub fn deinit(self: *CpuRenderer) void {
    self.frame_buffer.deinit();
}

pub fn beginFrame(self: *CpuRenderer) !void {
    self.frame_buffer.clear(self.clear_color);
}

pub fn endFrame(self: *CpuRenderer) !void {
    self.frame_buffer.rotateBuffers();
}

pub fn clear(self: *CpuRenderer) void {
    self.frame_buffer.clear(self.clear_color);
}

pub fn setClearColor(self: *CpuRenderer, color: Color) void {
    self.clear_color = color;
}

pub fn getRawFrameBuffer(self: *const CpuRenderer) []const Color {
    return self.frame_buffer.bufferMemory;
}

pub fn getDisplayBufferOffset(self: *const CpuRenderer) u32 {
    return self.frame_buffer.getDisplayBufferOffset();
}

pub fn gameToScreen(renderer: *const CpuRenderer, p: GamePoint) ScreenPoint {
    const ctx = RenderContext{ .width = renderer.width, .height = renderer.height };
    return utils.gameToScreen(p, ctx);
}

pub fn screenToGame(renderer: *const CpuRenderer, sp: ScreenPoint) GamePoint {
    const ctx = RenderContext{ .width = renderer.width, .height = renderer.height };
    return utils.screenToGame(sp, ctx);
}

pub fn drawShape(
    self: *CpuRenderer,
    shape: ShapeData,
    transform: ?Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    if (transform) |xform| {
        switch (shape) {
            .Circle => |circle| {
                self.drawCircleWithTransform(
                    circle,
                    xform,
                    fill_color,
                    stroke_color,
                    stroke_width,
                );
            },
            .Ellipse => |ellipse| {
                _ = ellipse;
                std.debug.panic("Ellipse has not been implemented yet!!\n", .{});
            },
            .Line => |line| {
                self.drawLineWithTransform(
                    line,
                    xform,
                    stroke_color,
                    stroke_width,
                );
            },
            .Rectangle => |rect| {
                self.drawRectangleWithTransform(
                    rect,
                    xform,
                    fill_color,
                    stroke_color,
                    stroke_width,
                );
            },
            .Triangle => |tri| {
                self.drawTriangleWithTransform(
                    tri,
                    xform,
                    fill_color,
                    stroke_color,
                    stroke_width,
                );
            },
            .Polygon => |poly| {
                self.drawPolygonWithTransform(
                    poly,
                    xform,
                    fill_color,
                    stroke_color,
                    stroke_width,
                );
            },
        }
    } else {
        switch (shape) {
            .Circle => |circle| {
                self.drawCircle(circle, fill_color, stroke_color, stroke_width);
            },
            .Ellipse => |ellipse| {
                _ = ellipse;
                std.debug.panic("TODO: Ellipse has not been implemented yet!!\n", .{});
            },
            .Line => |line| {
                self.drawLine(line.start, line.end, stroke_color, stroke_width);
            },
            .Rectangle => |rect| {
                self.drawRectangle(rect, null, fill_color, stroke_color, stroke_width);
            },
            .Triangle => |tri| {
                self.drawTriangle(tri, null, fill_color, stroke_color, stroke_width);
            },
            .Polygon => |poly| {
                self.drawPolygon(poly, null, fill_color, stroke_color, stroke_width);
            },
        }
    }
}

fn drawOutlineWithTransform(
    renderer: *CpuRenderer,
    pts: []const GamePoint,
    transform: ?Transform,
    color: Color,
    stroke_width: f32,
) void {
    if (transform) |xform| {
        const len = pts.len;
        switch (len) {
            0 => return,
            1 => drawPoint(renderer, utils.transformPoint(pts[0], xform), color),
            2 => drawLineWithTransform(
                renderer,
                Line{ .start = pts[0], .end = pts[1] },
                xform,
                color,
                stroke_width,
            ),
            else => {
                // draw them all
                for (0..len) |i| {
                    const start = pts[i];
                    const end = pts[(i + 1) % len];
                    drawLineWithTransform(
                        renderer,
                        Line{ .start = start, .end = end },
                        xform,
                        color,
                        stroke_width,
                    );
                }
            },
        }
    } else {
        drawOutline(renderer, pts, color, stroke_width);
    }
}

fn drawOutline(
    renderer: *CpuRenderer,
    pts: []const GamePoint,
    color: Color,
    stroke_width: f32,
) void {
    const len = pts.len;
    switch (len) {
        0 => return,
        1 => drawPoint(renderer, pts[0], color),
        2 => drawLine(renderer, pts[0], pts[1], color, stroke_width),
        else => {
            // draw them all
            for (0..len) |i| {
                const start = pts[i];
                const end = pts[(i + 1) % len];
                drawLine(renderer, start, end, color, stroke_width);
            }
        },
    }
}

// MARK: Point
fn drawPoint(renderer: *CpuRenderer, point: GamePoint, color: ?Color) void {
    const c = if (color != null) color.? else return;

    const screenPos = renderer.gameToScreen(point);

    if (screenPos.x < 0 or screenPos.x >= renderer.width or
        screenPos.y < 0 or screenPos.y >= renderer.height)
        return;

    renderer.frame_buffer.setPixel(@intCast(screenPos.x), @intCast(screenPos.y), c);
}

// MARK: Lines
fn drawLineWithTransform(
    renderer: *CpuRenderer,
    line: Line,
    xform: Transform,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    const start = utils.transformPoint(line.start, xform);
    const end = utils.transformPoint(line.end, xform);
    renderer.drawLine(start, end, stroke_color, stroke_width);
}

fn drawLine(
    renderer: *CpuRenderer,
    start: GamePoint,
    end: GamePoint,
    color: ?Color,
    stroke_width: f32,
) void {
    _ = stroke_width;
    const c = if (color != null) color.? else return;

    const screenStart = renderer.gameToScreen(start);
    const screenEnd = renderer.gameToScreen(end);

    if (screenStart.eql(screenEnd)) return drawPoint(renderer, start, c);
    var x = screenStart.x;
    var y = screenStart.y;
    const endX = screenEnd.x;
    const endY = screenEnd.y;

    var dx = screenEnd.x - screenStart.x;
    var dy = screenEnd.y - screenStart.y;

    const stepX: i32 = if (dx < 0) -1 else 1;
    const stepY: i32 = if (dy < 0) -1 else 1;

    dx = @intCast(@abs(dx));
    dy = @intCast(@abs(dy));

    if (dx == 0) {
        // Handle vertical case
        while (y != endY) : (y += stepY) {
            renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), c);
        }
    } else if (dy == 0) {
        // Handle horizontal case
        while (x != endX) : (x += stepX) {
            renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), c);
        }
    } else if (dx == dy) {
        // Handle diagonal case
        while (x != endX) {
            renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), c);
            x += stepX;
            y += stepY;
        }
    } else {
        // Standard Bresenham algorithm with proper handling of directions
        var err: i32 = 0;

        if (dx > dy) {
            err = @divFloor(dx, 2);

            while (x != endX + stepX) {
                if (x >= 0 and x < renderer.width and y >= 0 and y < renderer.height) {
                    renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), c);
                }

                err -= dy;
                if (err < 0) {
                    y += stepY;
                    err += dx;
                }

                x += stepX;
            }
        } else {
            err = @divFloor(dy, 2);

            while (y != endY + stepY) {
                if (x >= 0 and x < renderer.width and y >= 0 and y < renderer.height) {
                    renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), c);
                }

                err -= dx;
                if (err < 0) {
                    x += stepX;
                    err += dy;
                }

                y += stepY;
            }
        }
    }
}

// MARK: Circle drawing
fn drawCircleWithTransform(
    renderer: *CpuRenderer,
    circle: Circle,
    xform: Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    const newOrigin = utils.transformPoint(circle.origin, xform);
    const newRadius = if (xform.scale) |scale| circle.radius * scale else circle.radius;
    const newCircle = Circle{
        .origin = newOrigin,
        .radius = newRadius,
    };
    drawCircle(renderer, newCircle, fill_color, stroke_color, stroke_width);
}

fn drawCircle(
    renderer: *CpuRenderer,
    circle: Circle,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    if (fill_color) |fc| {
        drawCircleFilled(renderer, circle, fc, stroke_width);
    }
    if (stroke_color) |oc| {
        drawCircleOutline(renderer, circle, oc, stroke_width);
    }
}

fn drawHorizontalScanLineF32(renderer: *CpuRenderer, y: f32, startx: f32, endx: f32, color: Color) void {
    const start = renderer.gameToScreenCoordsFromPoint(startx, y);
    const end = renderer.gameToScreenFromXY(endx, y);

    renderer.drawHorizontalScanLineInt(start.y, start.x, end.x, color);
}

fn drawHorizontalScanLineInt(renderer: *CpuRenderer, y: i32, startx: i32, endx: i32, color: Color) void {
    if (y < 0 or y >= renderer.height) return;

    const clippedStart = @max(0, startx);
    const clippedEnd = @min(renderer.width - 1, endx);

    var x = clippedStart;
    while (x <= clippedEnd) : (x += 1) {
        renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), color);
    }
}

fn drawCircleFilled(
    renderer: *CpuRenderer,
    circle: Circle,
    color: Color,
    stroke_width: f32,
) void {
    _ = stroke_width;
    const center = renderer.gameToScreen(circle.origin);
    const edge: GamePoint = .{ .x = circle.origin.x + circle.radius, .y = circle.origin.y };
    const edgeScreen = renderer.gameToScreen(edge);
    const screenRadius: i32 = edgeScreen.x - center.x;

    var x: i32 = 0;
    var y: i32 = screenRadius;
    var d: i32 = 1 - screenRadius;

    drawHorizontalScanLineInt(renderer, center.y, center.x - screenRadius, center.x + screenRadius, color);

    while (x <= y) {
        if (d < 0) {
            d += 2 * x + 3;
        } else {
            d += 2 * (x - y) + 5;
            y -= 1;
        }
        x += 1;
        drawHorizontalScanLineInt(renderer, center.y + y, center.x - x, center.x + x, color);
        drawHorizontalScanLineInt(renderer, center.y - y, center.x - x, center.x + x, color);
        drawHorizontalScanLineInt(renderer, center.y + x, center.x - y, center.x + y, color);
        drawHorizontalScanLineInt(renderer, center.y - x, center.x - y, center.x + y, color);
    }
}

inline fn plotCirclePoint(renderer: *CpuRenderer, x: i32, y: i32, color: Color) void {
    if (x >= 0 and x < renderer.width and y >= 0 and y < renderer.height) {
        renderer.frame_buffer.setPixel(@intCast(x), @intCast(y), color);
    }
}

fn plotCirclePoints(renderer: *CpuRenderer, center: ScreenPoint, x: i32, y: i32, color: Color) void {
    plotCirclePoint(renderer, center.x + x, center.y + y, color);
    plotCirclePoint(renderer, center.x - x, center.y + y, color);
    plotCirclePoint(renderer, center.x + x, center.y - y, color);
    plotCirclePoint(renderer, center.x - x, center.y - y, color);
    plotCirclePoint(renderer, center.x + y, center.y + x, color);
    plotCirclePoint(renderer, center.x - y, center.y + x, color);
    plotCirclePoint(renderer, center.x + y, center.y - x, color);
    plotCirclePoint(renderer, center.x - y, center.y - x, color);
}

fn drawCircleOutline(
    renderer: *CpuRenderer,
    circle: Circle,
    color: Color,
    stroke_width: f32,
) void {
    _ = stroke_width;
    const center = renderer.gameToScreen(circle.origin);
    const edge: GamePoint = .{ .x = circle.origin.x + circle.radius, .y = circle.origin.y };
    const edgeScreen = renderer.gameToScreen(edge);
    const screenRadius: i32 = edgeScreen.x - center.x;

    var x: i32 = 0;
    var y: i32 = screenRadius;
    var d: i32 = 1 - screenRadius;

    while (x <= y) {
        plotCirclePoints(renderer, center, x, y, color);

        if (d < 0) {
            d += 2 * x + 3;
        } else {
            d += 2 * (x - y) + 5;
            y -= 1;
        }
        x += 1;
    }
}

// MARK: Rectangles
fn drawRectangleWithTransform(
    renderer: *CpuRenderer,
    rect: Rectangle,
    transform: Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    // const newCenter = transformPoint(rect.center, transform);
    const new_half_width = if (transform.scale) |scale| rect.half_width * scale else rect.half_width;
    const new_half_height = if (transform.scale) |scale| rect.half_height * scale else rect.half_height;

    const newRect = Rectangle{
        .center = rect.center,
        .half_width = new_half_width,
        .half_height = new_half_height,
    };
    renderer.drawRectangle(newRect, transform, fill_color, stroke_color, stroke_width);
}

fn drawRectangle(
    renderer: *CpuRenderer,
    rect: Rectangle,
    transform: ?Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    if (fill_color) |fc| {
        drawRectFilled(renderer, rect, transform, fc);
    }
    if (stroke_color) |sc| {
        drawRectOutline(renderer, rect, transform, sc, stroke_width);
    }
}

fn drawRectFilled(
    renderer: *CpuRenderer,
    rect: Rectangle,
    transform: ?Transform,
    fill_color: Color,
) void {
    const corners = rect.getCorners();

    var c0 = corners[0];
    var c1 = corners[1];
    var c2 = corners[2];
    var c3 = corners[3];
    if (transform) |xform| {
        c0 = utils.transformPoint(c0, xform);
        c1 = utils.transformPoint(c1, xform);
        c2 = utils.transformPoint(c2, xform);
        c3 = utils.transformPoint(c3, xform);

        if (xform.rotation) |_| {
            var verts1: [3]GamePoint = .{ c0, c1, c2 };
            std.mem.sort(GamePoint, &verts1, {}, sortPointByY);
            var verts2: [3]GamePoint = .{ c0, c2, c3 };
            std.mem.sort(GamePoint, &verts2, {}, sortPointByY);

            const tri1 = Triangle{
                .v0 = verts1[0],
                .v1 = verts1[1],
                .v2 = verts1[2],
            };
            const tri2 = Triangle{
                .v0 = verts2[0],
                .v1 = verts2[1],
                .v2 = verts2[2],
            };

            drawTriangle(renderer, tri1, null, fill_color, null, 0);
            drawTriangle(renderer, tri2, null, fill_color, null, 0);
            return;
        }
    }

    const topLeft = renderer.gameToScreen(c0);
    const bottomRight = renderer.gameToScreen(c2);

    std.debug.assert(topLeft.x <= bottomRight.x);
    std.debug.assert(topLeft.y <= bottomRight.y);

    const startX = @max(0, topLeft.x);
    const endX = @min(renderer.width, bottomRight.x);
    const startY = @max(0, topLeft.y);
    const endY = @min(renderer.height, bottomRight.y);

    if (startX > renderer.width or endX < 0 or startY > renderer.height or endY < 0) return;

    var y = startY;
    while (y <= endY) : (y += 1) {
        var x = startX;
        while (x <= endX) : (x += 1) {
            renderer.frame_buffer.setPixel(x, y, fill_color);
        }
    }
}

fn drawRectOutline(
    renderer: *CpuRenderer,
    rect: Rectangle,
    transform: ?Transform,
    stroke_color: Color,
    stroke_width: f32,
) void {
    const corners = rect.getCorners();

    const c0 = if (transform) |xform| utils.transformPoint(corners[0], xform) else corners[0];
    const c1 = if (transform) |xform| utils.transformPoint(corners[1], xform) else corners[1];
    const c2 = if (transform) |xform| utils.transformPoint(corners[2], xform) else corners[2];
    const c3 = if (transform) |xform| utils.transformPoint(corners[3], xform) else corners[3];
    const xformexCorners: [4]GamePoint = .{ c0, c1, c2, c3 };

    for (0..4) |i| {
        const start = xformexCorners[i];
        const end = xformexCorners[(i + 1) % 4];
        drawLine(renderer, start, end, stroke_color, stroke_width);
    }
}

// MARK: Triangle
fn drawTriangleWithTransform(
    renderer: *CpuRenderer,
    tri: Triangle,
    xform: Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    drawTriangle(renderer, tri, xform, fill_color, stroke_color, stroke_width);
}

fn drawTriangle(
    renderer: *CpuRenderer,
    tri: Triangle,
    transform: ?Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    if (fill_color) |fc| {
        const verts = [3]GamePoint{ tri.v0, tri.v1, tri.v2 };
        drawTriangleFilled(renderer, &verts, transform, fc);
    }
    if (stroke_color) |sc| {
        const verts = [3]GamePoint{ tri.v0, tri.v1, tri.v2 };
        drawOutlineWithTransform(renderer, &verts, transform, sc, stroke_width);
    }
}

fn drawTriangleFilled(renderer: *CpuRenderer, verts: []const GamePoint, transform: ?Transform, color: Color) void {
    std.debug.assert(verts.len == 3);

    var v0 = if (transform) |xform| utils.transformPoint(verts[0], xform) else verts[0];
    var v1 = if (transform) |xform| utils.transformPoint(verts[1], xform) else verts[1];
    var v2 = if (transform) |xform| utils.transformPoint(verts[2], xform) else verts[2];

    if (transform) |xform| {
        if (xform.rotation) |_| {
            var newVerts: [3]GamePoint = .{ v0, v1, v2 };
            std.mem.sort(GamePoint, &newVerts, {}, sortPointByY);
            v0 = newVerts[0];
            v1 = newVerts[1];
            v2 = newVerts[2];
        }
    }

    if (v0.y == v1.y) {
        drawFlatTopTriangle(renderer, v0, v1, v2, color);
    } else if (v1.y == v2.y) {
        drawFlatBottomTriangle(renderer, v0, v1, v2, color);
    } else {
        const factor = (v1.y - v0.y) / (v2.y - v0.y);
        const v3 = GamePoint{ .x = v0.x + factor * (v2.x - v0.x), .y = v1.y };

        drawFlatBottomTriangle(renderer, v0, v1, v3, color);
        drawFlatTopTriangle(renderer, v1, v3, v2, color);
    }
}

fn drawFlatTopTriangle(renderer: *CpuRenderer, v1: GamePoint, v2: GamePoint, v3: GamePoint, color: Color) void {
    std.debug.assert(v1.y == v2.y);

    const topLeft = if (v1.x < v2.x) v1 else v2;
    const topRight = if (v1.x < v2.x) v2 else v1;

    const screenTopLeft = renderer.gameToScreen(topLeft);
    const screenTopRight = renderer.gameToScreen(topRight);
    const screenBottom = renderer.gameToScreen(v3);

    const leftYDist = screenBottom.y - screenTopLeft.y;
    const rightYDist = screenBottom.y - screenTopRight.y;

    const leftXDist = screenTopLeft.x - screenBottom.x;
    const rightXDist = screenTopRight.x - screenBottom.x;

    const leftXInc: f32 = @as(f32, @floatFromInt(leftXDist)) / @as(f32, @floatFromInt(leftYDist));
    const rightXInc: f32 = @as(f32, @floatFromInt(rightXDist)) / @as(f32, @floatFromInt(rightYDist));

    var currY = screenBottom.y;

    var leftX: f32 = @floatFromInt(screenBottom.x);
    var rightX: f32 = @floatFromInt(screenBottom.x);

    while (currY >= screenTopLeft.y) : (currY -= 1) {
        const leftXInt: i32 = @intFromFloat(leftX);
        const rightXInt: i32 = @intFromFloat(rightX);

        drawHorizontalScanLineInt(renderer, currY, leftXInt, rightXInt, color);

        leftX += leftXInc;
        rightX += rightXInc;
    }
}

fn drawFlatBottomTriangle(
    renderer: *CpuRenderer,
    v1: GamePoint,
    v2: GamePoint,
    v3: GamePoint,
    color: Color,
) void {
    std.debug.assert(v2.y == v3.y);

    const botLeft = if (v2.x < v3.x) v2 else v3;
    const botRight = if (v2.x < v3.x) v3 else v2;

    const screenBotLeft = renderer.gameToScreen(botLeft);
    const screenBotRight = renderer.gameToScreen(botRight);
    const screenTop = renderer.gameToScreen(v1);

    const leftYDist = screenBotLeft.y - screenTop.y; // This should be positive
    const rightYDist = screenBotRight.y - screenTop.y; // This should be positive

    const leftXDist = screenBotLeft.x - screenTop.x;
    const rightXDist = screenBotRight.x - screenTop.x;

    const leftXInc: f32 = @as(f32, @floatFromInt(leftXDist)) / @as(f32, @floatFromInt(leftYDist));
    const rightXInc: f32 = @as(f32, @floatFromInt(rightXDist)) / @as(f32, @floatFromInt(rightYDist));

    var currY = screenTop.y;
    var leftX: f32 = @floatFromInt(screenTop.x);
    var rightX: f32 = @floatFromInt(screenTop.x);

    while (currY <= screenBotLeft.y) : (currY += 1) {
        const leftXInt: i32 = @intFromFloat(leftX);
        const rightXInt: i32 = @intFromFloat(rightX);

        const drawLeft = @min(leftXInt, rightXInt);
        const drawRight = @max(leftXInt, rightXInt);

        drawHorizontalScanLineInt(renderer, currY, drawLeft, drawRight, color);

        leftX += leftXInc;
        rightX += rightXInc;
    }
}

// MARK: Polygon
fn drawPolygonWithTransform(
    renderer: *CpuRenderer,
    poly: Polygon,
    xform: Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    drawPolygon(renderer, poly, xform, fill_color, stroke_color, stroke_width);
}

fn drawPolygon(
    renderer: *CpuRenderer,
    poly: Polygon,
    transform: ?Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
) void {
    if (fill_color) |fc| {
        drawPolygonFilled(renderer, poly, transform, fc);
    }
    if (stroke_color) |sc| {
        drawOutlineWithTransform(renderer, poly.points, transform, sc, stroke_width);
    }
}

fn drawPolygonOutline(
    renderer: *CpuRenderer,
    poly: Polygon,
    transform: ?Transform,
    color: Color,
    stroke_width: f32,
) void {
    if (transform) |xform| {
        return drawPolygonOutline(renderer, poly, xform, color, stroke_width);
    }
    return drawOutline(renderer, poly.verts, color, stroke_width);
}

fn drawPolygonFilled(
    renderer: *CpuRenderer,
    poly: Polygon,
    transform: ?Transform,
    color: Color,
) void {
    var sortedVerts: [3]GamePoint = undefined;
    var v1: GamePoint = undefined;
    var v2: GamePoint = undefined;

    const center = if (transform) |xform| utils.transformPoint(poly.center, xform) else poly.center;
    for (0..poly.points.len) |i| {
        v1 = if (transform) |xform| utils.transformPoint(poly.points[i], xform) else poly.points[i];
        const idx = (i + 1) % poly.points.len;
        v2 = if (transform) |xform| utils.transformPoint(poly.points[idx], xform) else poly.points[idx];
        sortedVerts = .{ center, v1, v2 };
        std.mem.sort(GamePoint, &sortedVerts, {}, sortPointByY);
        drawTriangleFilled(renderer, &sortedVerts, null, color);
    }
}

fn sortPointByY(context: void, a: GamePoint, b: GamePoint) bool {
    _ = context;
    return a.y > b.y;
}
